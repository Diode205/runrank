import 'package:supabase_flutter/supabase_flutter.dart';

class ClubRecord {
  final String id;
  final String distance;
  final int timeSeconds;
  final String runnerName;
  final String? userId;
  final String raceName;
  final DateTime raceDate;
  final bool isHistorical;

  ClubRecord({
    required this.id,
    required this.distance,
    required this.timeSeconds,
    required this.runnerName,
    this.userId,
    required this.raceName,
    required this.raceDate,
    this.isHistorical = false,
  });

  factory ClubRecord.fromJson(Map<String, dynamic> json) {
    return ClubRecord(
      id: json['id'] as String,
      distance: json['distance'] as String,
      timeSeconds: json['time_seconds'] as int,
      runnerName: json['runner_name'] as String,
      userId: json['user_id'] as String?,
      raceName: json['race_name'] as String,
      raceDate: DateTime.parse(json['race_date'] as String),
      isHistorical: json['is_historical'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'time_seconds': timeSeconds,
      'runner_name': runnerName,
      'user_id': userId,
      'race_name': raceName,
      'race_date': raceDate.toIso8601String().split('T')[0],
      'is_historical': isHistorical,
    };
  }

  String get formattedTime {
    final hours = timeSeconds ~/ 3600;
    final minutes = (timeSeconds % 3600) ~/ 60;
    final seconds = timeSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
    } else {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
  }
}

class ClubRecordsService {
  final _supabase = Supabase.instance.client;

  /// Fetch top N records for a specific distance
  Future<List<ClubRecord>> getTopRecords(
    String distance, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('club_records')
          .select()
          .eq('distance', distance)
          .order('time_seconds', ascending: true)
          .limit(limit);

      return (response as List)
          .map((json) => ClubRecord.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching club records for $distance: $e');
      return [];
    }
  }

  /// Fetch top records for all distances
  Future<Map<String, List<ClubRecord>>> getAllTopRecords({
    int limitPerDistance = 5,
  }) async {
    final distances = ['5K', '5M', '10K', '10M', 'Half M', 'Marathon'];
    final Map<String, List<ClubRecord>> results = {};

    for (final distance in distances) {
      results[distance] = await getTopRecords(
        distance,
        limit: limitPerDistance,
      );
    }

    return results;
  }

  /// Get the fastest record for a distance (club record holder)
  Future<ClubRecord?> getClubRecordHolder(String distance) async {
    try {
      final records = await getTopRecords(distance, limit: 1);
      return records.isNotEmpty ? records.first : null;
    } catch (e) {
      print('Error fetching club record holder for $distance: $e');
      return null;
    }
  }

  /// Add a new club record (admin only)
  Future<bool> addRecord(ClubRecord record) async {
    try {
      await _supabase.from('club_records').insert(record.toJson());
      return true;
    } catch (e) {
      print('Error adding club record: $e');
      return false;
    }
  }

  /// Update an existing record (admin only)
  Future<bool> updateRecord(String id, ClubRecord record) async {
    try {
      await _supabase.from('club_records').update(record.toJson()).eq('id', id);
      return true;
    } catch (e) {
      print('Error updating club record: $e');
      return false;
    }
  }

  /// Delete a record (admin only)
  Future<bool> deleteRecord(String id) async {
    try {
      await _supabase.from('club_records').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting club record: $e');
      return false;
    }
  }

  /// Auto-sync: Check race_results and update club records if new PRs exist
  Future<void> syncFromRaceResults() async {
    try {
      final distances = ['5K', '5M', '10K', '10M', 'Half M', 'Marathon'];

      for (final distance in distances) {
        // Get top 5 times from race_results for this distance
        final raceResults = await _supabase
            .from('race_results')
            .select('user_id, race_name, distance, time_seconds, raceDate')
            .eq('distance', distance)
            .order('time_seconds', ascending: true)
            .limit(10);

        // Get user names
        for (final result in raceResults) {
          final userId = result['user_id'] as String?;
          if (userId == null) continue;

          // Fetch user's name
          final profile = await _supabase
              .from('user_profiles')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();

          if (profile == null) continue;

          final runnerName = profile['full_name'] as String? ?? 'Unknown';
          final timeSeconds = result['time_seconds'] as int?;
          if (timeSeconds == null || timeSeconds <= 0) continue;

          // Check if this record already exists
          final existing = await _supabase
              .from('club_records')
              .select('id')
              .eq('user_id', userId)
              .eq('distance', distance)
              .eq('time_seconds', timeSeconds)
              .maybeSingle();

          if (existing == null) {
            // Add as a potential club record
            final record = ClubRecord(
              id: '',
              distance: distance,
              timeSeconds: timeSeconds,
              runnerName: runnerName,
              userId: userId,
              raceName: result['race_name'] as String? ?? 'Unknown Race',
              raceDate: DateTime.parse(result['raceDate'] as String),
              isHistorical: false,
            );

            await addRecord(record);
          }
        }
      }
    } catch (e) {
      print('Error syncing club records: $e');
    }
  }
}
