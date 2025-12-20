// lib/services/notification_service.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------
  // SEND NOTIFICATION TO ALL USERS
  // ---------------------------------------------------------------
  static Future<void> notifyAllUsers({
    required String title,
    required String body,
    String? eventId,
    String? targetScreen,
  }) async {
    final users = await _supabase.from('user_profiles').select('id');

    for (final u in users) {
      await _supabase.from('notifications').insert({
        'user_id': u['id'],
        'title': title,
        'body': body,
        'event_id': eventId,
        'target_screen': targetScreen,
        'is_read': false,
      });
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
    String? targetScreen,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'event_id': eventId,
      'target_screen': targetScreen,
      'is_read': false,
    });
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
    await notifyUser(
      userId: creatorId,
      title: title,
      body: body,
      eventId: eventId,
      targetScreen: 'event_details',
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
    final responses = await _supabase
        .from('club_event_responses')
        .select('user_id')
        .eq('event_id', eventId);

    for (final response in responses) {
      final userId = response['user_id'] as String;
      if (excludeUserId != null && userId == excludeUserId) continue;

      await notifyUser(
        userId: userId,
        title: title,
        body: body,
        eventId: eventId,
        targetScreen: 'event_details',
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
    if (user == null) return Stream.value(0);

    final controller = StreamController<int>();

    // Initial push
    () async {
      controller.add(await unreadCount());
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
            controller.add(await unreadCount());
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await _supabase.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  static void watchUnreadCount(void Function(int) handler) {
    watchUnreadCountStream().listen(handler);
  }
}
