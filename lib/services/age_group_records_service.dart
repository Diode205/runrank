import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/standards_data.dart';

/// A top performance within a specific age-group band (e.g. "40-44"),
/// mirroring [ClubRecord] but scoped per age category instead of overall.
class AgeGroupRecord {
  final String id;
  final String distance;
  final String ageGroup; // plain band label, e.g. "18-29" or "Under35"
  final int? ageAtRace;
  final int timeSeconds;
  final String runnerName;
  final String? userId;
  final String? club;
  final String? gender;
  final String raceName;
  final DateTime raceDate;
  final bool isHistorical;

  AgeGroupRecord({
    required this.id,
    required this.distance,
    required this.ageGroup,
    this.ageAtRace,
    required this.timeSeconds,
    required this.runnerName,
    this.userId,
    this.club,
    this.gender,
    required this.raceName,
    required this.raceDate,
    this.isHistorical = false,
  });

  factory AgeGroupRecord.fromJson(Map<String, dynamic> json) {
    return AgeGroupRecord(
      id: json['id'] as String,
      distance: json['distance'] as String,
      ageGroup: json['age_group'] as String,
      ageAtRace: json['age_at_race'] as int?,
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
      'age_group': ageGroup,
      'age_at_race': ageAtRace,
      'time_seconds': timeSeconds,
      'runner_name': runnerName,
      'user_id': userId,
      if (club != null) 'club': club,
      'gender': gender,
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

class AgeGroupRecordsService {
  final _supabase = Supabase.instance.client;

  String? _cachedClubName;
  bool _clubLoaded = false;
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

  /// Derive age at [date] from a stored date-of-birth string (yyyy-mm-dd).
  int? _ageOnDate({required String? dobString, required DateTime date}) {
    if (dobString == null || dobString.isEmpty) return null;
    final dob = DateTime.tryParse(dobString);
    if (dob == null) return null;

    var years = date.year - dob.year;
    final hasHadBirthday =
        date.month > dob.month ||
        (date.month == dob.month && date.day >= dob.day);
    if (!hasHadBirthday) years--;

    if (years <= 0 || years > 120) return null;
    return years;
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
      print('Error fetching current user club for age-group records: $e');
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
      print('Error fetching current user gender for age-group records: $e');
      _userGenderLoaded = true;
      _cachedUserGender = null;
      return null;
    }
  }

  Future<String?> getDefaultGenderFilter() => _getCurrentUserGender();

  Future<String?> getClubName() => _getCurrentUserClub();

  /// The signed-in runner's current, gender-neutral age-group band.
  ///
  /// This is used to focus the records page on the category most relevant to
  /// the runner. Race records themselves still use the runner's age on race
  /// day when deciding which group they belong to.
  Future<String?> getCurrentUserAgeGroup() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _supabase
          .from('user_profiles')
          .select('date_of_birth')
          .eq('id', user.id)
          .maybeSingle();
      final age = _ageOnDate(
        dobString: row?['date_of_birth'] as String?,
        date: DateTime.now(),
      );
      if (age == null) return null;
      return ageGroupLabelForClub(
        age: age,
        clubName: await _getCurrentUserClub(),
      );
    } catch (e) {
      print('Error fetching current user age group: $e');
      return null;
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
          .select('id, full_name, club, gender, date_of_birth')
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
      print('Error fetching club profiles for age-group records: $e');
      return {};
    }
  }

  Future<List<AgeGroupRecord>> _fetchLiveAgeGroupRecords(
    String distance, {
    String? genderFilter,
  }) async {
    try {
      return await _fetchLiveAgeGroupRecordsUnsafe(
        distance,
        genderFilter: genderFilter,
      );
    } catch (e) {
      print('Error fetching live age-group records for $distance: $e');
      return [];
    }
  }

