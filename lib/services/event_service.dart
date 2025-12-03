// lib/services/event_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class EventService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ------------------------------------------------------
  // CREATE EVENT (returns new event ID)
  // ------------------------------------------------------
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
    double? latitude,
    double? longitude,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw "Not logged in";

    // Convert date/time into Supabase columns:
    final eventDate =
        "${dateTime.year.toString().padLeft(4, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.day.toString().padLeft(2, '0')}";

    final eventTime =
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";

    // Build insert payload EXACTLY matching your Supabase table
    final payload = {
      "event_type": eventType,
      "training_number": trainingNumber,
      "race_name": raceName,
      "handicap_distance": handicapDistance,
      "relay_team": relayTeam,

      "title": title,
      "date": eventDate,
      "time": eventTime,

      "host_or_director": hostOrDirector,
      "venue": venue,
      "venue_address": venueAddress,
      "description": description,

      "marshal_call_date": marshalCallDate?.toIso8601String(),

      "latitude": latitude,
      "longitude": longitude,

      // This MUST exist in table
      "created_by": user.id,
    };

    // INSERT
    final response = await _supabase
        .from("club_events")
        .insert(payload)
        .select("id")
        .single();

    return response["id"] as String;
  }

  // ------------------------------------------------------
  // FETCH EVENTS (Upcoming)
  // ------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchEvents() async {
    final rows = await _supabase
        .from("club_events")
        .select()
        .order("date", ascending: true)
        .order("time", ascending: true);

    return rows;
  }
}
