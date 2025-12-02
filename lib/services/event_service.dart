import 'package:supabase_flutter/supabase_flutter.dart';

class EventService {
  static final _client = Supabase.instance.client;

  static Future<String> createEvent({
    required String eventType,
    int? trainingNumber,
    String? raceName,
    String? handicapDistance,
    required String title,
    required DateTime dateTime,
    required String hostOrDirector,
    required String venue,
    String? venueAddress,
    required String description,
    DateTime? marshalCallDate,
    String? relayTeam,
  }) async {
    final data = {
      'event_type': eventType,
      'training_number': trainingNumber,
      'race_name': raceName,
      'handicap_distance': handicapDistance,
      'title': title,
      'date': dateTime.toIso8601String(),
      'time': dateTime.toIso8601String(),
      'host_or_director': hostOrDirector,
      'venue': venue,
      'venue_address': venueAddress,
      'description': description,
      'marshal_call_date': marshalCallDate?.toIso8601String(),
      'relay_team': relayTeam,
    };

    final response = await _client
        .from('club_events')
        .insert(data)
        .select('id')
        .single();

    return response['id'] as String;
  }
}