  Future<List<AgeGroupRecord>> _fetchLiveAgeGroupRecordsUnsafe(
    String distance, {
    String? genderFilter,
  }) async {
    final profilesById = await _getClubProfiles(genderFilter);
    if (profilesById.isEmpty) return [];
    final club = await _getCurrentUserClub();

    dynamic query = _supabase
        .from('race_results')
        .select('user_id, race_name, time_seconds, raceDate, age');

    if (distance == '20M') {
      query = query.inFilter('distance', ['20M', '20m', '20 mile', '20 Mile']);
    } else {
      query = query.eq('distance', distance);
    }

    query = query.inFilter('user_id', profilesById.keys.toList());

    final rows = await query;
    final records = <AgeGroupRecord>[];

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

      // Prefer the age snapshot stored on the race result; fall back to
      // deriving it from the runner's date of birth so older/incomplete
      // rows (e.g. age missing or 0) still surface in age-group records.
      final ageRaw = row['age'];
      var age = (ageRaw is num && ageRaw > 0) ? ageRaw.toInt() : null;
      age ??= _ageOnDate(
        dobString: profile['date_of_birth'] as String?,
        date: DateTime.parse(raceDate),
      );
      if (age == null || age <= 0) continue;

      final ageGroup = ageGroupLabelForClub(age: age, clubName: club);

      records.add(
        AgeGroupRecord(
          id: 'live-$userId-${distance == '20M' ? '20M' : distance}-$timeSeconds-$raceDate',
          distance: distance == '20M' ? '20M' : distance,
          ageGroup: ageGroup,
          ageAtRace: age,
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

    return records;
  }

  Future<List<AgeGroupRecord>> _fetchSupplementalAgeGroupRecords(
    String distance, {
    String? genderFilter,
  }) async {
    try {
      final currentClub = await _getCurrentUserClub();
      final normalizedGender = _normalizeGender(genderFilter);

      dynamic query = _supabase.from('age_group_records').select();

      if (distance == '20M') {
        query = query.inFilter('distance', [
          '20M',
          '20m',
          '20 mile',
          '20 Mile',
        ]);
      } else {
        query = query.eq('distance', distance);
      }

      if (currentClub != null && currentClub.isNotEmpty) {
        query = query.inFilter('club', _clubAliases(currentClub));
      }

      if (normalizedGender != null) {
        query = query.eq('gender', normalizedGender);
      }

      final response = await query;
      return (response as List)
          .map((json) => AgeGroupRecord.fromJson(json))
          .where((record) => canonicalClubName(record.club) == currentClub)
          .toList();
    } catch (e) {
      // e.g. the age_group_records table/migration isn't deployed yet -
      // don't let this blank out live race-result-derived records below.
      print('Error fetching supplemental age-group records: $e');
      return [];
    }
  }

  /// Fetch top-3 performances per age-group band for a single distance.
  /// Returned map is ordered per the club's age-group band order.
  Future<Map<String, List<AgeGroupRecord>>> getTopRecordsByAgeGroup(
    String distance, {
    int limitPerGroup = 3,
    String? genderFilter,
  }) async {
    try {
      final club = await _getCurrentUserClub();
      final results = await Future.wait([
        _fetchLiveAgeGroupRecords(distance, genderFilter: genderFilter),
        _fetchSupplementalAgeGroupRecords(distance, genderFilter: genderFilter),
      ]);
      final liveRecords = results[0];
      final supplementalRecords = results[1];

      final seen = <String>{};
      final merged = <AgeGroupRecord>[];
      String keyFor(AgeGroupRecord record) {
        final dateOnly = record.raceDate.toIso8601String().split('T')[0];
        final runnerToken = (record.userId != null && record.userId!.isNotEmpty)
            ? record.userId!
            : record.runnerName.trim().toLowerCase();
        return '${record.distance}|${record.ageGroup}|$runnerToken|${record.timeSeconds}|${record.raceName.trim().toLowerCase()}|$dateOnly';
      }

      for (final record in [...liveRecords, ...supplementalRecords]) {
        final key = keyFor(record);
        if (seen.add(key)) merged.add(record);
      }

      final byGroup = <String, List<AgeGroupRecord>>{};
      for (final record in merged) {
        byGroup.putIfAbsent(record.ageGroup, () => []).add(record);
      }

      final ordered = <String, List<AgeGroupRecord>>{};
      for (final band in ageGroupOrderForClub(club)) {
        final groupRecords = List<AgeGroupRecord>.from(
          byGroup[band] ?? const [],
        );
        groupRecords.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
        // A leaderboard place belongs to a runner, not a performance. Since
        // the list is best-first, keep only each runner's fastest submitted
        // or historical result before applying the top-three limit.
        final representedRunners = <String>{};
        ordered[band] = groupRecords
            .where((record) => representedRunners.add(_runnerKey(record)))
            .take(limitPerGroup)
            .toList();
      }

      return ordered;
    } catch (e) {
      print('Error fetching age-group records for $distance: $e');
      return {};
    }
  }

  String _runnerKey(AgeGroupRecord record) {
    final normalizedName = record.runnerName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    // Admin-entered historical records may not have a user ID; using a
    // normalized name also combines them with that runner's submitted times.
    if (normalizedName.isNotEmpty && normalizedName != 'unknown') {
      return 'name:$normalizedName';
    }
    final userId = record.userId?.trim();
    return userId == null || userId.isEmpty
        ? 'record:${record.id}'
        : 'id:$userId';
  }

  /// Get the fastest record for a distance+age-group (band record holder).
  Future<AgeGroupRecord?> getAgeGroupRecordHolder(
    String distance,
    String ageGroup, {
    String? genderFilter,
  }) async {
    final byGroup = await getTopRecordsByAgeGroup(
      distance,
      limitPerGroup: 1,
      genderFilter: genderFilter,
    );
    final list = byGroup[ageGroup];
    return (list != null && list.isNotEmpty) ? list.first : null;
  }

  bool _isSameRaceDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesPerformance(
    AgeGroupRecord record, {
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

  /// Notify the club if a newly-submitted performance is now the top time
  /// within its age-group band (a runner can hold records in multiple bands
  /// across their lifetime, but only one at a time per band).
  Future<void> notifyIfPerformanceSetAgeGroupRecord({
    required String userId,
    required String distance,
    required int timeSeconds,
    required String raceName,
    required DateTime raceDate,
    required int age,
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

      final ageGroup = ageGroupLabelForClub(age: age, clubName: clubName);
      final currentHolder = await getAgeGroupRecordHolder(
        distance,
        ageGroup,
        genderFilter: genderFilter,
      );

      if (currentHolder == null ||
          !_matchesPerformance(
            currentHolder,
            userId: userId,
            timeSeconds: timeSeconds,
            raceName: raceName,
            raceDate: raceDate,
          )) {
        return;
      }

      final distanceToken = distance.replaceAll(' ', '_');
      final genderToken =
          _normalizeGender(currentHolder.gender) ?? genderFilter;
      final displayBand = displayAgeGroupLabel(ageGroup);
      await NotificationService.notifyUsersInClub(
        clubName: clubName,
        title: 'New age-group record set',
        body:
            '$runnerName set a new $distance age-group ($displayBand) record in ${currentHolder.formattedTime}.',
        route:
            'age_group_records/$distanceToken/$ageGroup${genderToken != null ? '/$genderToken' : ''}',
      );
    } catch (e) {
      print('Error notifying for age-group record achievement: $e');
    }
  }

  /// Add a new supplemental/historical age-group record (admin only).
  Future<bool> addRecord(AgeGroupRecord record) async {
    try {
      final currentClub = await _getCurrentUserClub();
      final payload = record.toJson();
      payload['club'] = canonicalClubName(record.club ?? currentClub);
      payload['gender'] = _normalizeGender(record.gender);

      await _supabase.from('age_group_records').insert(payload);

      try {
        final clubName = currentClub;
        if (clubName != null && clubName.isNotEmpty) {
          final distanceToken = record.distance.replaceAll(' ', '_');
          final displayBand = displayAgeGroupLabel(record.ageGroup);
          await NotificationService.notifyUsersInClub(
            clubName: clubName,
            title: 'New age-group record set',
            body:
                '${record.runnerName} set a new ${record.distance} age-group '
                '($displayBand) record in ${record.formattedTime}.',
            route: 'age_group_records/$distanceToken/${record.ageGroup}',
          );
        }
      } catch (e) {
        print('Error sending age-group record notification: $e');
      }
      return true;
    } catch (e) {
      print('Error adding age-group record: $e');
      return false;
    }
  }

  Future<bool> updateRecord(String id, AgeGroupRecord record) async {
    try {
      final payload = record.toJson();
      payload['club'] = canonicalClubName(
        record.club ?? await _getCurrentUserClub(),
      );
      payload['gender'] = _normalizeGender(record.gender);

      await _supabase.from('age_group_records').update(payload).eq('id', id);
      return true;
    } catch (e) {
      print('Error updating age-group record: $e');
      return false;
    }
  }

  Future<bool> deleteRecord(String id) async {
    try {
      await _supabase.from('age_group_records').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting age-group record: $e');
      return false;
    }
  }
}
