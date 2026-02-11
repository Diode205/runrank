import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

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
      // 20M: accept common naming variants in the database
      // ("20M", "20m", "20 mile", "20 Mile").
      if (distance == '20M') {
        final response = await _supabase
            .from('club_records')
            .select()
            .inFilter('distance', ['20M', '20m', '20 mile', '20 Mile'])
            .order('time_seconds', ascending: true)
            .limit(limit);

        return (response as List)
            .map((json) => ClubRecord.fromJson(json))
            .toList();
      }

      // Ultra records: rank by distance covered (parsed from race name),
      // not by time. For other distances, keep fastest-time order.
      if (distance == 'Ultra') {
        final response = await _supabase
            .from('club_records')
            .select()
            .eq('distance', distance);

        final List<ClubRecord> all = (response as List)
            .map((json) => ClubRecord.fromJson(json))
            .toList();

        all.sort((a, b) {
          final da = _parseUltraDistanceScore(a.raceName);
          final db = _parseUltraDistanceScore(b.raceName);
          // Larger distance first; if equal, fall back to faster time.
          final cmp = db.compareTo(da);
          if (cmp != 0) return cmp;
          return a.timeSeconds.compareTo(b.timeSeconds);
        });

        if (all.length > limit) {
          return all.take(limit).toList();
        }
        return all;
      }

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

  /// For Ultra, extract a numeric distance from the race name.
  /// Examples handled: "Ultra 50K", "Ultra 100 km", "My Ultra — 32 miles".
  /// Returned value is in kilometres so larger = further.
  static double _parseUltraDistanceScore(String raceName) {
    final text = raceName.toLowerCase();

    // Look for a number followed by a unit.
    final unitPattern = RegExp(
      r'(\d+(?:\.\d+)?)\s*(k|km|kilometre|kilometer|mile|miles|mi)\b',
    );
    final unitMatch = unitPattern.firstMatch(text);
    if (unitMatch != null) {
      final value = double.tryParse(unitMatch.group(1) ?? '');
      if (value == null) return 0;
      final unit = unitMatch.group(2) ?? '';
      if (unit.startsWith('k')) {
        // Kilometres
        return value;
      } else {
        // Miles -> km
        return value * 1.60934;
      }
    }

    // Fallback: bare number with no unit, treat as km
    final numberPattern = RegExp(r'(\d+(?:\.\d+)?)');
    final numberMatch = numberPattern.firstMatch(text);
    if (numberMatch != null) {
      final value = double.tryParse(numberMatch.group(1) ?? '');
      return value ?? 0;
    }

    return 0;
  }

  /// Fetch top records for all distances
  Future<Map<String, List<ClubRecord>>> getAllTopRecords({
    int limitPerDistance = 5,
  }) async {
    final distances = [
      '5K',
      '5M',
      '10K',
      '10M',
      'Half M',
      'Marathon',
      '20M',
      'Ultra',
    ];
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

      // Notify all users that a new club record has been set
      try {
        final runner = record.runnerName;
        final distance = record.distance;
        final time = record.formattedTime;
        await NotificationService.notifyAllUsers(
          title: 'New club record set',
          body: '$runner set a new $distance club record in $time.',
          // Use a route tag so Alerts can deep-link to Club Records
          route: 'club_records',
        );
      } catch (e) {
        print('Error sending club record notification: $e');
      }
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
      final distances = [
        '5K',
        '5M',
        '10K',
        '10M',
        'Half M',
        'Marathon',
        '20M',
        'Ultra',
      ];

      for (final distance in distances) {
        // Get top times from race_results for this distance
        dynamic query = _supabase
            .from('race_results')
            .select('user_id, race_name, distance, time_seconds, raceDate');

        if (distance == '20M') {
          // Accept common legacy labels for 20 mile races
          query = query.inFilter('distance', [
            '20M',
            '20m',
            '20 mile',
            '20 Mile',
          ]);
        } else {
          query = query.eq('distance', distance);
        }

        final raceResults = await query
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
              .select('id, runner_name')
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
          } else {
            // Ensure existing record's name is kept in sync with profile
            final existingId = existing['id'] as String?;
            final existingName = existing['runner_name'] as String?;
            if (existingId != null && existingName != runnerName) {
              await _supabase
                  .from('club_records')
                  .update({'runner_name': runnerName})
                  .eq('id', existingId);
            }
          }
        }
      }
    } catch (e) {
      print('Error syncing club records: $e');
    }
  }

  /// Ensure there is a club record for a just-submitted race result.
  /// Used mainly for 20M and Ultra so their club records appear immediately
  /// without waiting on a full sync.
  Future<void> ensureRecordForResult({
    required String userId,
    required String distance,
    required int timeSeconds,
    required String raceName,
    required DateTime raceDate,
  }) async {
    try {
      // Look up the latest profile name for this user
      final profile = await _supabase
          .from('user_profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final runnerName =
          (profile != null ? profile['full_name'] as String? : null) ??
          'Unknown';

      // Check for an existing record with same user, distance and time
      final existing = await _supabase
          .from('club_records')
          .select('id')
          .eq('user_id', userId)
          .eq('distance', distance)
          .eq('time_seconds', timeSeconds)
          .maybeSingle();

      if (existing == null) {
        final record = ClubRecord(
          id: '',
          distance: distance,
          timeSeconds: timeSeconds,
          runnerName: runnerName,
          userId: userId,
          raceName: raceName.isEmpty ? 'Untitled race' : raceName,
          raceDate: raceDate,
          isHistorical: false,
        );

        await addRecord(record);
      } else {
        final existingId = existing['id'] as String?;
        if (existingId != null) {
          await _supabase
              .from('club_records')
              .update({'runner_name': runnerName})
              .eq('id', existingId);
        }
      }
    } catch (e) {
      print('Error ensuring club record for result: $e');
    }
  }
}
