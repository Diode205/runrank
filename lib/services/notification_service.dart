// lib/services/notification_service.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  static final _unreadCountController = StreamController<int>.broadcast();
  static final _eventActivityController = StreamController<int>.broadcast();

  // ---------------------------------------------------------------
  // SEND NOTIFICATION TO ALL USERS
  // ---------------------------------------------------------------
  static Future<void> notifyAllUsers({
    required String title,
    required String body,
    String? eventId,
    String? route, // e.g., 'malcolm_ball_award'
  }) async {
    print(
      "DEBUG: notifyAllUsers called - title: $title, body: $body, eventId: $eventId",
    );
    try {
      final users = await _supabase.from('user_profiles').select('id');

      for (final u in users) {
        try {
          // Embed a route tag into body to support client-side deep linking
          final bodyWithRoute = route != null && route.isNotEmpty
              ? '[route:' + route + '] ' + body
              : body;

          await _supabase.from('notifications').insert({
            'user_id': u['id'],
            'title': title,
            'body': bodyWithRoute,
            'event_id': eventId,
            'is_read': false,
          });
          print("DEBUG: Notification sent to user: ${u['id']}");
        } catch (e) {
          print("DEBUG: Error sending notification to user ${u['id']}: $e");
        }
      }
    } catch (e) {
      print("DEBUG: Error in notifyAllUsers: $e");
    }
  }

  // ---------------------------------------------------------------
  // NOTIFY SPECIFIC USER
  // ---------------------------------------------------------------
  static Future<void> notifyUser({
    required String userId,
    required String title,
    required String body,
    String? eventId,
    String? route, // e.g., 'malcolm_ball_award'
  }) async {
    print(
      "DEBUG: notifyUser called - userId: $userId, title: $title, body: $body, eventId: $eventId",
    );
    final bodyWithRoute = route != null && route.isNotEmpty
        ? '[route:' + route + '] ' + body
        : body;

    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': bodyWithRoute,
      'event_id': eventId,
      'is_read': false,
    });
    print("DEBUG: Notification inserted for user: $userId");
  }

  // ---------------------------------------------------------------
  // NOTIFY EVENT CREATOR
  // ---------------------------------------------------------------
  static Future<void> notifyEventCreator({
    required String eventId,
    required String creatorId,
    required String title,
    required String body,
  }) async {
    print(
      "DEBUG: notifyEventCreator called - creatorId: $creatorId, title: $title, body: $body",
    );
    await notifyUser(
      userId: creatorId,
      title: title,
      body: body,
      eventId: eventId,
    );
  }

  // ---------------------------------------------------------------
  // NOTIFY EVENT PARTICIPANTS
  // ---------------------------------------------------------------
  static Future<void> notifyEventParticipants({
    required String eventId,
    required String title,
    required String body,
    String? excludeUserId,
  }) async {
    print(
      "DEBUG: notifyEventParticipants called - eventId: $eventId, title: $title",
    );
    final responses = await _supabase
        .from('club_event_responses')
        .select('user_id')
        .eq('event_id', eventId);

    print("DEBUG: Found ${responses.length} participants for event $eventId");
    for (final response in responses) {
      final userId = response['user_id'] as String;
      if (excludeUserId != null && userId == excludeUserId) {
        print("DEBUG: Skipping user $userId (excluded)");
        continue;
      }

      await notifyUser(
        userId: userId,
        title: title,
        body: body,
        eventId: eventId,
      );
    }
  }

  // ---------------------------------------------------------------
  // FETCH NOTIFICATIONS FOR CURRENT USER
  // ---------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    print("DEBUG fetchNotifications: $response");

    return response.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------
  // MARK ALL AS READ
  // ---------------------------------------------------------------
  static Future<void> markAllRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  // ---------------------------------------------------------------
  // UNREAD COUNT
  // ---------------------------------------------------------------
  static Future<int> unreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final data = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .eq('is_read', false);

    return data.length;
  }

  // ---------------------------------------------------------------
  // REALTIME UNREAD LISTENER (CORRECT FOR SUPABASE 2.0.0)
  // ---------------------------------------------------------------
  static Stream<int> watchUnreadCountStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print("DEBUG: User is null, returning Stream.value(0)");
      return Stream.value(0);
    }

    print("DEBUG: Creating watchUnreadCountStream for user: ${user.id}");
    final controller = StreamController<int>();

    // Listen to broadcast controller for manual refreshes
    final broadcastSubscription = _unreadCountController.stream.listen(
      (count) {
        print("DEBUG: Broadcast controller update: $count");
        if (!controller.isClosed) {
          controller.add(count);
        }
      },
      onError: (error) {
        print("DEBUG: Broadcast error: $error");
      },
    );

    // Initial push
    () async {
      final count = await unreadCount();
      print("DEBUG: Initial unread count: $count");
      if (!controller.isClosed) {
        controller.add(count);
      }
    }();

    final channel = _supabase
        .channel('notif_changes_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) async {
            final count = await unreadCount();
            print(
              "DEBUG: Postgres change detected! New unread count: $count, Payload: $payload",
            );
            if (!controller.isClosed) {
              controller.add(count);
            }
          },
        )
        .subscribe();

    controller.onCancel = () async {
      print("DEBUG: Stream cancelled, removing channel");
      await broadcastSubscription.cancel();
      await _supabase.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  static void watchUnreadCount(void Function(int) handler) {
    watchUnreadCountStream().listen(
      handler,
      onError: (error) {
        print("DEBUG: Stream error: $error");
      },
      onDone: () {
        print("DEBUG: Stream done");
      },
    );
  }

  // ---------------------------------------------------------------
  // REFRESH UNREAD COUNT (call this after marking as read)
  // ---------------------------------------------------------------
  static Future<void> refreshUnreadCount() async {
    final count = await unreadCount();
    print("DEBUG: Refreshing unread count: $count");
    _unreadCountController.add(count);
  }

  // ---------------------------------------------------------------
  // DELETE ALL NOTIFICATIONS FOR CURRENT USER
  // ---------------------------------------------------------------
  static Future<void> deleteAllNotificationsForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('notifications').delete().eq('user_id', user.id);

      // Ensure badges/streams update
      await refreshUnreadCount();
    } catch (e) {
      print('DEBUG: Error deleting all notifications: $e');
    }
  }

  // ---------------------------------------------------------------
  // EVENT ACTIVITY (UNSEEN EVENTS FOR CLUB HUB)
  // ---------------------------------------------------------------

  static Stream<int> watchEventActivityStream() {
    return _eventActivityController.stream;
  }

  static Future<int> unseenEventCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final seenKey = 'events_seen_ids_${user.id}';
      final seenIds = prefs.getStringList(seenKey) ?? const <String>[];
      // Resolve current user's club and all user IDs in that club so
      // we only count events created within the same club.
      Set<String> clubUserIds = {};

      String? debugClubName;

      try {
        final profile = await _supabase
            .from('user_profiles')
            .select('club')
            .eq('id', user.id)
            .maybeSingle();

        final clubNameRaw = (profile?['club'] as String?)?.trim();
        final clubName = (clubNameRaw != null && clubNameRaw.isNotEmpty)
            ? clubNameRaw
            : null;

        debugClubName = clubName;

        if (clubName != null) {
          final rows = await _supabase
              .from('user_profiles')
              .select('id')
              .eq('club', clubName);

          for (final row in rows as List) {
            final id = row['id'] as String?;
            if (id != null && id.isNotEmpty) {
              clubUserIds.add(id);
            }
          }
        }
      } catch (e) {
        print('DEBUG: unseenEventCount club resolution error: $e');
      }

      print(
        'DEBUG: unseenEventCount for user ${user.id}, club=$debugClubName, clubUserIds=${clubUserIds.length}',
      );

      final rows = await _supabase
          .from('club_events')
          .select('id, date, time, created_by')
          .order('date')
          .order('time');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int count = 0;
      for (final row in rows as List) {
        final dateStr = row['date'] as String?;
        final timeVal = row['time'];
        if (dateStr == null || timeVal == null) continue;

        final timeStr = timeVal.toString().split('.').first;
        DateTime dt;
        try {
          dt = DateTime.parse('$dateStr $timeStr');
        } catch (_) {
          continue;
        }

        final d = DateTime(dt.year, dt.month, dt.day);
        if (d.isBefore(today)) continue;

        // If we have a club-specific user set, only count events
        // created by users in that set.
        if (clubUserIds.isNotEmpty) {
          final createdBy = row['created_by']?.toString();
          if (createdBy == null || !clubUserIds.contains(createdBy)) {
            continue;
          }
        }

        final id = row['id'].toString();
        if (!seenIds.contains(id)) {
          count++;
        }
      }

      print(
        'DEBUG: unseenEventCount final count=$count for user ${user.id}, club=$debugClubName',
      );

      return count;
    } catch (e) {
      print('DEBUG: unseenEventCount error: $e');
      return 0;
    }
  }

  static Future<void> refreshEventActivityCount() async {
    final count = await unseenEventCount();
    print('DEBUG: Refreshing event activity count: $count');
    _eventActivityController.add(count);
  }

  // Fire a local signal when this client creates a new event or marks
  // one as seen. The underlying count is recomputed from Supabase
  // and local "seen" state, so this is safe to call repeatedly.
  static Future<void> signalLocalEventActivityChanged() async {
    await refreshEventActivityCount();
  }

  // ---------------------------------------------------------------
  // POST ACTIVITY (UNSEEN POSTS FOR POSTS TAB BADGE)
  // ---------------------------------------------------------------

  static Future<int> unseenPostActivityCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final seenKey = 'posts_last_seen_${user.id}';
      final lastSeenStr = prefs.getString(seenKey);
      DateTime? lastSeen;
      if (lastSeenStr != null) {
        lastSeen = DateTime.tryParse(lastSeenStr);
      }

      // Resolve current user's club and all user IDs in that club so
      // we only consider posts authored within the same club.
      Set<String> clubUserIds = {};
      String? debugClubName;

      try {
        final profile = await _supabase
            .from('user_profiles')
            .select('club')
            .eq('id', user.id)
            .maybeSingle();

        final clubNameRaw = (profile?['club'] as String?)?.trim();
        final clubName = (clubNameRaw != null && clubNameRaw.isNotEmpty)
            ? clubNameRaw
            : null;

        debugClubName = clubName;

        if (clubName != null) {
          final rows = await _supabase
              .from('user_profiles')
              .select('id')
              .eq('club', clubName);

          for (final row in rows as List) {
            final id = row['id'] as String?;
            if (id != null && id.isNotEmpty) {
              clubUserIds.add(id);
            }
          }
        }
      } catch (e) {
        print('DEBUG: unseenPostActivityCount club resolution error: $e');
      }

      final rows = await _supabase
          .from('club_posts')
          .select('created_at, author_id')
          .order('created_at', ascending: false)
          .limit(50);

      DateTime? latestForClub;
      for (final row in rows as List) {
        final authorId = row['author_id']?.toString();
        if (authorId == null) continue;

        if (clubUserIds.isNotEmpty && !clubUserIds.contains(authorId)) {
          continue;
        }

        final createdAtStr = row['created_at'] as String?;
        if (createdAtStr == null) continue;
        final createdAt = DateTime.tryParse(createdAtStr);
        if (createdAt == null) continue;
        latestForClub = createdAt.toUtc();
        break;
      }

      if (latestForClub == null) {
        return 0;
      }

      if (lastSeen == null || latestForClub.isAfter(lastSeen.toUtc())) {
        print(
          'DEBUG: unseenPostActivityCount -> unseen (user=${user.id}, club=$debugClubName)',
        );
        return 1; // indicate at least one unseen post
      }

      return 0;
    } catch (e) {
      print('DEBUG: unseenPostActivityCount error: $e');
      return 0;
    }
  }

  static Future<void> markPostsSeen() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Find the latest post for this user's club so we can store
      // its timestamp as the "last seen" marker.
      Set<String> clubUserIds = {};

      try {
        final profile = await _supabase
            .from('user_profiles')
            .select('club')
            .eq('id', user.id)
            .maybeSingle();

        final clubNameRaw = (profile?['club'] as String?)?.trim();
        final clubName = (clubNameRaw != null && clubNameRaw.isNotEmpty)
            ? clubNameRaw
            : null;

        if (clubName != null) {
          final rows = await _supabase
              .from('user_profiles')
              .select('id')
              .eq('club', clubName);

          for (final row in rows as List) {
            final id = row['id'] as String?;
            if (id != null && id.isNotEmpty) {
              clubUserIds.add(id);
            }
          }
        }
      } catch (e) {
        print('DEBUG: markPostsSeen club resolution error: $e');
      }

      final rows = await _supabase
          .from('club_posts')
          .select('created_at, author_id')
          .order('created_at', ascending: false)
          .limit(50);

      DateTime? latestForClub;
      for (final row in rows as List) {
        final authorId = row['author_id']?.toString();
        if (authorId == null) continue;

        if (clubUserIds.isNotEmpty && !clubUserIds.contains(authorId)) {
          continue;
        }

        final createdAtStr = row['created_at'] as String?;
        if (createdAtStr == null) continue;
        final createdAt = DateTime.tryParse(createdAtStr);
        if (createdAt == null) continue;
        latestForClub = createdAt.toUtc();
        break;
      }

      if (latestForClub != null) {
        final prefs = await SharedPreferences.getInstance();
        final seenKey = 'posts_last_seen_${user.id}';
        await prefs.setString(seenKey, latestForClub.toIso8601String());
      }
    } catch (e) {
      print('DEBUG: markPostsSeen error: $e');
    }
  }
}
