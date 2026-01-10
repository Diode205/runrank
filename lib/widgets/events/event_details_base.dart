// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:runrank/models/club_event.dart';
import 'package:runrank/services/notification_service.dart';

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

  // Inline comments + reactions state
  bool commentsLoading = false;
  List<Map<String, dynamic>> comments = [];
  Map<String, Map<String, List<String>>> commentReactions = {};
  bool _commentReactionsMissing = false;

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
    // Also load existing comments immediately so the inline
    // comments section is populated on first open.
    loadComments();
  }

  Future<void> loadResponses() async {
    loading = true;
    if (mounted) setState(() {});

    final usersResponse = await supabase.from('user_profiles').select('id');
    totalUsers = usersResponse.length;

    final rows = await supabase
        .from('club_event_responses')
        .select()
        .eq('event_id', event.id);

    final list = rows.map((e) => Map<String, dynamic>.from(e)).toList();

    // For relay events, treat anyone with relay stages
    // recorded as a runner, even if their primary
    // response_type is "marshalling" (e.g. they are
    // both running and helping as Stage 6 marshal).
    // Prefer the new relay_stages_json field but fall
    // back to the legacy relay_stage integer.
    runners = list.where((e) {
      if (e['response_type'] == 'running') return true;
      if (event.eventType.toLowerCase() == 'relay') {
        if (e['relay_stages_json'] != null) return true;
        return e['relay_stage'] != null;
      }
      return false;
    }).toList();

    volunteers = list
        .where((e) => e['response_type'] == 'marshalling')
        .toList();
    unavailable = list
        .where((e) => e['response_type'] == 'unavailable')
        .toList();

    // Include anyone with non-empty support roles in Support Crew,
    // allowing multi-role selection (running/marshalling + supporting).
    supporters = list.where((e) {
      final raw = e['relay_roles_json'];
      if (raw == null) return e['response_type'] == 'supporting';
      try {
        final roles = raw is String ? jsonDecode(raw) : raw;
        return roles is List && roles.isNotEmpty;
      } catch (_) {
        return e['response_type'] == 'supporting';
      }
    }).toList();

    final user = supabase.auth.currentUser;
    if (user != null) {
      final mine = list.where((e) => e['user_id'] == user.id);
      if (mine.isNotEmpty) {
        myResponse = mine.first;

        // Prefer multi-stage JSON, fall back to legacy
        // integer relay_stage so older responses still
        // load correctly.
        final stagesJson = myResponse!['relay_stages_json'];
        if (stagesJson != null) {
          try {
            final raw = stagesJson is String
                ? jsonDecode(stagesJson)
                : stagesJson;
            if (raw is List) {
              myRelayStages = raw
                  .whereType<num>()
                  .map((n) => n.toInt())
                  .toList();
            }
          } catch (_) {
            myRelayStages = [];
          }
        } else if (myResponse!['relay_stage'] != null) {
          final stageValue = myResponse!['relay_stage'];
          if (stageValue is int) {
            myRelayStages = [stageValue];
          }
        }

        if (myResponse!['relay_roles_json'] != null) {
          myRelayRoles = List<String>.from(
            jsonDecode(myResponse!['relay_roles_json']),
          );
        }

        myPredictedPace = _asInt(myResponse!['predicted_pace']);
        final expectedSeconds = _asInt(myResponse!['expected_time_seconds']);
        myPredictedFinishHHMMSS = expectedSeconds == null
            ? null
            : secondsToHHMMSS(expectedSeconds);
      }
    }

    loading = false;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadComments() async {
    if (_baseCommentsTableMissing) return;

    commentsLoading = true;
    if (mounted) setState(() {});

    try {
      final data = await getCommentsWithNames(eventId: event.id);
      comments = data;
      await _loadCommentReactions();
    } catch (_) {
      // Errors are already logged in getCommentsWithNames.
    } finally {
      commentsLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadCommentReactions() async {
    if (_commentReactionsMissing) return;

    final ids = comments
        .map((c) => c['id'])
        .where((id) => id != null)
        .map((id) => id.toString())
        .toList();
    if (ids.isEmpty) return;

    try {
      final rows = await supabase
          .from('event_comment_reactions')
          .select('comment_id, user_id, emoji')
          .inFilter('comment_id', ids);

      final map = <String, Map<String, List<String>>>{};

      for (final row in rows) {
        final commentId = row['comment_id']?.toString();
        final userId = row['user_id']?.toString();
        final emoji = row['emoji'] as String?;
        if (commentId == null || userId == null || emoji == null) continue;

        map.putIfAbsent(commentId, () => <String, List<String>>{});
        map[commentId]!.putIfAbsent(emoji, () => <String>[]);
        map[commentId]![emoji]!.add(userId);
      }

      if (!mounted) return;
      setState(() {
        commentReactions = map;
      });
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        _commentReactionsMissing = true;
        debugPrint(
          'event_comment_reactions table missing; skipping inline reactions',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading inline comment reactions: $e');
    }
  }

  Map<String, int> supportRoleBreakdown() {
    final counts = <String, int>{
      'timekeeping': 0,
      'cycling': 0,
      'driving': 0,
      'team_lead': 0,
    };

    for (final supporter in supporters) {
      final raw = supporter['relay_roles_json'];
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
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[dt.weekday - 1];
  }

  String month(int m) {
    const list = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return list[m - 1];
  }

  Color _membershipColor(String? membershipType) {
    switch (membershipType) {
      case '1st Claim':
        return const Color(0xFFFFD700);
      case '2nd Claim':
        return const Color(0xFF0055FF);
      case 'Social':
        return Colors.grey;
      case 'Full-Time Education':
        return const Color(0xFF2E8B57);
      default:
        return const Color(0xFFF5C542);
    }
  }

  int hhmmssToSeconds(String text) {
    final parts = text.split(':').map(int.parse).toList();
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }

  /// Format a comment timestamp into a short, readable string (e.g. 04/01 21:46).
  String formatCommentTimestamp(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m $h:$min';
    } catch (_) {
      return isoString;
    }
  }

  /// Convert user-entered pace to seconds.
  /// Accepts MM:SS, M:SS, '7.30', '7m30s', or decimal minutes like '7.5'.
  int? mmssToSeconds(String? text) {
    if (text == null) return null;
    final raw = text.trim();
    if (raw.isEmpty) return null;

    // Normalize to digits + separators only.
    final cleaned = raw.replaceAll(RegExp(r"[^0-9:.,]"), '');
    if (cleaned.isEmpty) return null;

    int minutes = 0;
    int seconds = 0;

    if (cleaned.contains(':')) {
      final parts = cleaned.split(':').where((p) => p.isNotEmpty).toList();
      minutes = int.tryParse(parts[0]) ?? 0;
      seconds = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      minutes = int.tryParse(parts[0]) ?? 0;
      final secStr = (parts.length > 1 ? parts[1] : '0').padRight(2, '0');
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

  /// Convert seconds to MM:SS pace format (e.g., 450 -> '07:30')
  String secondsToMMSS(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String secondsToHHMMSS(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
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
              title: const Text('Google Maps'),
              onTap: () async {
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Apple Maps'),
              onTap: () async {
                final uri = Uri.parse('http://maps.apple.com/?ll=$lat,$lng');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Waze'),
              onTap: () async {
                final uri = Uri.parse(
                  'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
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
        case 'run':
          dbType = 'running';
          break;
        case 'volunteer':
          dbType = 'marshalling';
          break;
        case 'support':
          // Preserve primary response_type when adding support roles
          // so users can be both runners/marshals and supporters.
          if (myResponse != null && myResponse!['response_type'] is String) {
            dbType = myResponse!['response_type'] as String;
          } else {
            dbType = 'supporting';
          }
          break;
        case 'unavailable':
          dbType = 'unavailable';
          break;
        default:
          dbType = type;
      }

      await supabase.from('club_event_responses').upsert({
        'event_id': event.id,
        'user_id': user.id,
        'response_type': dbType,
        // For relay events, write all selected stages to
        // relay_stages_json while keeping relay_stage set
        // to the first stage for backwards compatibility.
        'relay_stages_json': relayStages != null && relayStages.isNotEmpty
            ? jsonEncode(relayStages)
            : null,
        'relay_stage': relayStages != null && relayStages.isNotEmpty
            ? relayStages.first
            : null,
        'relay_roles_json': relayRoles != null ? jsonEncode(relayRoles) : null,
        'predicted_pace': predictedPace,
        'expected_time_seconds': predictedTimeSeconds,
      }, onConflict: 'event_id,user_id');

      // Notify event creator about new response
      if (event.createdBy != null && event.createdBy!.isNotEmpty) {
        final userProfile = await supabase
            .from('user_profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();

        final userName = userProfile['full_name'] ?? 'A member';
        String action;
        switch (dbType) {
          case 'running':
            action = 'joined';
            break;
          case 'marshalling':
            action = 'volunteered to marshal';
            break;
          case 'supporting':
            action = 'offered support for';
            break;
          case 'unavailable':
            action = 'marked unavailable for';
            break;
          default:
            action = 'responded to';
        }

        await NotificationService.notifyEventCreator(
          eventId: event.id,
          creatorId: event.createdBy!,
          title: 'Event Response',
          body: '$userName has $action ${event.title}',
        );

        // Scope alerts: creator + actor only (no broadcast to all participants)

        // Also notify the responding user so their Alerts badge updates
        await NotificationService.notifyUser(
          userId: user.id,
          title: 'Response Saved',
          body: 'You have $action ${event.title}',
          eventId: event.id,
        );
      }

      loadResponses();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Map<String, String>> fetchNamesForIds(Set<String> ids) async {
    if (ids.isEmpty) return {};

    final map = <String, String>{};
    final res = await supabase
        .from('user_profiles')
        .select('id, full_name')
        .inFilter('id', ids.toList());

    for (final row in res) {
      final id = row['id'] as String?;
      final name = row['full_name'] as String?;
      if (id != null) {
        map[id] = name ?? 'Unknown';
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getHostMessagesWithNames(
    String eventId,
  ) async {
    final rows = await supabase
        .from('event_host_messages')
        .select('id, event_id, sender_id, receiver_id, message, created_at')
        .eq('event_id', eventId)
        .order('created_at');

    final messages = rows.map((e) => Map<String, dynamic>.from(e)).toList();
    final ids = <String>{};
    for (final m in messages) {
      final sender = m['sender_id'] as String?;
      if (sender != null) ids.add(sender);
    }

    if (ids.isEmpty) return messages;

    final profiles = await supabase
        .from('user_profiles')
        .select('id, full_name, avatar_url, membership_type')
        .inFilter('id', ids.toList());

    final Map<String, String> idToName = {
      for (final p in profiles)
        p['id'] as String: (p['full_name'] as String?) ?? 'Member',
    };

    final Map<String, String?> idToAvatar = {
      for (final p in profiles) p['id'] as String: p['avatar_url'] as String?,
    };

    final Map<String, String?> idToMembership = {
      for (final p in profiles)
        p['id'] as String: p['membership_type'] as String?,
    };

    return [
      for (final m in messages)
        {
          ...m,
          'senderName': idToName[m['sender_id']] ?? 'Member',
          'avatarUrl': idToAvatar[m['sender_id']],
          'membershipType': idToMembership[m['sender_id']],
        },
    ];
  }

  Future<void> sendHostMessage(String hostUserId, String message) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('event_host_messages').insert({
      'event_id': event.id,
      'sender_id': user.id,
      'receiver_id': hostUserId,
      'message': message,
    });

    // Notify the host that a new message has arrived.
    try {
      final profile = await supabase
          .from('user_profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final senderName = (profile != null && profile['full_name'] != null)
          ? profile['full_name'] as String
          : 'A member';

      final eventTitle = event.title ?? 'an event';

      await NotificationService.notifyUser(
        userId: hostUserId,
        title: 'New message about $eventTitle',
        body: '$senderName sent you a message about $eventTitle',
        eventId: event.id,
      );
    } catch (e) {
      debugPrint('❌ Error notifying host about new message: $e');
    }
  }

  Future<void> cancelMyPlan() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel your response?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await supabase
        .from('club_event_responses')
        .delete()
        .eq('event_id', event.id)
        .eq('user_id', user.id);

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
      // ignore: avoid_print
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
          .select('id, user_id, comment, timestamp')
          .eq('event_id', eventId)
          .order('timestamp');

      if (commentRows.isEmpty) return [];

      final userIds = <String>{
        for (final row in commentRows) row['user_id'] as String,
      }.toList();
      final orFilter = userIds.map((id) => 'id.eq.$id').join(',');
      final profileRows = await supabase
          .from('user_profiles')
          .select('id, full_name, avatar_url, membership_type')
          .or(orFilter);

      final Map<String, String> idToName = {
        for (final p in profileRows)
          p['id'] as String: (p['full_name'] as String?) ?? 'Unknown user',
      };

      final Map<String, String?> idToAvatar = {
        for (final p in profileRows)
          p['id'] as String: p['avatar_url'] as String?,
      };

      final Map<String, String?> idToMembership = {
        for (final p in profileRows)
          p['id'] as String: p['membership_type'] as String?,
      };

      return [
        for (final c in commentRows)
          {
            'id': c['id'],
            'userId': c['user_id'] as String?,
            'fullName': idToName[(c['user_id'] as String?) ?? ''] ?? 'Unknown',
            'avatarUrl': idToAvatar[(c['user_id'] as String?) ?? ''],
            'membershipType': idToMembership[(c['user_id'] as String?) ?? ''],
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

  Future<void> addComment(String text) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await supabase.from('event_comments').insert({
      'event_id': event.id,
      'user_id': user.id,
      'comment': trimmed,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await loadComments();

    try {
      final profile = await supabase
          .from('user_profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final commenterName = (profile != null && profile['full_name'] != null)
          ? profile['full_name'] as String
          : 'A member';

      final eventTitle = event.title ?? 'an event';

      // Notify the event creator, if any.
      if (event.createdBy != null && event.createdBy!.isNotEmpty) {
        await NotificationService.notifyEventCreator(
          eventId: event.id,
          creatorId: event.createdBy!,
          title: 'New comment on $eventTitle',
          body: '$commenterName commented on $eventTitle',
        );
      }

      // Notify other participants (excluding the commenter) about the comment.
      await NotificationService.notifyEventParticipants(
        eventId: event.id,
        title: 'New comment on $eventTitle',
        body: '$commenterName commented on $eventTitle',
        excludeUserId: user.id,
      );

      // Also notify the commenting user so their alerts badge updates.
      await NotificationService.notifyUser(
        userId: user.id,
        title: 'Comment posted',
        body: 'You commented on $eventTitle',
        eventId: event.id,
      );
    } catch (e) {
      debugPrint('❌ Error sending notifications for comment: $e');
    }
  }

  Future<void> _toggleInlineCommentReaction(
    String commentId,
    String emoji,
  ) async {
    if (_commentReactionsMissing) return;
    final user = supabase.auth.currentUser;
    if (user == null || commentId.isEmpty) return;

    try {
      final users = commentReactions[commentId]?[emoji] ?? const <String>[];
      final hasReacted = users.contains(user.id);

      if (hasReacted) {
        await supabase
            .from('event_comment_reactions')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', user.id)
            .eq('emoji', emoji);
      } else {
        await supabase.from('event_comment_reactions').insert({
          'comment_id': commentId,
          'user_id': user.id,
          'emoji': emoji,
        });
      }

      await _loadCommentReactions();
    } catch (e) {
      debugPrint('❌ Error toggling inline comment reaction: $e');
    }
  }

  Future<void> _showInlineCommentReactionPicker(String commentId) async {
    if (_commentReactionsMissing || commentId.isEmpty) return;
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop();
                        await _toggleInlineCommentReaction(commentId, e);
                      },
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget buildInlineCommentsPreview() {
    if (commentsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No comments yet. Type below to start the conversation.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return Column(
      children: comments.map((c) {
        final name = c['fullName'] as String? ?? 'Member';
        final text = c['comment'] as String? ?? '';
        final ts = c['timestamp'] as String?;
        final commentId = c['id']?.toString() ?? '';
        final avatarUrl = c['avatarUrl'] as String?;
        final membershipType = c['membershipType'] as String?;
        final emojiMap =
            commentReactions[commentId] ?? const <String, List<String>>{};

        final initials = name.isNotEmpty
            ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').join()
            : 'M';

        return GestureDetector(
          onLongPress: () => _showInlineCommentReactionPicker(commentId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _membershipColor(membershipType),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white12,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(
                            '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                          )
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? Text(
                            initials.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ts != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                formatCommentTimestamp(ts),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        if (ts != null) const SizedBox(height: 4),
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (emojiMap.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final entry in emojiMap.entries)
                                if (entry.value.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(entry.key),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${entry.value.length}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
