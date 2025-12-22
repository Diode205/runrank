// lib/services/notification_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;
  static final _unreadCountController = StreamController<int>.broadcast();

  // ---------------------------------------------------------------
  // SEND NOTIFICATION TO ALL USERS
  // ---------------------------------------------------------------
  static Future<void> notifyAllUsers({
    required String title,
    required String body,
    String? eventId,
  }) async {
    print(
      "DEBUG: notifyAllUsers called - title: $title, body: $body, eventId: $eventId",
    );
    final users = await _supabase.from('user_profiles').select('id');

    for (final u in users) {
      await _supabase.from('notifications').insert({
        'user_id': u['id'],
        'title': title,
        'body': body,
        'event_id': eventId,
        'is_read': false,
      });
      print("DEBUG: Notification sent to user: ${u['id']}");
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
  }) async {
    print(
      "DEBUG: notifyUser called - userId: $userId, title: $title, body: $body, eventId: $eventId",
    );
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
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
}
