import 'package:flutter/material.dart';

class ClubEvent {
  final String id;
  final DateTime? createdAt;
  final String? createdBy;

  final String eventType;
  final int? trainingNumber;
  final String? raceName;
  final String? handicapDistance;

  final String? title;
  final DateTime dateTime; // Combined date + time

  final String hostOrDirector;
  final String venue;
  final String venueAddress;
  final String description;

  final DateTime? marshalCallDate;

  final double? latitude;
  final double? longitude;

  final String? relayTeam;
  final bool isCancelled;
  final String? cancelReason;

  final List<Map<String, dynamic>>? relayStages; // parsed JSON
  final bool expectedTimeRequired;

  ClubEvent({
    required this.id,
    required this.createdAt,
    required this.createdBy,
    required this.eventType,
    required this.trainingNumber,
    required this.raceName,
    required this.handicapDistance,
    required this.title,
    required this.dateTime,
    required this.hostOrDirector,
    required this.venue,
    required this.venueAddress,
    required this.description,
    required this.marshalCallDate,
    required this.latitude,
    required this.longitude,
    required this.relayTeam,
    required this.isCancelled,
    required this.cancelReason,
    required this.relayStages,
    required this.expectedTimeRequired,
  });

  /// ---------------------------------------------------------------------------
  /// PARSE FROM SUPABASE
  /// ---------------------------------------------------------------------------
  factory ClubEvent.fromSupabase(Map<String, dynamic> row) {
    // Combine date + time into one DateTime
    final dateStr = row['date'] as String;
    final timeStr = (row['time'] as String).split('.').first;

    final dt = DateTime.parse("$dateStr $timeStr");

    // Parse relay stages JSON
    List<Map<String, dynamic>>? stages;
    if (row['relay_stages_json'] != null) {
      final json = row['relay_stages_json'] as List<dynamic>;
      stages = json.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return ClubEvent(
      id: row['id'].toString(),
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at']),
      createdBy: row['created_by']?.toString(),
      eventType: row['event_type'] ?? "event",
      trainingNumber: row['training_number'],
      raceName: row['race_name'],
      handicapDistance: row['handicap_distance'],
      title: row['title'],
      dateTime: dt,
      hostOrDirector: row['host_or_director'] ?? "",
      venue: row['venue'] ?? "",
      venueAddress: row['venue_address'] ?? "",
      description: row['description'] ?? "",
      marshalCallDate: row['marshal_call_date'] == null
          ? null
          : DateTime.parse(row['marshal_call_date']),
      latitude: row['latitude'] == null
          ? null
          : (row['latitude'] as num).toDouble(),
      longitude: row['longitude'] == null
          ? null
          : (row['longitude'] as num).toDouble(),
      relayTeam: row['relay_team'],
      isCancelled: row['is_cancelled'] ?? false,
      cancelReason: row['cancel_reason'],
      relayStages: stages,
      expectedTimeRequired: row['expected_time_required'] ?? false,
    );
  }
}
