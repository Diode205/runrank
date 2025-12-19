// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';

class EventDetailsPage extends StatefulWidget {
  final ClubEvent event;

  const EventDetailsPage({super.key, required this.event});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
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
  String? myPredictedPace;
  String? myPredictedFinishHHMMSS;

  final commentController = TextEditingController();
  final messageController = TextEditingController();

  final List<Map<String, dynamic>> relayStages = [
    {'stage': 1, 'distance': '6.2 miles', 'details': 'Start to Whitlingham'},
    {
      'stage': 2,
      'distance': '5.8 miles',
      'details': 'Whitlingham to Whitlingham Broad',
    },
    {
      'stage': 3,
      'distance': '7.1 miles',
      'details': 'Whitlingham Broad to Whitlingham',
    },
    {
      'stage': 4,
      'distance': '6.5 miles',
      'details': 'Whitlingham to Whitlingham',
    },
    {
      'stage': 5,
      'distance': '5.9 miles',
      'details': 'Whitlingham to Whitlingham',
    },
    {'stage': 6, 'distance': '6.3 miles', 'details': 'Whitlingham to Cromer'},
    {'stage': 7, 'distance': '5.7 miles', 'details': 'Cromer to Cromer'},
    {'stage': 8, 'distance': '6.8 miles', 'details': 'Cromer to Cromer'},
    {'stage': 9, 'distance': '5.4 miles', 'details': 'Cromer to Cromer'},
    {'stage': 10, 'distance': '7.2 miles', 'details': 'Cromer to Cromer'},
    {'stage': 11, 'distance': '6.1 miles', 'details': 'Cromer to Cromer'},
    {'stage': 12, 'distance': '5.6 miles', 'details': 'Cromer to Cromer'},
    {'stage': 13, 'distance': '6.9 miles', 'details': 'Cromer to Cromer'},
    {'stage': 14, 'distance': '5.3 miles', 'details': 'Cromer to Cromer'},
    {'stage': 15, 'distance': '7.0 miles', 'details': 'Cromer to Cromer'},
    {'stage': 16, 'distance': '6.4 miles', 'details': 'Cromer to Cromer'},
    {'stage': 17, 'distance': '5.5 miles', 'details': 'Cromer to Finish'},
  ];

  @override
  void dispose() {
    commentController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    loading = true;
    setState(() {});

    final usersResponse = await supabase.from("user_profiles").select("id");
    totalUsers = usersResponse.length;

    final rows = await supabase
        .from("club_event_responses")
        .select()
        .eq("event_id", widget.event.id);

    final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    runners = list.where((e) => e["response_type"] == "running").toList();
    volunteers = list
        .where((e) => e["response_type"] == "marshalling")
        .toList();
    unavailable = list
        .where((e) => e["response_type"] == "unavailable")
        .toList();
    supporters = list.where((e) => e["response_type"] == "supporting").toList();

    final user = supabase.auth.currentUser;
    if (user != null) {
      final mine = list.where((e) => e["user_id"] == user.id);
      if (mine.isNotEmpty) {
        myResponse = mine.first;
        if (myResponse!["relay_stage"] != null) {
          myRelayStages = List<int>.from(
            jsonDecode(myResponse!["relay_stage"]),
          );
        }
        if (myResponse!["relay_roles_json"] != null) {
          myRelayRoles = List<String>.from(
            jsonDecode(myResponse!["relay_roles_json"]),
          );
        }
        myPredictedPace = myResponse!["predicted_pace"];
        myPredictedFinishHHMMSS = myResponse!["expected_time_seconds"] == null
            ? null
            : _secondsToHHMMSS(myResponse!["expected_time_seconds"] as int);
      }
    }

    loading = false;
    setState(() {});
  }

