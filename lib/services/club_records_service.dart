import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class ClubRecord {
  final String id;
  final String distance;
  final int timeSeconds;
  final String runnerName;
  final String? userId;
  final String? club;
  final String? gender;
  final String raceName;
  final DateTime raceDate;
  final bool isHistorical;

  ClubRecord({
    required this.id,
    required this.distance,
    required this.timeSeconds,
    required this.runnerName,
    this.userId,
    this.club,
    this.gender,
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
      club: json['club'] as String?,
      gender: json['gender'] as String?,
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
      if (club != null) 'club': club,
      if (gender != null) 'gender': gender,
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

  String? _cachedClubName;
  bool _clubLoaded = false;
  Set<String>? _cachedClubUserIds;
  bool _clubUserIdsLoaded = false;
  String? _cachedUserGender;
  bool _userGenderLoaded = false;

  Future<String?> _getCurrentUserClub() async {
    if (_clubLoaded) return _cachedClubName;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clubLoaded = true;
      _cachedClubName = null;
      return null;
    }

    try {
      final row = await _supabase
          .from('user_profiles')
          .select('club')
          .eq('id', user.id)
          .maybeSingle();

      final club = (row?['club'] as String?)?.trim();
      _cachedClubName = (club != null && club.isNotEmpty) ? club : null;
      _clubLoaded = true;
      return _cachedClubName;
    } catch (e) {
      print('Error fetching current user club for club records: $e');
      _clubLoaded = true;
      _cachedClubName = null;
      return null;
    }
  }

  Future<String?> _getCurrentUserGender() async {
    if (_userGenderLoaded) return _cachedUserGender;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _userGenderLoaded = true;
      _cachedUserGender = null;
      return null;
    }

    try {
      final row = await _supabase
          .from('user_profiles')
          .select('gender')
          .eq('id', user.id)
          .maybeSingle();

      final raw = (row?['gender'] as String?)?.trim().toUpperCase();
      if (raw == 'M' || raw == 'F') {
        _cachedUserGender = raw;
      } else {
        _cachedUserGender = null;
      }
      _userGenderLoaded = true;
      return _cachedUserGender;
    } catch (e) {
      print('Error fetching current user gender for club records: $e');
      _userGenderLoaded = true;
      _cachedUserGender = null;
      return null;
    }
  }

  String? _normalizeGender(String? raw) {
    final normalized = raw?.trim().toUpperCase();
    return normalized == 'M' || normalized == 'F' ? normalized : null;
  }

  bool _isMissingScopedClubRecordColumns(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('club_records') &&
        message.contains('column') &&
        (message.contains(' club ') ||
            message.contains('"club"') ||
            message.contains(' gender ') ||
            message.contains('"gender"'));
  }

  Future<Set<String>> _getLegacyClubUserIds(String? genderFilter) async {
    final club = await _getCurrentUserClub();
    if (club == null) return {};

    if (genderFilter == null &&
        _clubUserIdsLoaded &&
        _cachedClubUserIds != null) {
      return _cachedClubUserIds!;
    }

    try {
      var query = _supabase.from('user_profiles').select('id').eq('club', club);

      final normalizedGender = _normalizeGender(genderFilter);
      if (normalizedGender != null) {
        query = query.eq('gender', normalizedGender);
      }

      final rows = await query;
      final ids = <String>{};
      for (final row in rows as List) {
        final id = row['id'] as String?;
        if (id != null && id.isNotEmpty) {
          ids.add(id);
        }
      }

      if (genderFilter == null) {
        _cachedClubUserIds = ids;
        _clubUserIdsLoaded = true;
      }

      return ids;
    } catch (e) {
      print('Error fetching legacy club user IDs: $e');
      if (genderFilter == null) {
        _cachedClubUserIds = {};
        _clubUserIdsLoaded = true;
      }
      return {};
    }
  }

  Future<List<ClubRecord>> _fetchScopedRecords(
    String distance, {
    String? genderFilter,
  }) async {
    final currentClub = await _getCurrentUserClub();
    final normalizedGender = _normalizeGender(genderFilter);

    dynamic query = _supabase.from('club_records').select();

    if (distance == '20M') {
      query = query.inFilter('distance', ['20M', '20m', '20 mile', '20 Mile']);
    } else {
      query = query.eq('distance', distance);
    }

    if (currentClub != null && currentClub.isNotEmpty) {
      query = query.eq('club', currentClub);
    }

    if (normalizedGender != null) {
      query = query.eq('gender', normalizedGender);
    }

    if (distance != 'Ultra') {
      query = query.order('time_seconds', ascending: true);
    }

    final response = await query;
    return (response as List).map((json) => ClubRecord.fromJson(json)).toList();
  }

  Future<List<ClubRecord>> _fetchLegacyRecords(
    String distance, {
    int limit = 5,
    String? genderFilter,
  }) async {
    final userIds = await _getLegacyClubUserIds(genderFilter);
    final applyClubFilter = userIds.isNotEmpty;
    final userIdList = userIds.toList();

    if (distance == '20M') {
      final response = applyClubFilter
          ? await _supabase
                .from('club_records')
                .select()
                .inFilter('distance', ['20M', '20m', '20 mile', '20 Mile'])
                .inFilter('user_id', userIdList)
                .order('time_seconds', ascending: true)
                .limit(limit)
          : await _supabase
                .from('club_records')
                .select()
                .inFilter('distance', ['20M', '20m', '20 mile', '20 Mile'])
                .order('time_seconds', ascending: true)
                .limit(limit);

      return (response as List)
          .map((json) => ClubRecord.fromJson(json))
          .toList();
    }

    if (distance == 'Ultra') {
      final response = applyClubFilter
          ? await _supabase
                .from('club_records')
                .select()
                .eq('distance', distance)
                .inFilter('user_id', userIdList)
          : await _supabase
                .from('club_records')
                .select()
                .eq('distance', distance);

      final List<ClubRecord> all = (response as List)
          .map((json) => ClubRecord.fromJson(json))
          .toList();

      all.sort((a, b) {
        final da = _parseUltraDistanceScore(a.raceName);
        final db = _parseUltraDistanceScore(b.raceName);
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return a.timeSeconds.compareTo(b.timeSeconds);
      });

      return all.length > limit ? all.take(limit).toList() : all;
    }

    final response = applyClubFilter
        ? await _supabase
              .from('club_records')
              .select()
              .eq('distance', distance)
              .inFilter('user_id', userIdList)
              .order('time_seconds', ascending: true)
              .limit(limit)
        : await _supabase
              .from('club_records')
              .select()
              .eq('distance', distance)
              .order('time_seconds', ascending: true)
              .limit(limit);

    return (response as List).map((json) => ClubRecord.fromJson(json)).toList();
  }

  /// Fetch top N records for a specific distance
  Future<List<ClubRecord>> getTopRecords(
    String distance, {
    int limit = 5,
    String? genderFilter,
  }) async {
    try {
      final records = await _fetchScopedRecords(
        distance,
        genderFilter: genderFilter,
      );

      if (distance == 'Ultra') {
        records.sort((a, b) {
          final da = _parseUltraDistanceScore(a.raceName);
          final db = _parseUltraDistanceScore(b.raceName);
          final cmp = db.compareTo(da);
          if (cmp != 0) return cmp;
          return a.timeSeconds.compareTo(b.timeSeconds);
        });
      }

      return records.length > limit ? records.take(limit).toList() : records;
    } catch (e) {
      if (_isMissingScopedClubRecordColumns(e)) {
        try {
          return await _fetchLegacyRecords(
            distance,
            limit: limit,
            genderFilter: genderFilter,
          );
        } catch (legacyError) {
          print(
            'Error fetching legacy club records for $distance after scoped fallback: $legacyError',
          );
          return [];
        }
      }

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
    String? genderFilter,
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
        genderFilter: genderFilter,
      );
    }

    return results;
  }

  /// Get the fastest record for a distance (club record holder)
  Future<ClubRecord?> getClubRecordHolder(
    String distance, {
    String? genderFilter,
  }) async {
    try {
      final records = await getTopRecords(
        distance,
        limit: 1,
        genderFilter: genderFilter,
      );
      return records.isNotEmpty ? records.first : null;
    } catch (e) {
      print('Error fetching club record holder for $distance: $e');
      return null;
    }
  }

  /// Public helper so UI code can pick a sensible default gender filter
  /// for club records based on the current user's profile.
  Future<String?> getDefaultGenderFilter() => _getCurrentUserGender();

  /// Add a new club record (admin only)
  Future<bool> addRecord(ClubRecord record) async {
    try {
      final currentClub = await _getCurrentUserClub();
      final payload = record.toJson();
      payload['club'] = record.club ?? currentClub;
      payload['gender'] =
          _normalizeGender(record.gender) ??
          _normalizeGender(await _getCurrentUserGender());

      try {
        await _supabase.from('club_records').insert(payload);
      } catch (e) {
        if (!_isMissingScopedClubRecordColumns(e)) {
          rethrow;
        }

        payload.remove('club');
        payload.remove('gender');
        await _supabase.from('club_records').insert(payload);
      }

      // Notify users in the current admin's club that a new club record has been set
      try {
        final runner = record.runnerName;
        final distance = record.distance;
        final time = record.formattedTime;

        // Encode the distance into the route so Alerts can deep-link
        // directly to the correct distance tab. Spaces are replaced
        // with underscores for a route-safe token.
        final distanceToken = distance.replaceAll(' ', '_');
        // Scope notifications strictly to the club of the admin
        // who is adding the record. This avoids any possibility of
        // cross-club leakage due to runner profiles or data issues.
        final clubName = currentClub;

        if (clubName != null && clubName.isNotEmpty) {
          await NotificationService.notifyUsersInClub(
            clubName: clubName,
            title: 'New club record set',
            body: '$runner set a new $distance club record in $time.',
            // e.g. [route:club_records/10K] or [route:club_records/Half_M]
            route: 'club_records/' + distanceToken,
          );
        } else {
          // If we cannot resolve a club at all, skip sending a
          // notification rather than broadcasting across all clubs.
          // This avoids cross-club leakage of record activity.
          print(
            'ClubRecordsService.addRecord: Skipping notification because club could not be resolved for distance $distance and runner $runner',
          );
        }
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
      final payload = record.toJson();
      payload['club'] = record.club ?? await _getCurrentUserClub();
      payload['gender'] =
          _normalizeGender(record.gender) ??
          _normalizeGender(await _getCurrentUserGender());

      try {
        await _supabase.from('club_records').update(payload).eq('id', id);
      } catch (e) {
        if (!_isMissingScopedClubRecordColumns(e)) {
          rethrow;
        }

        payload.remove('club');
        payload.remove('gender');
        await _supabase.from('club_records').update(payload).eq('id', id);
      }
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
              .select('full_name, club, gender')
              .eq('id', userId)
              .maybeSingle();

          if (profile == null) continue;

          final runnerName = profile['full_name'] as String? ?? 'Unknown';
          final club = profile['club'] as String?;
          final gender = _normalizeGender(profile['gender'] as String?);
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
              club: club,
              gender: gender,
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
          .select('full_name, club, gender')
          .eq('id', userId)
          .maybeSingle();

      final runnerName =
          (profile != null ? profile['full_name'] as String? : null) ??
          'Unknown';
      final club = profile != null ? profile['club'] as String? : null;
      final gender = profile != null
          ? _normalizeGender(profile['gender'] as String?)
          : null;

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
          club: club,
          gender: gender,
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
