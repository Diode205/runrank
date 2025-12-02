import 'package:supabase_flutter/supabase_flutter.dart';

class EventResponseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Submit or update a single response for an event.
  /// Always ensures ONE row per (event_id, user_id).
  static Future<bool> submitResponse({
    required String eventId,
    required String userId,
    required String
    responseType, // attending, unavailable, running, marshalling, supporting
    int? expectedTimeSeconds, // handicap only
  }) async {
    try {
      await _client.from('club_event_responses').upsert({
        'event_id': eventId,
        'user_id': userId,
        'response_type': responseType,
        'expected_time_seconds': expectedTimeSeconds,
      });

      return true;
    } catch (e) {
      print('❌ Error submitting response: $e');
      return false;
    }
  }

  /// Get counts of each response type for an event.
  static Future<Map<String, int>> getResponseCounts(String eventId) async {
    final Map<String, int> counts = {
      'attending': 0,
      'unavailable': 0,
      'running': 0,
      'marshalling': 0,
      'supporting': 0,
    };

    try {
      final rows = await _client
          .from('club_event_responses')
          .select('response_type')
          .eq('event_id', eventId);

      for (final row in rows) {
        final type = row['response_type'] as String?;
        if (type != null && counts.containsKey(type)) {
          counts[type] = counts[type]! + 1;
        }
      }
    } catch (e) {
      print('❌ Error getting response counts: $e');
    }

    return counts;
  }

  /// Fetch responders WITH their full names (joined from user_profiles).
  static Future<List<Map<String, dynamic>>> getRespondersWithNames({
    required String eventId,
    required String responseType,
  }) async {
    try {
      // First: get ALL matching responses
      final responseRows = await _client
          .from('club_event_responses')
          .select('user_id, expected_time_seconds')
          .eq('event_id', eventId)
          .eq('response_type', responseType);

      if (responseRows.isEmpty) return [];

      // Extract UNIQUE user IDs
      final userIds = <String>{
        for (final row in responseRows) row['user_id'] as String,
      }.toList();

      // Fetch profiles for each ID — using contains() (new API)
      final profileRows = await _client
          .from('user_profiles')
          .select('id, full_name')
          .contains('id', userIds);

      final Map<String, String> idToName = {
        for (final p in profileRows)
          p['id'] as String: (p['full_name'] as String?) ?? 'Unknown runner',
      };

      // Merge response rows with profile names
      final List<Map<String, dynamic>> result = [];

      for (final row in responseRows) {
        final uid = row['user_id'] as String;
        result.add({
          'userId': uid,
          'fullName': idToName[uid] ?? 'Unknown runner',
          'expectedTimeSeconds': row['expected_time_seconds'] as int?,
        });
      }

      return result;
    } catch (e) {
      print('❌ Error fetching responders with names: $e');
      return [];
    }
  }

  /// Save expected handicap time without changing response type.
  static Future<bool> submitExpectedTime({
    required String eventId,
    required String userId,
    required int expectedTimeSeconds,
  }) async {
    try {
      await _client.from('club_event_responses').upsert({
        'event_id': eventId,
        'user_id': userId,
        'expected_time_seconds': expectedTimeSeconds,
      });

      return true;
    } catch (e) {
      print('❌ Error saving expected handicap time: $e');
      return false;
    }
  }
}