  String _weekday(DateTime dt) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[dt.weekday - 1];
  }

  String _month(int m) {
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

  int _hhmmssToSeconds(String text) {
    final parts = text.split(":").map(int.parse).toList();
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  String _secondsToHHMMSS(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, "0");
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, "0");
    final sec = (s % 60).toString().padLeft(2, "0");
    return "$h:$m:$sec";
  }

  Future<void> _openMaps() async {
    if (widget.event.latitude == null || widget.event.longitude == null) return;
    final lat = widget.event.latitude!;
    final lng = widget.event.longitude!;

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

  Future<void> _submitResponse({
    required String type,
    List<int>? relayStages,
    List<String>? relayRoles,
    String? predictedPace,
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
          dbType = "supporting";
          break;
        case "unavailable":
          dbType = "unavailable";
          break;
        default:
          dbType = type;
      }

      await supabase.from("club_event_responses").upsert({
        "event_id": widget.event.id,
        "user_id": user.id,
        "response_type": dbType,
        "relay_stage": relayStages == null ? null : jsonEncode(relayStages),
        "relay_roles_json": relayRoles == null ? null : jsonEncode(relayRoles),
        "predicted_pace": predictedPace,
        "expected_time_seconds": predictedTimeSeconds,
      });

      await _loadResponses();

      String message;
      if (type == "run") {
        message = "You have joined this event";
      } else if (type == "volunteer") {
        message = "You have volunteered for this event";
      } else if (type == "support") {
        message = "You are supporting this event";
      } else if (type == "unavailable") {
        message = "You have declined this event";
      } else {
        message = "Your response has been recorded";
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _contactHost() async {
    // Treat the event creator as the host; fall back to the current user if missing.
    final hostUserId = widget.event.createdBy ?? supabase.auth.currentUser?.id;
    if (hostUserId == null || hostUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No creator id found for this event. Please re-save the event.",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HostChatSheet(
        event: widget.event,
        hostUserId: hostUserId,
        hostDisplayName: widget.event.hostOrDirector.isNotEmpty
            ? widget.event.hostOrDirector
            : "Host / Coach",
        messageController: messageController,
        loadMessages: getHostMessagesWithNames,
        sendMessage: _sendHostMessage,
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = commentController.text.trim();
    if (comment.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from("event_comments").insert({
      "event_id": widget.event.id,
      "user_id": user.id,
      "comment": comment,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }

  Future<void> _openCommentsSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        eventId: widget.event.id,
        commentController: commentController,
        onCommentSubmitted: _submitComment,
      ),
    );
  }

  Future<Map<String, String>> _fetchNamesForIds(Set<String> userIds) async {
    if (userIds.isEmpty) return {};

    final res = await supabase
        .from("user_profiles")
        .select("id, full_name")
        .inFilter("id", userIds.toList());

    final map = <String, String>{};
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

    final names = await _fetchNamesForIds(ids);

    return messages
        .map((m) => {...m, "senderName": names[m["sender_id"]] ?? "Member"})
        .toList();
  }

  Future<void> _sendHostMessage(String hostUserId, String message) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from("event_host_messages").insert({
      "event_id": widget.event.id,
      "sender_id": user.id,
      "receiver_id": hostUserId,
      "message": message,
    });
  }

  Future<void> _cancelMyPlan() async {
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
        .eq("event_id", widget.event.id)
        .eq("user_id", user.id);

    _loadResponses();
  }

  Widget _buildParticipationSection() {
    final type = widget.event.eventType.toLowerCase();
    if (widget.event.isCancelled) return const SizedBox.shrink();
    final hasResponse = myResponse != null;

    if (hasResponse) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your choice",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "• Type: ${myResponse!["response_type"]}",
                style: const TextStyle(fontSize: 16),
              ),
              if (myRelayStages.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text("• Relay stages: ${myRelayStages.join(", ")}"),
              ],
              if (myRelayRoles.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text("• Relay roles: ${myRelayRoles.join(", ")}"),
              ],
              if (myPredictedPace != null) ...[
                const SizedBox(height: 6),
                Text("• Predicted pace: $myPredictedPace min/mile"),
              ],
              if (myPredictedFinishHHMMSS != null) ...[
                const SizedBox(height: 6),
                Text("• Predicted finish: $myPredictedFinishHHMMSS"),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => myResponse = null),
                    child: const Text("Edit"),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _cancelMyPlan,
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    switch (type) {
      case "training_1":
      case "training_2":
      case "special_event":
      case "social_run":
      case "meet_&_drink":
      case "swim_or_cycle":
      case "others":
        return _buildSimpleButtons();
      case "race":
        return _buildRaceButtons();
      case "handicap_series":
        return _buildHandicapButtons();
      case "relay":
        return _buildRelayButtons();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSimpleButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FilledButton(
          onPressed: () => _submitResponse(type: "run"),
          child: const Text("✅ Attending"),
        ),
        FilledButton(
          onPressed: () => _submitResponse(type: "unavailable"),
          child: const Text("❌ Decline"),
        ),
      ],
    );
  }

  Widget _buildRaceButtons() {
    final marshalDate = widget.event.marshalCallDate;
    final canMarshal =
        marshalDate == null || DateTime.now().isAfter(marshalDate);

    return Column(
      children: [
        if (marshalDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Marshal Call Date On: ${_weekday(marshalDate)}, ${marshalDate.day} ${_month(marshalDate.month)} ${marshalDate.year}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            FilledButton(
              onPressed: () => _submitResponse(type: "run"),
              child: const Icon(Icons.directions_run),
            ),
            FilledButton(
              onPressed: canMarshal
                  ? () => _submitResponse(type: "volunteer")
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "You will be notified when Marshall call is opened",
                        ),
                      ),
                    ),
              child: const Icon(Icons.security),
            ),
            FilledButton(
              onPressed: () => _submitResponse(type: "unavailable"),
              child: const Icon(Icons.cancel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHandicapButtons() {
    final marshalDate = widget.event.marshalCallDate;
    final canMarshal =
        marshalDate == null || DateTime.now().isAfter(marshalDate);

    return Column(
      children: [
        if (marshalDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Marshal Call Date On: ${_weekday(marshalDate)}, ${marshalDate.day} ${_month(marshalDate.month)} ${marshalDate.year}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            FilledButton(
              onPressed: () async {
                final timeController = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Predicted finish time"),
                    content: TextField(
                      controller: timeController,
                      decoration: const InputDecoration(labelText: "HH:MM:SS"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  if (RegExp(
                    r"^\d\d:\d\d:\d\d$",
                  ).hasMatch(timeController.text)) {
                    final secs = _hhmmssToSeconds(timeController.text);
                    _submitResponse(type: "run", predictedTimeSeconds: secs);
                  }
                }
              },
              child: const Icon(Icons.directions_run),
            ),
            FilledButton(
              onPressed: canMarshal
                  ? () => _submitResponse(type: "volunteer")
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "You will be notified when Marshall call is opened",
                        ),
                      ),
                    ),
              child: const Icon(Icons.security),
            ),
            FilledButton(
              onPressed: () => _submitResponse(type: "unavailable"),
              child: const Icon(Icons.cancel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelayButtons() {
    final marshalDate = widget.event.marshalCallDate;
    final canMarshal =
        marshalDate == null || DateTime.now().isAfter(marshalDate);

    return Column(
      children: [
        if (marshalDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Marshal Call Date On: ${_weekday(marshalDate)}, ${marshalDate.day} ${_month(marshalDate.month)} ${marshalDate.year}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            FilledButton(
              onPressed: () async {
                final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => _relayRunningDialog(),
                );
                if (result != null) {
                  myRelayStages = result['stages'];
                  myPredictedPace = result['pace'];
                  _submitResponse(
                    type: "run",
                    relayStages: myRelayStages,
                    predictedPace: myPredictedPace,
                  );
                }
              },
              child: const Icon(Icons.directions_run),
            ),
            FilledButton(
              onPressed: canMarshal
                  ? () => _submitResponse(type: "volunteer")
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "You will be notified when Marshall call is opened",
                        ),
                      ),
                    ),
              child: const Icon(Icons.security),
            ),
            FilledButton(
              onPressed: () async {
                final roles = await showDialog<List<String>>(
                  context: context,
                  builder: (_) => _relaySupportingDialog(),
                );
                if (roles != null && roles.isNotEmpty) {
                  myRelayRoles = roles;
                  _submitResponse(type: "support", relayRoles: myRelayRoles);
                }
              },
              child: const Icon(Icons.people),
            ),
          ],
        ),
      ],
    );
  }

  Widget _relayRunningDialog() {
    List<int> selectedStages = List.from(myRelayStages);
    String? pace;

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Select Relay Stages & Pace"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: relayStages.map((stage) {
                    return CheckboxListTile(
                      title: Text(
                        "Stage ${stage['stage']}: ${stage['distance']} - ${stage['details']}",
                      ),
                      value: selectedStages.contains(stage['stage']),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            selectedStages.add(stage['stage'] as int);
                          } else {
                            selectedStages.remove(stage['stage'] as int);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Predicted Pace (min/mile)",
                ),
                onChanged: (value) => pace = value.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'stages': selectedStages,
              'pace': pace,
            }),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _relaySupportingDialog() {
    List<String> selectedRoles = List.from(myRelayRoles);

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text("Select Support Roles"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text("🧭 Timekeeping"),
              value: selectedRoles.contains("timekeeping"),
              onChanged: (v) => setState(
                () => v == true
                    ? selectedRoles.add("timekeeping")
                    : selectedRoles.remove("timekeeping"),
              ),
            ),
            CheckboxListTile(
              title: const Text("🚴 Cycling"),
              value: selectedRoles.contains("cycling"),
              onChanged: (v) => setState(
                () => v == true
                    ? selectedRoles.add("cycling")
                    : selectedRoles.remove("cycling"),
              ),
            ),
            CheckboxListTile(
              title: const Text("🚐 Driving"),
              value: selectedRoles.contains("driving"),
              onChanged: (v) => setState(
                () => v == true
                    ? selectedRoles.add("driving")
                    : selectedRoles.remove("driving"),
              ),
            ),
            CheckboxListTile(
              title: const Text("📋 Team Lead"),
              value: selectedRoles.contains("team_lead"),
              onChanged: (v) => setState(
                () => v == true
                    ? selectedRoles.add("team_lead")
                    : selectedRoles.remove("team_lead"),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selectedRoles),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelEvent() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Event?"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason"),
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
        .from("club_events")
        .update({
          "is_cancelled": true,
          "cancel_reason": reasonController.text.trim(),
        })
        .eq("id", widget.event.id);

    setState(() {});
  }

  Future<void> _deleteEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Event Permanently?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await supabase.from("club_events").delete().eq("id", widget.event.id);
    Navigator.pop(context);
  }

  Future<void> _showParticipantsByType(
    String title,
    String responseType, {
    bool showExpectedTime = false,
  }) async {
    final attendees = await getRespondersWithNames(
      eventId: widget.event.id,
      responseType: responseType,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: attendees.isEmpty
              ? const Center(
                  child: Text(
                    "No participants yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    final a = attendees[i];
                    final name = a['fullName'] as String? ?? 'Unknown runner';
                    final expected = a['expectedTimeSeconds'] as int?;
                    return ListTile(
                      title: Text(name),
                      subtitle: showExpectedTime && expected != null
                          ? Text(
                              'Predicted time: ${_secondsToHHMMSS(expected)}',
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;
    final user = supabase.auth.currentUser;
    final isAdmin = user?.id == e.createdBy;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          e.title ?? "Event Details",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD300).withOpacity(0.3),
                const Color(0xFF0057B7).withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
              children: [
                ...(e.isCancelled
                    ? [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.3),
                                Colors.red.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "CANCELLED — ${e.cancelReason ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]
                    : []),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade800.withOpacity(0.5),
                        Colors.grey.shade900.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD300).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFFFFD300),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${_weekday(dt)}, ${dt.day} ${_month(dt.month)} ${dt.year}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0057B7).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.access_time,
                              color: Color(0xFF0057B7),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white12),
                      Text(
                        "Hosted By",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.hostOrDirector.isNotEmpty
                            ? e.hostOrDirector
                            : "Not specified",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Divider(height: 32, color: Colors.white12),
                      Text(
                        "Venue",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.venue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      ...(e.venueAddress.isNotEmpty
                          ? [
                              const SizedBox(height: 4),
                              Text(
                                e.venueAddress,
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ]
                          : []),
                      ...(e.latitude != null && e.longitude != null
                          ? [
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _openMaps,
                                icon: const Icon(Icons.map),
                                label: const Text("Open in Maps"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFD300),
                                  side: const BorderSide(
                                    color: Color(0xFFFFD300),
                                  ),
                                ),
                              ),
                            ]
                          : []),
                      const Divider(height: 32, color: Colors.white12),
                      Text(
                        "Details",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.description.isEmpty
                            ? "No description provided."
                            : e.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Responses",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD300),
                  ),
                ),
                const SizedBox(height: 8),
                _buildParticipationSection(),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Builder(
                    builder: (_) {
                      final items = _getParticipantLines();
                      final children = <Widget>[];
                      for (var i = 0; i < items.length; i++) {
                        children.add(items[i]);
                        if (i < items.length - 1) {
                          children.add(
                            const Divider(height: 1, color: Colors.white12),
                          );
                        }
                      }
                      return Column(children: children);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0057B7), Color(0xFF003F8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0057B7).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _contactHost(),
                    icon: const Icon(Icons.message),
                    label: const Text("Message Host/Coach"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text("Comments", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openCommentsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white12,
                          child: Icon(
                            Icons.add,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Add a comment...",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_up, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                ...(isAdmin
                    ? [
                        const Divider(height: 40),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _cancelEvent,
                          child: const Text("Cancel Event"),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          onPressed: _deleteEvent,
                          child: const Text("Delete Event"),
                        ),
                      ]
                    : []),
              ],
            ),
    );
  }

  Widget _buildParticipantLine(
    String label,
    int count,
    List<Map<String, dynamic>> participants, {
    String? responseType,
    bool showExpectedTime = false,
  }) {
    return InkWell(
      onTap: count > 0
          ? () {
              if (responseType != null) {
                _showParticipantsByType(
                  label,
                  responseType,
                  showExpectedTime: showExpectedTime,
                );
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getParticipantLines() {
    final type = widget.event.eventType.toLowerCase();
    List<Widget> lines = [];

    if (type == "training_1" ||
        type == "training_2" ||
        type == "special_event" ||
        type == "social_run" ||
        type == "meet_&_drink" ||
        type == "swim_or_cycle" ||
        type == "others") {
      final answeredCount = runners.length + unavailable.length;
      final unansweredCount = (totalUsers - answeredCount) < 0
          ? 0
          : (totalUsers - answeredCount);

      lines.add(
        _buildParticipantLine(
          "✅ Attending",
          runners.length,
          runners,
          responseType: 'running',
        ),
      );
      lines.add(
        _buildParticipantLine(
          "❌ Declined",
          unavailable.length,
          unavailable,
          responseType: 'unavailable',
        ),
      );
      lines.add(_buildParticipantLine("❓ Unanswered", unansweredCount, []));
    } else if (type == "race" || type == "handicap_series") {
      lines.add(
        _buildParticipantLine(
          "🏃‍♀️ Running",
          runners.length,
          runners,
          responseType: 'running',
          showExpectedTime: type == 'handicap_series',
        ),
      );
      lines.add(
        _buildParticipantLine(
          "🦺 Marshalling",
          volunteers.length,
          volunteers,
          responseType: 'marshalling',
        ),
      );
      lines.add(
        _buildParticipantLine(
          "❌ Unavailable",
          unavailable.length,
          unavailable,
          responseType: 'unavailable',
        ),
      );
    } else if (type == "relay") {
      lines.add(
        _buildParticipantLine(
          "🏃‍♀️ Running",
          runners.length,
          runners,
          responseType: 'running',
        ),
      );
      lines.add(
        _buildParticipantLine(
          "🦺 Marshals",
          volunteers.length,
          volunteers,
          responseType: 'marshalling',
        ),
      );
      if (supporters.isNotEmpty) {
        lines.add(
          _buildParticipantLine(
            "🤝 Support Crew",
            supporters.length,
            supporters,
            responseType: 'supporting',
          ),
        );
      }
    }

    return lines;
  }
}

Future<List<Map<String, dynamic>>> getRespondersWithNames({
  required String eventId,
  required String responseType,
}) async {
  final supabase = Supabase.instance.client;
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
  final supabase = Supabase.instance.client;
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
  } catch (e) {
    print('❌ Error fetching comments with names: $e');
    return [];
  }
}

class _CommentsSheet extends StatefulWidget {
  final String eventId;
  final TextEditingController commentController;
  final Future<void> Function() onCommentSubmitted;

  const _CommentsSheet({
    required this.eventId,
    required this.commentController,
    required this.onCommentSubmitted,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _HostChatSheet extends StatefulWidget {
  final ClubEvent event;
  final String hostUserId;
  final String hostDisplayName;
  final TextEditingController messageController;
  final Future<List<Map<String, dynamic>>> Function(String eventId)
  loadMessages;
  final Future<void> Function(String hostUserId, String message) sendMessage;

  const _HostChatSheet({
    required this.event,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.messageController,
    required this.loadMessages,
    required this.sendMessage,
  });

  @override
  State<_HostChatSheet> createState() => _HostChatSheetState();
}

class _HostChatSheetState extends State<_HostChatSheet> {
  final _headerShadow = BoxShadow(
    color: Colors.black.withOpacity(0.35),
    blurRadius: 16,
    offset: const Offset(0, 10),
  );

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _messages = [];
  ScrollController? _listController;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _listController = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await widget.loadMessages(widget.event.id);
      if (!mounted) return;
      _messages = data;
      _loading = false;
      setState(() {});
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _loading = false;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load messages: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _listController;
      if (controller == null || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return "";
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _handleSend() async {
    final text = widget.messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await widget.sendMessage(widget.hostUserId, text);
      widget.messageController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        _listController = scrollController;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD300).withOpacity(0.22),
                      const Color(0xFF0057B7).withOpacity(0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 1.2),
                  boxShadow: [_headerShadow],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                              ),
                            ),
                            child: const Icon(
                              Icons.forum,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.title ?? "Event",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Chat with ${widget.hostDisplayName}",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(32),
                        children: const [
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No messages yet",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Start a conversation with the host",
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isMine = msg['sender_id'] == currentUserId;
                          final sender =
                              (msg['senderName'] as String?) ??
                              (isMine ? 'You' : widget.hostDisplayName);
                          final ts = _formatTime(msg['created_at'] as String?);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? const Color(
                                            0xFF0057B7,
                                          ).withOpacity(0.85)
                                        : Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white12,
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: isMine
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMine)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              sender,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          (msg['message'] as String?) ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (ts.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              ts,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.55,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  border: const Border(
                    top: BorderSide(color: Colors.white12, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 56,
                          maxHeight: 140,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Photo attachment coming soon',
                                    ),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.photo_library),
                              color: const Color(0xFF0057B7),
                              tooltip: 'Attach photo',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Camera feature coming soon'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.camera_alt),
                              color: const Color(0xFF0057B7),
                              tooltip: 'Take photo',
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: widget.messageController,
                                maxLines: null,
                                textInputAction: TextInputAction.newline,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _sending ? null : _handleSend,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        tooltip: 'Send message',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    final data = await getCommentsWithNames(eventId: widget.eventId);
    if (mounted) {
      setState(() {
        _comments = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline, color: Colors.white70),
                    SizedBox(width: 8),
                    Text(
                      "Comments",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "No comments yet",
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Start the conversation",
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final name = c['fullName'] as String? ?? 'User';
                          final text = c['comment'] as String? ?? '';
                          final ts = c['timestamp'] as String?;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                if (ts != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      ts,
                                      style: const TextStyle(
                                        color: Colors.white30,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemCount: _comments.length,
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  border: const Border(
                    top: BorderSide(color: Colors.white12, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Add coming soon"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.white70),
                        tooltip: "Add",
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: widget.commentController,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () async {
                          if (widget.commentController.text.trim().isEmpty)
                            return;
                          await widget.onCommentSubmitted();
                          widget.commentController.clear();
                          await _loadComments();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Comment posted"),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                        ),
                        tooltip: "Post comment",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
