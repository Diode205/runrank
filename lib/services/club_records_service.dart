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

  static String canonicalClubName(String? clubName) {
    final normalized = (clubName ?? '').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'nrr' ||
        lower == 'norwich-road-runners' ||
        lower.contains('norwich road runners')) {
      return 'Norwich Road Runners';
    }
    if (lower == 'nnbr' ||
        lower == 'north-norfolk-beach-runners' ||
        lower.contains('north norfolk beach runners')) {
      return 'NNBR (North Norfolk Beach Runners)';
    }
    return normalized;
  }

  static List<String> _clubAliases(String? clubName) {
    final canonical = canonicalClubName(clubName);
    if (canonical.isEmpty) return const [];
    if (canonical == 'Norwich Road Runners') {
      return const [
        'NRR',
        'nrr',
        'Norwich Road Runners',
        'norwich-road-runners',
      ];
    }
    if (canonical == 'NNBR (North Norfolk Beach Runners)') {
      return const [
        'NNBR',
        'nnbr',
        'NNBR (North Norfolk Beach Runners)',
        'North Norfolk Beach Runners',
        'north-norfolk-beach-runners',
      ];
    }
    return [canonical];
  }

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

      final club = canonicalClubName(row?['club'] as String?);
      _cachedClubName = club.isNotEmpty ? club : null;
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

      _cachedUserGender = _normalizeGender(row?['gender'] as String?);
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
    if (normalized == 'M' || normalized == 'MALE' || normalized == "MEN'S") {
      return 'M';
    }
    if (normalized == 'F' ||
        normalized == 'FEMALE' ||
        normalized == "WOMEN'S") {
      return 'F';
    }
    return null;
  }

  String _recordSyncKey(int timeSeconds, String raceName, String raceDate) {
    return '$timeSeconds|${raceName.trim()}|$raceDate';
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
      var query = _supabase
          .from('user_profiles')
          .select('id, club')
          .inFilter('club', _clubAliases(club));

      final normalizedGender = _normalizeGender(genderFilter);
      if (normalizedGender != null) {
        query = query.eq('gender', normalizedGender);
      }

      final rows = await query;
      final ids = <String>{};
      for (final row in rows as List) {
        final id = row['id'] as String?;
        final rowClub = canonicalClubName(row['club'] as String?);
        if (rowClub != club) continue;
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

  Future<Map<String, Map<String, dynamic>>> _getClubProfiles(
    String? genderFilter,
  ) async {
    final club = await _getCurrentUserClub();
    if (club == null || club.isEmpty) return {};

    try {
      var query = _supabase
          .from('user_profiles')
          .select('id, full_name, club, gender')
          .inFilter('club', _clubAliases(club));

      final normalizedGender = _normalizeGender(genderFilter);
      if (normalizedGender != null) {
        query = query.eq('gender', normalizedGender);
      }

      final rows = await query;
      final profiles = <String, Map<String, dynamic>>{};
      for (final raw in rows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final rowClub = canonicalClubName(row['club'] as String?);
        if (rowClub != club) continue;
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        row['club'] = rowClub;
        profiles[id] = row;
      }
      return profiles;
    } catch (e) {
      print('Error fetching club profiles for club records: $e');
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
      query = query.inFilter('club', _clubAliases(currentClub));
    }

    if (normalizedGender != null) {
      query = query.eq('gender', normalizedGender);
    }

    if (distance != 'Ultra') {
      query = query.order('time_seconds', ascending: true);
    }

    final response = await query;
    return (response as List)
        .map((json) => ClubRecord.fromJson(json))
        .where((record) => canonicalClubName(record.club) == currentClub)
        .toList();
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

  bool _isSupplementalClubRecord(ClubRecord record) {
    return record.isHistorical ||
        record.userId == null ||
        record.userId!.isEmpty;
  }

  String _displayDistanceForRaceRow(String requestedDistance) {
    return requestedDistance == '20M' ? '20M' : requestedDistance;
  }

  Future<List<ClubRecord>> _fetchSupplementalClubRecords(
    String distance, {
    int limit = 5,
    String? genderFilter,
  }) async {
    try {
      final records = await _fetchScopedRecords(
        distance,
        genderFilter: genderFilter,
      );
      return records.where(_isSupplementalClubRecord).toList();
    } catch (e) {
      if (_isMissingScopedClubRecordColumns(e)) {
        final records = await _fetchLegacyRecords(
          distance,
          limit: limit,
          genderFilter: genderFilter,
        );
        return records.where(_isSupplementalClubRecord).toList();
      }
      rethrow;
    }
  }

  Future<List<ClubRecord>> _fetchLiveRaceRecords(
    String distance, {
    int limit = 5,
    String? genderFilter,
  }) async {
    final profilesById = await _getClubProfiles(genderFilter);
    if (profilesById.isEmpty) return [];

    dynamic query = _supabase
        .from('race_results')
        .select('user_id, race_name, time_seconds, raceDate');

    if (distance == '20M') {
      query = query.inFilter('distance', ['20M', '20m', '20 mile', '20 Mile']);
    } else {
      query = query.eq('distance', distance);
    }

    query = query.inFilter('user_id', profilesById.keys.toList());

    final rows = await query;
    final records = <ClubRecord>[];

    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final userId = row['user_id'] as String?;
      final raceDate = row['raceDate'] as String?;
      final timeRaw = row['time_seconds'];
      if (userId == null || raceDate == null || timeRaw is! num) continue;

      final timeSeconds = timeRaw.toInt();
      if (timeSeconds <= 0) continue;

      final profile = profilesById[userId];
      if (profile == null) continue;

      records.add(
        ClubRecord(
          id: 'live-$userId-${_displayDistanceForRaceRow(distance)}-$timeSeconds-$raceDate',
          distance: _displayDistanceForRaceRow(distance),
          timeSeconds: timeSeconds,
          runnerName: (profile['full_name'] as String?) ?? 'Unknown',
          userId: userId,
          club: canonicalClubName(profile['club'] as String?),
          gender: _normalizeGender(profile['gender'] as String?),
          raceName: ((row['race_name'] as String?)?.trim().isNotEmpty == true)
              ? row['race_name'] as String
              : 'Untitled race',
          raceDate: DateTime.parse(raceDate),
          isHistorical: false,
        ),
      );
    }

    if (distance == 'Ultra') {
      records.sort((a, b) {
        final da = _parseUltraDistanceScore(a.raceName);
        final db = _parseUltraDistanceScore(b.raceName);
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return a.timeSeconds.compareTo(b.timeSeconds);
      });
    } else {
      records.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }

    return records.length > limit ? records.take(limit).toList() : records;
  }

  List<ClubRecord> _mergeRecordSources(
    String distance,
    List<ClubRecord> liveRecords,
    List<ClubRecord> supplementalRecords,
  ) {
    final merged = <ClubRecord>[];
    final seen = <String>{};

    String keyFor(ClubRecord record) {
      final dateOnly = record.raceDate.toIso8601String().split('T')[0];
      final runnerToken = (record.userId != null && record.userId!.isNotEmpty)
          ? record.userId!
          : record.runnerName.trim().toLowerCase();
      return '${record.distance}|$runnerToken|${record.timeSeconds}|${record.raceName.trim().toLowerCase()}|$dateOnly';
    }

    for (final record in [...liveRecords, ...supplementalRecords]) {
      final key = keyFor(record);
      if (seen.add(key)) {
        merged.add(record);
      }
    }

    if (distance == 'Ultra') {
      merged.sort((a, b) {
        final da = _parseUltraDistanceScore(a.raceName);
        final db = _parseUltraDistanceScore(b.raceName);
        final cmp = db.compareTo(da);
        if (cmp != 0) return cmp;
        return a.timeSeconds.compareTo(b.timeSeconds);
      });
    } else {
      merged.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }

    return merged;
  }

  /// Fetch top N records for a specific distance
  Future<List<ClubRecord>> getTopRecords(
    String distance, {
    int limit = 5,
    String? genderFilter,
  }) async {
    try {
      final liveRecords = await _fetchLiveRaceRecords(
        distance,
        limit: limit,
        genderFilter: genderFilter,
      );

      final supplementalRecords = await _fetchSupplementalClubRecords(
        distance,
        limit: limit,
        genderFilter: genderFilter,
      );

      final records = _mergeRecordSources(
        distance,
        liveRecords,
        supplementalRecords,
      );

      return records.length > limit ? records.take(limit).toList() : records;
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

    final unitPattern = RegExp(
      r'(\d+(?:\.\d+)?)\s*(k|km|kilometre|kilometer|mile|miles|mi)\b',
    );
    final unitMatch = unitPattern.firstMatch(text);
    if (unitMatch != null) {
      final value = double.tryParse(unitMatch.group(1) ?? '');
      if (value == null) return 0;
      final unit = unitMatch.group(2) ?? '';
      if (unit.startsWith('k')) {
        return value;
      } else {
        return value * 1.60934;
      }
    }

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
    final recordLists = await Future.wait(
      distances.map(
        (distance) => getTopRecords(
          distance,
          limit: limitPerDistance,
          genderFilter: genderFilter,
        ),
      ),
    );

    return {
      for (var index = 0; index < distances.length; index++)
        distances[index]: recordLists[index],
    };
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

  bool _isSameRaceDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesPerformance(
    ClubRecord record, {
    required String userId,
    required int timeSeconds,
    required String raceName,
    required DateTime raceDate,
  }) {
    final safeRaceName = raceName.trim().isEmpty
        ? 'Untitled race'
        : raceName.trim();
    return record.userId == userId &&
        record.timeSeconds == timeSeconds &&
        record.raceName.trim() == safeRaceName &&
        _isSameRaceDate(record.raceDate, raceDate);
  }

  Future<void> notifyIfPerformanceSetClubRecord({
    required String userId,
    required String distance,
    required int timeSeconds,
    required String raceName,
    required DateTime raceDate,
    ClubRecord? previousHolder,
  }) async {
    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('full_name, club, gender')
          .eq('id', userId)
          .maybeSingle();

      final runnerName =
          ((profile?['full_name'] as String?)?.trim().isNotEmpty == true)
          ? (profile!['full_name'] as String).trim()
          : 'Unknown';
      final clubName = (profile?['club'] as String?)?.trim();
      final genderFilter = _normalizeGender(profile?['gender'] as String?);

      if (clubName == null || clubName.isEmpty) return;

      final currentHolder = await getClubRecordHolder(
        distance,
        genderFilter: genderFilter,
      );
      if (currentHolder == null) return;

      if (!_matchesPerformance(
        currentHolder,
        userId: userId,
        timeSeconds: timeSeconds,
        raceName: raceName,
        raceDate: raceDate,
      )) {
        return;
      }

      if (previousHolder != null &&
          _matchesPerformance(
            previousHolder,
            userId: userId,
            timeSeconds: timeSeconds,
            raceName: raceName,
            raceDate: raceDate,
          )) {
        return;
      }

      if (previousHolder != null && previousHolder.userId == userId) {
        if (distance == 'Ultra') {
          final previousScore = _parseUltraDistanceScore(
            previousHolder.raceName,
          );
          final currentScore = _parseUltraDistanceScore(currentHolder.raceName);
          if (currentScore < previousScore) return;
          if (currentScore == previousScore &&
              currentHolder.timeSeconds >= previousHolder.timeSeconds) {
            return;
          }
        } else if (currentHolder.timeSeconds >= previousHolder.timeSeconds) {
          return;
        }
      }

      final distanceToken = distance.replaceAll(' ', '_');
      final genderToken =
          _normalizeGender(currentHolder.gender) ?? genderFilter;
      await NotificationService.notifyUsersInClub(
        clubName: clubName,
        title: 'New club record set',
        body:
            '$runnerName set a new $distance club record in ${currentHolder.formattedTime}.',
        route:
            'club_records/$distanceToken${genderToken != null ? '/$genderToken' : ''}',
      );
    } catch (e) {
      print('Error notifying for live club record achievement: $e');
    }
  }

  /// Add a new club record (admin only)
  Future<bool> addRecord(ClubRecord record) async {
    try {
      final currentClub = await _getCurrentUserClub();
      final payload = record.toJson();
      payload['club'] = canonicalClubName(record.club ?? currentClub);
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

      try {
        final runner = record.runnerName;
        final distance = record.distance;
        final time = record.formattedTime;
        final distanceToken = distance.replaceAll(' ', '_');
        final genderToken = _normalizeGender(payload['gender'] as String?);
        final clubName = currentClub;

        if (clubName != null && clubName.isNotEmpty) {
          await NotificationService.notifyUsersInClub(
            clubName: clubName,
            title: 'New club record set',
            body: '$runner set a new $distance club record in $time.',
            route:
                'club_records/$distanceToken${genderToken != null ? '/$genderToken' : ''}',
          );
        } else {
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
      payload['club'] = canonicalClubName(
        record.club ?? await _getCurrentUserClub(),
      );
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

  Future<void> reconcileCurrentUserRecordForDistance(String distance) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('full_name, club, gender')
          .eq('id', user.id)
          .maybeSingle();

      final runnerName =
          (profile != null ? profile['full_name'] as String? : null) ??
          'Unknown';
      final club = profile != null
          ? canonicalClubName(profile['club'] as String?)
          : null;
      final gender = profile != null
          ? _normalizeGender(profile['gender'] as String?)
          : null;

      dynamic raceResultsQuery = _supabase
          .from('race_results')
          .select('id, race_name, time_seconds, raceDate')
          .eq('user_id', user.id);

      dynamic clubRecordsQuery = _supabase
          .from('club_records')
          .select(
            'id, race_name, time_seconds, race_date, runner_name, club, gender',
          )
          .eq('user_id', user.id)
          .eq('is_historical', false);

      if (distance == '20M') {
        const aliases = ['20M', '20m', '20 mile', '20 Mile'];
        raceResultsQuery = raceResultsQuery.inFilter('distance', aliases);
        clubRecordsQuery = clubRecordsQuery.inFilter('distance', aliases);
      } else {
        raceResultsQuery = raceResultsQuery.eq('distance', distance);
        clubRecordsQuery = clubRecordsQuery.eq('distance', distance);
      }

      final raceResults = await raceResultsQuery;
      final existingRecords = await clubRecordsQuery;

      final expectedCounts = <String, int>{};
      Map<String, dynamic>? fastestResult;
      int? fastestTime;

      for (final row in raceResults as List) {
        final timeSeconds = row['time_seconds'] as int?;
        final raceDate = row['raceDate'] as String?;
        if (timeSeconds == null || timeSeconds <= 0 || raceDate == null) {
          continue;
        }

        final raceName =
            ((row['race_name'] as String?)?.trim().isNotEmpty == true)
            ? row['race_name'] as String
            : 'Untitled race';
        final dateOnly = DateTime.parse(
          raceDate,
        ).toIso8601String().split('T')[0];
        final key = _recordSyncKey(timeSeconds, raceName, dateOnly);
        expectedCounts[key] = (expectedCounts[key] ?? 0) + 1;

        if (fastestTime == null || timeSeconds < fastestTime) {
          fastestTime = timeSeconds;
          fastestResult = row as Map<String, dynamic>;
        }
      }

      var hasFastestRecord = false;
      for (final row in existingRecords as List) {
        final id = row['id'] as String?;
        final timeSeconds = row['time_seconds'] as int?;
        final raceDate = row['race_date'] as String?;
        if (id == null || timeSeconds == null || raceDate == null) continue;

        final raceName =
            ((row['race_name'] as String?)?.trim().isNotEmpty == true)
            ? row['race_name'] as String
            : 'Untitled race';
        final dateOnly = DateTime.parse(
          raceDate,
        ).toIso8601String().split('T')[0];
        final key = _recordSyncKey(timeSeconds, raceName, dateOnly);
        final remaining = expectedCounts[key] ?? 0;

        if (remaining <= 0) {
          await _supabase.from('club_records').delete().eq('id', id);
          continue;
        }

        expectedCounts[key] = remaining - 1;

        final updates = <String, dynamic>{};
        if (row['runner_name'] != runnerName) {
          updates['runner_name'] = runnerName;
        }
        if (row['club'] != club) {
          updates['club'] = club;
        }
        if (_normalizeGender(row['gender'] as String?) != gender) {
          updates['gender'] = gender;
        }
        if (updates.isNotEmpty) {
          await _supabase.from('club_records').update(updates).eq('id', id);
        }

        if (fastestTime != null && timeSeconds == fastestTime) {
          hasFastestRecord = true;
        }
      }

      if (!hasFastestRecord && fastestResult != null && fastestTime != null) {
        final raceName =
            ((fastestResult['race_name'] as String?)?.trim().isNotEmpty == true)
            ? fastestResult['race_name'] as String
            : 'Untitled race';
        await ensureRecordForResult(
          userId: user.id,
          distance: distance,
          timeSeconds: fastestTime,
          raceName: raceName,
          raceDate: DateTime.parse(fastestResult['raceDate'] as String),
        );
      }
    } catch (e) {
      print('Error reconciling current user club record for $distance: $e');
    }
  }

  Future<void> reconcileCurrentUserRecords() async {
    const distances = [
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
      await reconcileCurrentUserRecordForDistance(distance);
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
          final canonicalClub = canonicalClubName(club);
          final gender = _normalizeGender(profile['gender'] as String?);
          final timeSeconds = result['time_seconds'] as int?;
          if (timeSeconds == null || timeSeconds <= 0) continue;

          // Check if this record already exists
          final existing = await _supabase
              .from('club_records')
              .select('id, runner_name, race_name, race_date, club, gender')
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
              club: canonicalClub,
              gender: gender,
              raceName: result['race_name'] as String? ?? 'Unknown Race',
              raceDate: DateTime.parse(result['raceDate'] as String),
              isHistorical: false,
            );

            await addRecord(record);
          } else {
            // Ensure existing record stays in sync with the source result and
            // current profile metadata.
            final existingId = existing['id'] as String?;
            final resultRaceName =
                (result['race_name'] as String?)?.trim().isNotEmpty == true
                ? result['race_name'] as String
                : 'Unknown Race';
            final resultRaceDate = DateTime.parse(
              result['raceDate'] as String,
            ).toIso8601String().split('T')[0];

            if (existingId != null) {
              final updates = <String, dynamic>{};
              if (existing['runner_name'] != runnerName) {
                updates['runner_name'] = runnerName;
              }
              if (existing['race_name'] != resultRaceName) {
                updates['race_name'] = resultRaceName;
              }
              if (existing['race_date'] != resultRaceDate) {
                updates['race_date'] = resultRaceDate;
              }
              if (existing['club'] != club) {
                updates['club'] = canonicalClub;
              }
              if (_normalizeGender(existing['gender'] as String?) != gender) {
                updates['gender'] = gender;
              }

              if (updates.isNotEmpty) {
                await _supabase
                    .from('club_records')
                    .update(updates)
                    .eq('id', existingId);
              }
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
      final profile = await _supabase
          .from('user_profiles')
          .select('full_name, club, gender')
          .eq('id', userId)
          .maybeSingle();

      final runnerName =
          (profile != null ? profile['full_name'] as String? : null) ??
          'Unknown';
      final club = profile != null
          ? canonicalClubName(profile['club'] as String?)
          : null;
      final gender = profile != null
          ? _normalizeGender(profile['gender'] as String?)
          : null;

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
