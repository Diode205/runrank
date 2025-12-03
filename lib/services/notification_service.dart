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
    required String eventId,
  }) async {
    final users = await _supabase.from('user_profiles').select('id');

    for (final u in users) {
      await _supabase.from('notifications').insert({
        'user_id': u['id'],
        'title': title,
        'body': body,
        'event_id': eventId,
        'is_read': false,
      });
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

    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
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
