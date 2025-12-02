// lib/services/notification_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _client = Supabase.instance.client;

  // ----------------------------------------------------------------------
  // SEND NOTIFICATION TO ALL USERS
  // ----------------------------------------------------------------------
  static Future<void> notifyAllUsers({
    required String title,
    required String body,
    String? eventId,
  }) async {
    final users = await _client.from('user_profiles').select('id');

    final rows = users.map((u) {
      return {
        'user_id': u['id'],
        'title': title,
        'body': body,
        'event_id': eventId,
        'is_read': false,
      };
    }).toList();

    await _client.from('notifications').insert(rows);
  }

  // ----------------------------------------------------------------------
  // FETCH NOTIFICATIONS
  // ----------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  // ----------------------------------------------------------------------
  // COUNT UNREAD
  // ----------------------------------------------------------------------
  static Future<int> unreadCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .eq('is_read', false);

    return data.length;
  }

  // ----------------------------------------------------------------------
  // MARK ALL READ
  // ----------------------------------------------------------------------
  static Future<void> markAllRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  // ----------------------------------------------------------------------
  // REALTIME UNREAD BADGE LISTENER
  // ----------------------------------------------------------------------
  static RealtimeChannel? _channel;

  static void watchUnreadCount(void Function(int count) callback) {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // close previous channel if exists
    _channel?.unsubscribe();
    _channel = null;

    _channel = _client.channel('public:notifications')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (payload) async {
          final row = payload.newRecord;
          if (row['user_id'] == user.id) {
            final count = await unreadCount();
            callback(count);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'notifications',
        callback: (payload) async {
          final row = payload.newRecord;
          if (row['user_id'] == user.id) {
            final count = await unreadCount();
            callback(count);
          }
        },
      )
      ..subscribe();
  }
}
