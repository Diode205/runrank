// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';

// Prevent repeated Supabase error spam if the comments table is absent.
bool _baseCommentsTableMissing = false;

/// Base state for event details pages.
/// Handles shared logic: data loading, responses, comments, host messaging.
mixin EventDetailsBaseMixin<T extends StatefulWidget> on State<T> {
  final supabase = Supabase.instance.client;

  bool loading = true;

  List<Map<String, dynamic>> runners = [];
  List<Map<String, dynamic>> volunteers = [];
  List<Map<String, dynamic>> unavailable = [];
  List<Map<String, dynamic>> supporters = [];

  Map<String, dynamic>? myResponse;
  int totalUsers = 0;

  List<int> myRelayStages = [];
  List<String> myRelayRoles = [];
  int? myPredictedPace; // Stored as seconds per mile
  String? myPredictedFinishHHMMSS;

  final commentController = TextEditingController();
  final messageController = TextEditingController();

  ClubEvent get event;

  @override
  void dispose() {
    commentController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadResponses();
  }

  Future<void> loadResponses() async {
    loading = true;
    if (mounted) setState(() {});

    final usersResponse = await supabase.from("user_profiles").select("id");
    totalUsers = usersResponse.length;

    final rows = await supabase
        .from("club_event_responses")
        .select()
        .eq("event_id", event.id);

    final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    runners = list.where((e) => e["response_type"] == "running").toList();
    volunteers = list
        .where((e) => e["response_type"] == "marshalling")
        .toList();
    unavailable = list
        .where((e) => e["response_type"] == "unavailable")
        .toList();
    // Include anyone with non-empty support roles in Support Crew,
    // allowing multi-role selection (running/marshalling + supporting).
    supporters = list.where((e) {
      final raw = e["relay_roles_json"];
      if (raw == null) return e["response_type"] == "supporting";
      try {
        final roles = raw is String ? jsonDecode(raw) : raw;
        return roles is List && roles.isNotEmpty;
      } catch (_) {
        return e["response_type"] == "supporting";
      }
    }).toList();

    final user = supabase.auth.currentUser;
    if (user != null) {
      final mine = list.where((e) => e["user_id"] == user.id);
      if (mine.isNotEmpty) {
        myResponse = mine.first;
        if (myResponse!["relay_stage"] != null) {
          final stageValue = myResponse!["relay_stage"];
          if (stageValue is String) {
            try {
              myRelayStages = List<int>.from(jsonDecode(stageValue));
            } catch (e) {
              myRelayStages = [];
            }
          } else if (stageValue is int) {
            // Legacy: single int value
            myRelayStages = [stageValue];
          }
        }
        if (myResponse!["relay_roles_json"] != null) {
          myRelayRoles = List<String>.from(
            jsonDecode(myResponse!["relay_roles_json"]),
          );
        }
        myPredictedPace = _asInt(myResponse!["predicted_pace"]);
        final expectedSeconds = _asInt(myResponse!["expected_time_seconds"]);
        myPredictedFinishHHMMSS = expectedSeconds == null
            ? null
            : secondsToHHMMSS(expectedSeconds);
      }
    }

    loading = false;
    if (!mounted) return;
    setState(() {});
  }

  Map<String, int> supportRoleBreakdown() {
    final counts = <String, int>{
      "timekeeping": 0,
      "cycling": 0,
      "driving": 0,
      "team_lead": 0,
    };

    for (final supporter in supporters) {
      final raw = supporter["relay_roles_json"];
      List<dynamic>? roles;
      if (raw is String) {
        try {
          roles = jsonDecode(raw) as List<dynamic>?;
        } catch (_) {
          roles = null;
        }
      } else if (raw is List) {
        roles = raw;
      }

      if (roles == null) continue;

      for (final r in roles) {
        final role = r as String?;
        if (role != null && counts.containsKey(role)) {
          counts[role] = (counts[role] ?? 0) + 1;
        }
      }
    }

    return counts;
  }

  String weekday(DateTime dt) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[dt.weekday - 1];
  }

  String month(int m) {
    const list = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return list[m - 1];
  }

  int hhmmssToSeconds(String text) {
    final parts = text.split(":").map(int.parse).toList();
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  /// Convert user-entered pace to seconds.
  /// Accepts MM:SS, M:SS, "7.30", "7m30s", or decimal minutes like "7.5".
  int? mmssToSeconds(String? text) {
    if (text == null) return null;
    final raw = text.trim();
    if (raw.isEmpty) return null;

    // Normalize to digits + separators only.
    final cleaned = raw.replaceAll(RegExp(r"[^0-9:.,]"), "");
    if (cleaned.isEmpty) return null;

    int minutes = 0;
    int seconds = 0;

    if (cleaned.contains(":")) {
      final parts = cleaned.split(":").where((p) => p.isNotEmpty).toList();
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = int.tryParse(parts.length > 1 ? parts[1] : "0") ?? 0;
    } else if (cleaned.contains(".")) {
      final parts = cleaned.split(".");
      minutes = int.tryParse(parts[0]) ?? 0;
      final secStr = (parts.length > 1 ? parts[1] : "0").padRight(2, "0");
      seconds = int.tryParse(secStr.substring(0, 2)) ?? 0;
    } else if (cleaned.length >= 3) {
      // Treat last two digits as seconds when no separator provided (e.g., 730 -> 7:30).
      final secStr = cleaned.substring(cleaned.length - 2);
      final minStr = cleaned.substring(0, cleaned.length - 2);
      minutes = int.tryParse(minStr) ?? 0;
      seconds = int.tryParse(secStr) ?? 0;
    } else {
      minutes = int.tryParse(cleaned) ?? 0;
      seconds = 0;
    }

    // Carry any overflow and discard obviously invalid ranges.
    minutes += seconds ~/ 60;
    seconds = seconds % 60;

    final totalSeconds = minutes * 60 + seconds;
    if (totalSeconds < 120 || totalSeconds > 1200) {
      // Reject unrealistically low/high paces (below 2:00 or above 20:00).
      return null;
    }
    return totalSeconds;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Convert seconds to MM:SS pace format (e.g., 450 -> "07:30")
  String secondsToMMSS(int s) {
    final m = (s ~/ 60).toString().padLeft(2, "0");
    final sec = (s % 60).toString().padLeft(2, "0");
    return "$m:$sec";
  }

  String secondsToHHMMSS(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, "0");
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, "0");
    final sec = (s % 60).toString().padLeft(2, "0");
    return "$h:$m:$sec";
  }

  Future<void> openMaps() async {
    if (event.latitude == null || event.longitude == null) return;
    final lat = event.latitude!;
    final lng = event.longitude!;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text("Google Maps"),
              onTap: () async {
                final uri = Uri.parse(
                  "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
                );
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text("Apple Maps"),
              onTap: () async {
                final uri = Uri.parse("http://maps.apple.com/?ll=$lat,$lng");
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text("Waze"),
              onTap: () async {
                final uri = Uri.parse(
                  "https://waze.com/ul?ll=$lat,$lng&navigate=yes",
                );
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> submitResponse({
    required String type,
    List<int>? relayStages,
    List<String>? relayRoles,
    int? predictedPace,
    int? predictedTimeSeconds,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      String dbType;
      switch (type) {
        case "run":
          dbType = "running";
          break;
        case "volunteer":
          dbType = "marshalling";
          break;
        case "support":
          // Preserve primary response_type when adding support roles
          // so users can be both runners/marshals and supporters.
          if (myResponse != null && myResponse!["response_type"] is String) {
            dbType = myResponse!["response_type"] as String;
          } else {
            dbType = "supporting";
          }
          break;
        case "unavailable":
          dbType = "unavailable";
          break;
        default:
          dbType = type;
      }

      await supabase.from("club_event_responses").upsert({
        "event_id": event.id,
        "user_id": user.id,
        "response_type": dbType,
        "relay_stage": relayStages != null && relayStages.isNotEmpty
            ? relayStages.first
            : null,
        "relay_roles_json": relayRoles != null ? jsonEncode(relayRoles) : null,
        "predicted_pace": predictedPace,
        "expected_time_seconds": predictedTimeSeconds,
      }, onConflict: 'event_id,user_id');

      loadResponses();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<Map<String, String>> fetchNamesForIds(Set<String> ids) async {
    if (ids.isEmpty) return {};

    final map = <String, String>{};
    final res = await supabase
        .from("user_profiles")
        .select("id, full_name")
        .inFilter("id", ids.toList());

    for (final row in res) {
      final id = row["id"] as String?;
      final name = row["full_name"] as String?;
      if (id != null) {
        map[id] = name ?? "Unknown";
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getHostMessagesWithNames(
    String eventId,
  ) async {
    final rows = await supabase
        .from("event_host_messages")
        .select("id, event_id, sender_id, receiver_id, message, created_at")
        .eq("event_id", eventId)
        .order("created_at");

    final messages = rows.map((e) => Map<String, dynamic>.from(e)).toList();
    final ids = <String>{};
    for (final m in messages) {
      final sender = m["sender_id"] as String?;
      if (sender != null) ids.add(sender);
    }

    final names = await fetchNamesForIds(ids);

    return messages
        .map((m) => {...m, "senderName": names[m["sender_id"]] ?? "Member"})
        .toList();
  }

  Future<void> sendHostMessage(String hostUserId, String message) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from("event_host_messages").insert({
      "event_id": event.id,
      "sender_id": user.id,
      "receiver_id": hostUserId,
      "message": message,
    });
  }

  Future<void> cancelMyPlan() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel your response?"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason (optional)"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await supabase
        .from("club_event_responses")
        .delete()
        .eq("event_id", event.id)
        .eq("user_id", user.id);

    loadResponses();
  }

  Future<List<Map<String, dynamic>>> getRespondersWithNames({
    required String eventId,
    required String responseType,
  }) async {
    try {
      final responseRows = await supabase
          .from('club_event_responses')
          .select('user_id, expected_time_seconds')
          .eq('event_id', eventId)
          .eq('response_type', responseType);

      if (responseRows.isEmpty) return [];

      final userIds = <String>{
        for (final row in responseRows) row['user_id'] as String,
      }.toList();
      final orFilter = userIds.map((id) => 'id.eq.$id').join(',');
      final profileRows = await supabase
          .from('user_profiles')
          .select('id, full_name')
          .or(orFilter);

      final Map<String, String> idToName = {
        for (final p in profileRows)
          p['id'] as String: (p['full_name'] as String?) ?? 'Unknown runner',
      };

      return [
        for (final row in responseRows)
          {
            'userId': row['user_id'] as String,
            'fullName': idToName[row['user_id'] as String] ?? 'Unknown runner',
            'expectedTimeSeconds': row['expected_time_seconds'] as int?,
          },
      ];
    } catch (e) {
      print('❌ Error fetching responders with names: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCommentsWithNames({
    required String eventId,
  }) async {
    if (_baseCommentsTableMissing) return [];

    try {
      final commentRows = await supabase
          .from('event_comments')
          .select('user_id, comment, timestamp')
          .eq('event_id', eventId)
          .order('timestamp');

      if (commentRows.isEmpty) return [];

      final userIds = <String>{
        for (final row in commentRows) row['user_id'] as String,
      }.toList();
      final orFilter = userIds.map((id) => 'id.eq.$id').join(',');
      final profileRows = await supabase
          .from('user_profiles')
          .select('id, full_name')
          .or(orFilter);

      final Map<String, String> idToName = {
        for (final p in profileRows)
          p['id'] as String: (p['full_name'] as String?) ?? 'Unknown user',
      };

      return [
        for (final c in commentRows)
          {
            'userId': c['user_id'] as String?,
            'fullName': idToName[(c['user_id'] as String?) ?? ''] ?? 'Unknown',
            'comment': c['comment'] as String?,
            'timestamp': c['timestamp'] as String?,
          },
      ];
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        _baseCommentsTableMissing = true;
        debugPrint('event_comments table missing; suppressing further fetches');
        return [];
      }
      debugPrint('❌ Error fetching comments with names: $e');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching comments with names: $e');
      return [];
    }
  }
}
