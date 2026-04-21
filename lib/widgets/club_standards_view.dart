import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:runrank/calculator_logic.dart';
import 'package:runrank/standards_data.dart';
import 'package:runrank/widgets/result_card.dart';
import 'package:runrank/services/auth_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/services/club_records_service.dart';
import 'package:runrank/history_screen.dart';

class ClubStandardsView extends StatefulWidget {
  const ClubStandardsView({super.key});

  @override
  State<ClubStandardsView> createState() => _ClubStandardsViewState();
}

class _ClubStandardsViewState extends State<ClubStandardsView>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------
  // Animation for subtitle fade + slide + image carousel
  // ---------------------------------------------------------
  late AnimationController _subTitleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  // Image carousel
  late Timer _imageTimer;
  int _currentImageIndex = 0;
  List<String> _carouselImages = [
    // Neutral default while club is loading
    'assets/images/rank_logo.png',
  ];
  late AnimationController _imageController;
  late Animation<double> _imageFadeAnimation;

  // ---------------------------------------------------------
  // Current Club Standard award status (from race history)
  // ---------------------------------------------------------
  List<String> get _awardLevels => awardLevelsForClub(_clubName);

  List<String> get _awardDistances => awardDistancesForClub(_clubName);

  int get _requiredAwardDistanceCount =>
      requiredAwardDistanceCountForClub(_clubName);

  bool _isStandardDistance(String distance) {
    return clubSupportsStandardDistance(_clubName, distance);
  }

  // Input controllers
  final TextEditingController _raceNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _ultraDistanceController =
      TextEditingController();
  final TextEditingController _iceSearchController = TextEditingController();

  DateTime? _selectedRaceDate;
  String _selectedDistance = '5K';
  String _selectedGender = 'M';
  String? _resultMessage;
  String? _clubName;
  DateTime? _dateOfBirth;
  DateTime? _memberSince;

  // Whether we've finished loading the user's profile/club info
  bool _profileLoaded = false;

  // Award / badge state
  bool _loadingAwardStatus = false;
  String? _awardLevel;
  int _awardCount = 0;
  String? _awardError;
  bool _showBadgeOnRecordsButton = false;

  // Admin flag
  bool _isAdmin = false;

  // Top 10 snapview state
  final List<String> _snapDistances = const [
    '5K',
    '5M',
    '10K',
    '10M',
    'Half M',
    'Marathon',
  ];
  Map<String, int?> _top10Positions = {};
  bool _showTop10Snap = false;
  bool _loadingTop10Snap = false;
  int _top10SnapLoadGeneration = 0;
  bool _showTop10SnapWhenLoaded = false;
  bool _searchingIceMembers = false;
  List<Map<String, dynamic>> _iceSearchResults = [];

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });

    _subTitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _subTitleController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _subTitleController, curve: Curves.easeOut),
        );

    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _imageFadeAnimation = CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeInOut,
    );

    _subTitleController.forward();
    _imageController.forward();
    _startImageTimer();

    _initAdminAndStatus();
    _prefillAgeFromProfile();
  }

  @override
  void dispose() {
    _imageTimer.cancel();
    _scrollController.dispose();
    _subTitleController.dispose();
    _imageController.dispose();
    _raceNameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _ageController.dispose();
    _ultraDistanceController.dispose();
    _iceSearchController.dispose();
    super.dispose();
  }

  void _startImageTimer() {
    _imageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _carouselImages.length;
      });
      _imageController.forward(from: 0);
    });
  }

  Future<void> _prefillAgeFromProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final row = await client
          .from('user_profiles')
          .select('date_of_birth, gender, club, member_since')
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return;
      final rawGender = (row['gender'] as String?)?.trim().toUpperCase();
      final club = (row['club'] as String?)?.trim();

      int? age;
      final dobStr = row['date_of_birth'] as String?;
      final memberSinceStr = row['member_since'] as String?;
      if (dobStr != null && dobStr.isNotEmpty) {
        final dob = DateTime.tryParse(dobStr);
        if (dob != null) {
          _dateOfBirth = dob;
          final now = DateTime.now();
          var calculatedAge = now.year - dob.year;
          final hasHadBirthdayThisYear =
              (now.month > dob.month) ||
              (now.month == dob.month && now.day >= dob.day);
          if (!hasHadBirthdayThisYear) {
            calculatedAge--;
          }

          if (calculatedAge > 0 && calculatedAge <= 120) {
            age = calculatedAge;
          }
        }
      }
      if (memberSinceStr != null && memberSinceStr.isNotEmpty) {
        _memberSince = DateTime.tryParse(memberSinceStr);
      }

      if (!mounted) return;
      setState(() {
        if (age != null) {
          _ageController.text = age.toString();
        }

        if (rawGender != null && (rawGender == 'M' || rawGender == 'F')) {
          _selectedGender = rawGender;
        }

        if (club != null && club.isNotEmpty) {
          _clubName = club;

          final lowerClub = club.toLowerCase();
          if (lowerClub.contains('norwich road runners')) {
            _carouselImages = [
              'assets/images/nrr1.png',
              'assets/images/nrr2.png',
              'assets/images/nrr13.png',
              'assets/images/nrr14.png',
              'assets/images/nrr15.png',
              'assets/images/nrr16.png',
              'assets/images/nrr17.png',
              'assets/images/nrr18.png',
              'assets/images/nrr19.png',
              'assets/images/nrr20.png',
              'assets/images/nrr21.png',
              'assets/images/nrr22.png',
              'assets/images/nrr23.png',
              'assets/images/nrr24.png',
              'assets/images/nrr25.png',
            ];
          } else if (lowerClub.contains('north norfolk beach runners')) {
            _carouselImages = [
              'assets/images/pic1.png',
              'assets/images/pic2.png',
              'assets/images/pic3.png',
              'assets/images/pic4.png',
              'assets/images/pic5.png',
              'assets/images/pic6.png',
              'assets/images/pic7.png',
              'assets/images/pic8.png',
              'assets/images/pic9.png',
              'assets/images/pic10.png',
              'assets/images/pic11.png',
            ];
          } else {
            // Other clubs get a neutral carousel until bespoke images exist
            _carouselImages = ['assets/images/rank_logo.png'];
          }
        }
      });

      // Club-specific award rules depend on the loaded club, so refresh
      // the overall status once profile data is available.
      await _loadCurrentAwardStatus();
    } catch (e) {
      // ignore: avoid_print
      print('Error pre-filling age from profile: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _profileLoaded = true;
      });
    }
  }

  int? _ageOnDate(DateTime date) {
    final dob = _dateOfBirth;
    if (dob == null) return null;

    var years = date.year - dob.year;
    final hasHadBirthday =
        date.month > dob.month ||
        (date.month == dob.month && date.day >= dob.day);
    if (!hasHadBirthday) {
      years--;
    }

    if (years <= 0 || years > 120) return null;
    return years;
  }

  int _resolvedAgeForRaceDate(DateTime? raceDate, {int fallback = 0}) {
    return _ageOnDate(raceDate ?? DateTime.now()) ?? fallback;
  }

  void _syncDisplayedAgeWithSelectedRaceDate() {
    final derivedAge = _ageOnDate(_selectedRaceDate ?? DateTime.now());
    if (derivedAge != null) {
      _ageController.text = derivedAge.toString();
    }
  }

  bool _isRaceEligibleForAward(DateTime? raceDate) {
    final membershipDate = _memberSince;
    final eventDate = raceDate;
    if (membershipDate == null || eventDate == null) {
      return true;
    }

    final memberDay = DateTime(
      membershipDate.year,
      membershipDate.month,
      membershipDate.day,
    );
    final raceDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    return !raceDay.isBefore(memberDay);
  }

  String _clubStandardsDescription() {
    final club = (_clubName ?? '').toLowerCase();

    if (club.contains('norwich road runners')) {
      return 'NRR Club Standards require members to achieve qualifying times '
          'in five of seven races over a calendar year to earn an award.\n\n'
          'Only races run on or after your club membership date qualify for the award.\n\n'
          'Qualifying races are UKA licensed events. Parkruns and training runs do not count.\n\n'
          'A runner may achieve different standards in all categories during the year but only the lowest category will be awarded.\n\n'
          'Awards will be presented at the Annual Awards evening.';
    }

    if (club.contains('north norfolk beach runners')) {
      return 'NNBR Club Standards require members to achieve qualifying times '
          'in four of six distances over a calendar year to earn an award.\n\n'
          'Only races run on or after your club membership date qualify for the award.\n\n'
          'Qualifying races are UKA licensed and Club Handicap events. Parkruns and training runs do not count.\n\n'
          'A runner may achieve different standards in all categories during the year but only the lowest category will be awarded.\n\n'
          'Awards will be presented at the Annual Awards evening.';
    }

    // Generic wording while club is loading / for unknown clubs
    return 'Club Standards require members to achieve qualifying performances '
        'over key distances within a calendar year to earn an award.\n\n'
        'Only races run on or after your club membership date qualify for the award.\n\n'
        'Qualifying races are typically UKA licensed events and official club handicaps. Training runs do not count.\n\n'
        'A runner may achieve different standards in all categories during the year but only the lowest category will be awarded.\n\n'
        'Awards are usually presented at the Annual Awards evening.';
  }

  String _clubStandardsUrl() {
    final club = (_clubName ?? '').toLowerCase();

    if (club.contains('norwich road runners')) {
      return 'https://norwichroadrunners.co.uk/club-standards-1';
    }

    if (club.contains('north norfolk beach runners')) {
      return 'https://www.northnorfolkbeachrunners.com/club-standards';
    }

    // Neutral default link if club is unknown/loading
    return 'https://norwichroadrunners.co.uk/club-standards-1';
  }

  String _clubStandardsLinkLabel() {
    final club = (_clubName ?? '').toLowerCase();

    if (club.contains('norwich road runners')) {
      return 'View full club standards on NRR website';
    }

    if (club.contains('north norfolk beach runners')) {
      return 'View full club standards on NNBR website';
    }

    return 'View full club standards on club website';
  }

  Future<void> _initAdminAndStatus() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) {
      setState(() {});
    }
    await _loadCurrentAwardStatus();
  }

  Future<void> _loadCurrentAwardStatus() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _awardLevel = null;
        _awardCount = 0;
        _awardError =
            'Log in to see your Club Standard Award based on your race history.';
        _showBadgeOnRecordsButton = false;
      });
      return;
    }

    setState(() {
      _loadingAwardStatus = true;
      _awardError = null;
    });

    try {
      final rows = await client
          .from('race_results')
          .select('distance, level, time_seconds, gender, age, raceDate')
          .eq('user_id', user.id);

      if (rows.isEmpty) {
        setState(() {
          _awardLevel = null;
          _awardCount = 0;
          _awardError =
              'Once you have race records across our ${_awardDistances.length} key club distances, you\'ll see your overall Club Standard Award here.';
          _showBadgeOnRecordsButton = false;
        });
        return;
      }

      final Map<String, String> bestByDistance = {
        for (final d in _awardDistances) d: '',
      };

      for (final row in rows) {
        final distance = (row['distance'] as String?) ?? '';
        final raceDate = DateTime.tryParse(row['raceDate'] as String? ?? '');
        final level = _effectiveLevelFromRaceRow(row);

        if (!_awardDistances.contains(distance)) continue;
        if (!_isRaceEligibleForAward(raceDate)) continue;
        if (!_awardLevels.contains(level)) continue;

        final current = bestByDistance[distance] ?? '';
        if (current.isEmpty || _levelIndex(level) > _levelIndex(current)) {
          bestByDistance[distance] = level;
        }
      }

      String? achievedLevel;
      int contributingDistances = 0;

      for (final level in _awardLevels.reversed) {
        final requiredIdx = _levelIndex(level);
        int count = 0;
        for (final d in _awardDistances) {
          final lv = bestByDistance[d];
          if (lv == null || lv.isEmpty) continue;
          if (_levelIndex(lv) >= requiredIdx) {
            count++;
          }
        }
        if (count >= _requiredAwardDistanceCount) {
          achievedLevel = level;
          contributingDistances = count;
          break;
        }
      }

      setState(() {
        _awardLevel = achievedLevel;
        _awardCount = contributingDistances;
        if (achievedLevel == null) {
          _awardError =
              'You have some race records, but not yet across enough distances for an overall Club Standard Award.';
          _showBadgeOnRecordsButton = false;
        } else {
          _awardError = null;
          _showBadgeOnRecordsButton = true;
        }
      });
    } catch (_) {
      setState(() {
        _awardLevel = null;
        _awardCount = 0;
        _awardError = 'Could not load Club Standard status.';
        _showBadgeOnRecordsButton = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAwardStatus = false;
        });
      }
    }
  }

  int _levelIndex(String level) {
    final idx = _awardLevels.indexOf(level);
    return idx < 0 ? -1 : idx;
  }

  String _effectiveLevelFromRaceRow(Map<String, dynamic> row) {
    final storedLevel = (row['level'] as String?) ?? '';
    final distance = (row['distance'] as String?) ?? '';
    final timeSecondsRaw = row['time_seconds'];
    final finishSeconds = timeSecondsRaw is num ? timeSecondsRaw.toInt() : 0;
    final gender = ((row['gender'] as String?) ?? '').toUpperCase();
    final storedAge = row['age'] is int ? row['age'] as int : 0;
    final raceDate = DateTime.tryParse(row['raceDate'] as String? ?? '');
    final age = _resolvedAgeForRaceDate(raceDate, fallback: storedAge);

    if (!clubSupportsStandardDistance(_clubName, distance)) {
      return storedLevel;
    }

    if (finishSeconds <= 0 || (gender != 'M' && gender != 'F') || age <= 0) {
      return storedLevel;
    }

    final eval = RunCalculator.evaluate(
      gender: gender,
      age: age,
      distance: distance,
      finishSeconds: finishSeconds,
      clubName: _clubName,
    );
    return eval['level'] as String;
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'Copper':
        return const Color(0xFFB87333);
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platinum':
        return const Color(0xFFB0E0E6);
      case 'Emerald':
        return const Color(0xFF2ECC71);
      case 'Diamond':
        return const Color(0xFF00E5FF);
      default:
        return Colors.white;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickRaceDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial =
        (_selectedRaceDate != null && !_selectedRaceDate!.isAfter(today))
        ? _selectedRaceDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      selectableDayPredicate: (date) {
        // Allow only today and past dates (grey out future)
        final d = DateTime(date.year, date.month, date.day);
        return !d.isAfter(today);
      },
    );
    if (picked != null) {
      setState(() {
        _selectedRaceDate = picked;
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')} '
            '${_monthShort(picked.month)} ${picked.year}';
        _syncDisplayedAgeWithSelectedRaceDate();
      });
    }
  }

  String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) {
      return '${hrs.toString().padLeft(2, '0')}:'
          '${mins.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _submitToSupabase({
    required String race,
    required int age,
    required String gender,
    required String distance,
    required int seconds,
    required String level,
    required double ageGrade,
  }) async {
    final raceDate = _selectedRaceDate ?? DateTime.now();
    final success = await AuthService.submitRaceResult(
      raceName: race,
      gender: gender,
      age: age,
      distance: distance,
      finishSeconds: seconds,
      level: level,
      ageGrade: ageGrade,
      raceDate: raceDate,
    );
    if (!success) return;

    _invalidateTop10SnapCache();
  }

  Future<void> _toggleTop10Snap() async {
    if (_showTop10Snap) {
      _hideTop10Snap();
      return;
    }

    if (_loadingTop10Snap) {
      _showTop10SnapWhenLoaded = !_showTop10SnapWhenLoaded;
      return;
    }

    // If we already have data cached, just show it instantly.
    if (_top10Positions.isNotEmpty && !_loadingTop10Snap) {
      setState(() {
        _showTop10Snap = true;
        _showTop10SnapWhenLoaded = true;
      });
      return;
    }

    // Otherwise, load in the background and only show once ready.
    final loadGeneration = ++_top10SnapLoadGeneration;
    setState(() {
      _loadingTop10Snap = true;
      _showTop10SnapWhenLoaded = true;
    });

    final didLoad = await _loadTop10SnapPositions(loadGeneration);

    if (!mounted || !didLoad || !_showTop10SnapWhenLoaded) return;
    setState(() {
      _showTop10Snap = true;
    });
  }

  void _hideTop10Snap() {
    _showTop10SnapWhenLoaded = false;
    if (!_showTop10Snap) return;
    setState(() {
      _showTop10Snap = false;
    });
  }

  void _invalidateTop10SnapCache() {
    _top10SnapLoadGeneration++;
    _showTop10SnapWhenLoaded = false;

    if (!mounted) {
      _top10Positions = {};
      _showTop10Snap = false;
      _loadingTop10Snap = false;
      return;
    }

    setState(() {
      _top10Positions = {};
      _showTop10Snap = false;
      _loadingTop10Snap = false;
    });
  }

  Future<bool> _loadTop10SnapPositions(int loadGeneration) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      if (!mounted || loadGeneration != _top10SnapLoadGeneration) {
        return false;
      }
      setState(() {
        _top10Positions = {};
        _loadingTop10Snap = false;
      });
      return false;
    }

    try {
      final recordsService = ClubRecordsService();
      final gender = await recordsService.getDefaultGenderFilter();

      final all = await recordsService.getAllTopRecords(
        limitPerDistance: 10,
        genderFilter: gender,
      );

      final Map<String, int?> positions = {};

      for (final distance in _snapDistances) {
        final list = all[distance] ?? const [];
        int? position;
        for (var i = 0; i < list.length; i++) {
          final record = list[i];
          if (record.userId == user.id) {
            position = i + 1;
            break;
          }
        }
        positions[distance] = position;
      }

      if (!mounted || loadGeneration != _top10SnapLoadGeneration) {
        return false;
      }
      setState(() {
        _top10Positions = positions;
        _loadingTop10Snap = false;
      });
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error loading Top 10 snapview: $e');
      if (!mounted || loadGeneration != _top10SnapLoadGeneration) {
        return false;
      }
      setState(() {
        _top10Positions = {};
        _loadingTop10Snap = false;
      });
      return false;
    }
  }

  // ---------------------------------------------------------
  // Calculate
  // ---------------------------------------------------------
  Future<void> _onCalculate() async {
    final timeText = _timeController.text.trim();
    final seconds = RunCalculator.parseTimeToSeconds(timeText);

    if (seconds == null) {
      setState(() {
        _resultMessage =
            'Please enter time as hh:mm:ss, mm:ss or decimal minutes.';
      });
      return;
    }

    final race = _raceNameController.text.trim();
    final enteredAge = int.tryParse(_ageController.text.trim()) ?? 0;
    final age = _resolvedAgeForRaceDate(
      _selectedRaceDate,
      fallback: enteredAge,
    );
    final gender = _selectedGender;
    final distance = _selectedDistance;
    // Special handling for non-standard distances (20M, Ultra)
    if (!_isStandardDistance(distance)) {
      // Build a race label that can include the Ultra distance detail
      String raceLabel = race;
      if (distance == 'Ultra') {
        final extra = _ultraDistanceController.text.trim();
        if (extra.isNotEmpty) {
          raceLabel = raceLabel.isEmpty
              ? 'Ultra $extra'
              : '$raceLabel — $extra';
        }
      }

      setState(() {
        _resultMessage =
            '🏁 ${raceLabel.isEmpty ? '' : '$raceLabel — '}This distance is recorded for club history and records only.';
      });

      _hideTop10Snap();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Special Distance',
            style: TextStyle(color: Colors.white),
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 66, 66, 66),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color.fromARGB(60, 23, 7, 173),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Club Standard and Age Grade are not being calculated for this distance.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'You can still submit this performance so it appears in your history and club records.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Exit',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitToSupabase(
                  race: raceLabel,
                  age: age,
                  gender: gender,
                  distance: distance,
                  seconds: seconds,
                  level: 'Not calculated',
                  ageGrade: 0.0,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      return;
    }

    // Normal club-standard distances: compute level + age grade
    final raceDate = _selectedRaceDate ?? DateTime.now();
    final qualifiesForAward = _isRaceEligibleForAward(raceDate);
    final eval = RunCalculator.evaluate(
      gender: gender,
      age: age,
      distance: distance,
      finishSeconds: seconds,
      clubName: _clubName,
    );

    final level = eval['level'] as String;
    final ageGrade = eval['ageGrade'] as double;
    final ageGradeMessage = eval['ageGradeMessage'] as String;
    final clubLower = (_clubName ?? '').toLowerCase();
    final isNrrClub = clubLower.contains('norwich road runners');
    final resultCardBackground = isNrrClub
        ? const Color(0xFFD32F2F)
        : const Color(0xFF0057B7);
    final resultCardAccent = isNrrClub
        ? const Color(0xFFFFD54F)
        : const Color(0xFFF5C542);
    final submitButtonBackground = resultCardAccent;
    final submitButtonForeground =
        submitButtonBackground.computeLuminance() > 0.6
        ? Colors.black
        : Colors.white;

    setState(() {
      _resultMessage =
          '🏁 ${race.isEmpty ? '' : '$race — '}You achieved $level (${ageGrade.toStringAsFixed(1)}%).';
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('WELL DONE!', style: TextStyle(color: Colors.white)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 66, 66, 66),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color.fromARGB(60, 23, 7, 173),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ResultCard(
                standard: level,
                ageGrade: ageGrade,
                ageGradeMessage: ageGradeMessage,
                backgroundColor: resultCardBackground,
                accentColor: resultCardAccent,
                guidance:
                    (!qualifiesForAward && _memberSince != null
                        ? 'This race was before you joined in. It can be recorded but cannot be claimed towards Club Standards award. Update your membership date in profile if required.\n\n'
                        : '') +
                    'Age-grade compares your performance to world-class standards.\n\n'
                        '90%+ World Class/Elite\n'
                        '80–89% National Class\n'
                        '70–79% Regional Class\n'
                        '60–69% Local Level\n'
                        '50–59% Good Skill Level',
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitToSupabase(
                race: race,
                age: age,
                gender: gender,
                distance: distance,
                seconds: seconds,
                level: level,
                ageGrade: ageGrade,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: submitButtonBackground,
              foregroundColor: submitButtonForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: const Text('Submit Result'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // INPUT FORM — now restored with "Race" field
  // ---------------------------------------------------------
  Widget _buildInputForm() {
    final List<String> distances = const [
      '5K',
      '5M',
      '10K',
      '10M',
      'Half M',
      'Marathon',
      '20M',
      'Ultra',
    ];

    return Column(
      children: [
        // --------------------------------------
        // RACE NAME + DATE
        // --------------------------------------
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _raceNameController,
                onTap: _hideTop10Snap,
                decoration: const InputDecoration(labelText: 'Race/Event'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Race Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () {
                  _hideTop10Snap();
                  _pickRaceDate();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --------------------------------------
        // DISTANCE (+ ULTRA DETAIL) + TIME
        // --------------------------------------
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    flex: _selectedDistance == 'Ultra' ? 4 : 1,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedDistance,
                      items: distances
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedDistance = v;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Distance'),
                    ),
                  ),
                  if (_selectedDistance == 'Ultra') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ultraDistanceController,
                        onTap: _hideTop10Snap,
                        decoration: const InputDecoration(
                          labelText: 'K / M',
                          hintText: 'KM or MI',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _timeController,
                onTap: _hideTop10Snap,
                decoration: const InputDecoration(labelText: 'Time (hh:mm:ss)'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // --------------------------------------
        // GENDER + AGE
        // --------------------------------------
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Male')),
                  DropdownMenuItem(value: 'F', child: Text('Female')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedGender = v);
                },
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ageController,
                onTap: _hideTop10Snap,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // --------------------------------------
        // IMAGE CAROUSEL (only once club is known)
        // --------------------------------------
        if (_clubName != null)
          FadeTransition(
            opacity: _imageFadeAnimation,
            child: Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                final clubLower = (_clubName ?? '').toLowerCase();
                final isNNBR = clubLower.contains(
                  'north norfolk beach runners',
                );
                final borderColor = isNNBR
                    ? const Color(0xFF0055FF)
                    : colorScheme.primary;

                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      _carouselImages[_currentImageIndex],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Info sections for scrollable content
  // ---------------------------------------------------------
  Widget _buildInfoSection(
    String title,
    String content, {
    String? url,
    String? linkLabel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (url != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _launchUrl(url),
              child: Text(
                linkLabel ?? url,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.lightBlueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Current Club Standard Status section
  // ---------------------------------------------------------
  Widget _buildCurrentStatusSection() {
    final theme = Theme.of(context);

    Widget content;
    if (_loadingAwardStatus) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    } else if (_awardLevel != null) {
      final color = _levelColor(_awardLevel!);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Based on $_awardCount of the ${_awardDistances.length} club standard distances you\'ve raced,',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'You are currently achieving a:',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$_awardLevel Club Standard Award',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: _awardLevels.map((level) {
              final isActive = level == _awardLevel;
              return Chip(
                label: Text(level),
                backgroundColor: isActive
                    ? _levelColor(level)
                    : Colors.grey.shade900,
                labelStyle: TextStyle(
                  color: isActive ? Colors.black : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                avatar: Icon(
                  Icons.emoji_events,
                  size: 18,
                  color: isActive ? Colors.black : _levelColor(level),
                ),
              );
            }).toList(),
          ),
        ],
      );
    } else {
      content = Text(
        _awardError ??
            'Tap "Check Your Award" to see your current overall Club Standard once you have race records across our ${_awardDistances.length} key club distances.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF202040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 28,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Your Club Standard Status',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content,
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadingAwardStatus
                      ? null
                      : _loadCurrentAwardStatus,
                  icon: const Icon(Icons.flag_circle, size: 18),
                  label: const Text('Check Your Award'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_awardLevel != null && !_loadingAwardStatus)
                      ? () {
                          setState(() {
                            _showBadgeOnRecordsButton = true;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: const Text('Add club badge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Admin-only: Club Standards awardees snapshot
  // ---------------------------------------------------------
  Future<Map<String, List<String>>> _loadAllAwardsSnapshot() async {
    final client = Supabase.instance.client;
    // Restrict to the current admin's club if known
    Set<String>? allowedUserIds;
    final clubName = _clubName;
    final Map<String, DateTime?> memberSinceByUserId = {};
    final Map<String, String> idToName = {};
    if (clubName != null && clubName.isNotEmpty) {
      final profileRows = await client
          .from('user_profiles')
          .select('id, full_name, member_since')
          .eq('club', clubName);

      allowedUserIds = {
        for (final p in profileRows)
          if (p['id'] is String) p['id'] as String,
      };

      for (final p in profileRows) {
        final id = p['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final name = (p['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          idToName[id] = name;
        }
        final memberSinceStr = p['member_since'] as String?;
        memberSinceByUserId[id] =
            (memberSinceStr != null && memberSinceStr.isNotEmpty)
            ? DateTime.tryParse(memberSinceStr)
            : null;
      }

      if (allowedUserIds.isEmpty) {
        return {};
      }
    }

    final rows = allowedUserIds == null
        ? await client
              .from('race_results')
              .select(
                'user_id, distance, level, raceDate, time_seconds, gender, age',
              )
        : await client
              .from('race_results')
              .select(
                'user_id, distance, level, raceDate, time_seconds, gender, age',
              )
              .inFilter('user_id', allowedUserIds.toList());

    final Map<String, Map<String, String>> perUserBestByDistance = {};

    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final distance = (row['distance'] as String?) ?? '';
      final raceDate = DateTime.tryParse(row['raceDate'] as String? ?? '');
      final level = _effectiveLevelFromRaceRow(row);

      if (userId == null) continue;
      if (!_awardDistances.contains(distance)) continue;
      final memberSince = memberSinceByUserId[userId];
      if (memberSince != null && raceDate != null) {
        final memberDay = DateTime(
          memberSince.year,
          memberSince.month,
          memberSince.day,
        );
        final raceDay = DateTime(raceDate.year, raceDate.month, raceDate.day);
        if (raceDay.isBefore(memberDay)) continue;
      }
      if (!_awardLevels.contains(level)) continue;

      perUserBestByDistance.putIfAbsent(userId, () {
        return {for (final d in _awardDistances) d: ''};
      });

      final current = perUserBestByDistance[userId]![distance] ?? '';
      if (current.isEmpty) {
        perUserBestByDistance[userId]![distance] = level;
      } else {
        final currentIdx = _levelIndex(current);
        final newIdx = _levelIndex(level);
        if (newIdx > currentIdx) {
          perUserBestByDistance[userId]![distance] = level;
        }
      }
    }

    // Compute overall award for each user using the active club rule.
    final Map<String, String> userAwardLevel = {};

    perUserBestByDistance.forEach((userId, bestByDistance) {
      String? achievedLevel;
      for (final level in _awardLevels.reversed) {
        final requiredIdx = _levelIndex(level);
        int count = 0;
        for (final d in _awardDistances) {
          final lv = bestByDistance[d];
          if (lv == null || lv.isEmpty) continue;
          if (_levelIndex(lv) >= requiredIdx) {
            count++;
          }
        }
        if (count >= _requiredAwardDistanceCount) {
          achievedLevel = level;
          break;
        }
      }
      if (achievedLevel != null) {
        userAwardLevel[userId] = achievedLevel;
      }
    });

    if (userAwardLevel.isEmpty) {
      return {};
    }

    final userIds = userAwardLevel.keys.toList();
    if (idToName.length < userIds.length) {
      final profiles = await client
          .from('user_profiles')
          .select('id, full_name, member_since')
          .inFilter('id', userIds);

      for (final p in profiles) {
        final id = p['id'] as String?;
        if (id == null) continue;
        final name = (p['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          idToName[id] = name;
        }
        final memberSinceStr = p['member_since'] as String?;
        memberSinceByUserId[id] =
            (memberSinceStr != null && memberSinceStr.isNotEmpty)
            ? DateTime.tryParse(memberSinceStr)
            : memberSinceByUserId[id];
      }
    }

    final Map<String, List<String>> awardeesByLevel = {
      for (final level in _awardLevels.reversed) level: [],
    };

    userAwardLevel.forEach((userId, level) {
      final name = idToName[userId] ?? 'Unknown member';
      awardeesByLevel[level]!.add(name);
    });

    // Sort names inside each level
    awardeesByLevel.forEach((level, list) {
      list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });

    return awardeesByLevel;
  }

  Future<void> _exportVaultReportAsPdf(String title, String content) async {
    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              content,
              style: const pw.TextStyle(fontSize: 11, height: 1.3),
            ),
          ],
        ),
      );

      final safeTitle = title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
    }
  }

  Future<void> _showVaultReportSheet({
    required String title,
    required String content,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              media.viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: media.size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: content),
                            );
                            if (Navigator.canPop(sheetContext)) {
                              Navigator.pop(sheetContext);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied report to clipboard.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white38,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _exportVaultReportAsPdf(title, content);
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Export PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white38,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.maybePop(sheetContext);
                            await _publishListAsPostFromStandards(
                              title: title,
                              content: content,
                            );
                          },
                          icon: const Icon(Icons.campaign, size: 18),
                          label: const Text('Publish as post'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _buildAgeGradeTopsReport() async {
    final client = Supabase.instance.client;
    // Restrict to the current admin's club if known
    Set<String>? allowedUserIds;
    final clubName = _clubName;
    if (clubName != null && clubName.isNotEmpty) {
      final profileRows = await client
          .from('user_profiles')
          .select('id')
          .eq('club', clubName);

      allowedUserIds = {
        for (final p in profileRows)
          if (p['id'] is String) p['id'] as String,
      };

      if (allowedUserIds.isEmpty) {
        return null;
      }
    }

    final rows = allowedUserIds == null
        ? await client
              .from('race_results')
              .select(
                'user_id, race_name, distance, age_grade, level, raceDate',
              )
              .order('raceDate', ascending: false)
        : await client
              .from('race_results')
              .select(
                'user_id, race_name, distance, age_grade, level, raceDate',
              )
              .inFilter('user_id', allowedUserIds.toList())
              .order('raceDate', ascending: false);

    if (rows.isEmpty) return null;

    final Map<String, List<Map<String, dynamic>>> byDistance = {};
    final Set<String> userIds = {};

    for (final row in rows) {
      final distance = (row['distance'] as String?) ?? '';
      if (!_awardDistances.contains(distance)) continue;

      final ageGradeRaw = row['age_grade'];
      final ageGrade = ageGradeRaw is num ? ageGradeRaw.toDouble() : 0.0;
      if (ageGrade <= 0) continue;

      byDistance.putIfAbsent(distance, () => <Map<String, dynamic>>[]);
      byDistance[distance]!.add(row);

      final userId = row['user_id'] as String?;
      if (userId != null) {
        userIds.add(userId);
      }
    }

    if (byDistance.isEmpty) return null;

    final Map<String, String> idToName = {};
    if (userIds.isNotEmpty) {
      final profiles = await client
          .from('user_profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList());

      for (final p in profiles) {
        final id = p['id'] as String?;
        if (id == null) continue;
        final name = (p['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          idToName[id] = name;
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Latest Age-Grade Tops');
    buffer.writeln('');

    for (final distance in _awardDistances) {
      final list = byDistance[distance];
      if (list == null || list.isEmpty) continue;

      list.sort((a, b) {
        final agA = (a['age_grade'] is num)
            ? (a['age_grade'] as num).toDouble()
            : 0.0;
        final agB = (b['age_grade'] is num)
            ? (b['age_grade'] as num).toDouble()
            : 0.0;
        final dateA =
            DateTime.tryParse(a['raceDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['raceDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final cmp = agB.compareTo(agA);
        if (cmp != 0) return cmp;
        return dateB.compareTo(dateA);
      });

      final top = list.take(3).toList();
      buffer.writeln('$distance — Top ${top.length}');

      for (var i = 0; i < top.length; i++) {
        final row = top[i];
        final userId = row['user_id'] as String?;
        final name = idToName[userId] ?? 'Unknown member';
        final raceName = (row['race_name'] as String?)?.trim();
        final level = (row['level'] as String?) ?? '';
        final ageGradeRaw = row['age_grade'];
        final ageGrade = ageGradeRaw is num ? ageGradeRaw.toDouble() : 0.0;
        final raceDateStr = row['raceDate'] as String?;
        String dateLabel = '';
        if (raceDateStr != null) {
          final dt = DateTime.tryParse(raceDateStr);
          if (dt != null) {
            dateLabel =
                '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year % 100}';
          }
        }

        buffer.writeln(
          '${i + 1}) $name — ${raceName ?? 'Unknown race'} — '
          '${ageGrade.toStringAsFixed(1)}%'
          '${level.isNotEmpty ? ' ($level)' : ''}'
          '${dateLabel.isNotEmpty ? ' — $dateLabel' : ''}',
        );
      }

      buffer.writeln('');
    }

    final text = buffer.toString().trimRight();
    return text.isEmpty ? null : text;
  }

  Future<String?> _buildWeeklyRunningReport() async {
    final client = Supabase.instance.client;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEndDate = weekStartDate.add(const Duration(days: 7));

    // Restrict to the current admin's club if known
    Set<String>? allowedUserIds;
    final clubName = _clubName;
    if (clubName != null && clubName.isNotEmpty) {
      final profileRows = await client
          .from('user_profiles')
          .select('id')
          .eq('club', clubName);

      allowedUserIds = {
        for (final p in profileRows)
          if (p['id'] is String) p['id'] as String,
      };

      if (allowedUserIds.isEmpty) {
        return null;
      }
    }

    final rows = allowedUserIds == null
        ? await client
              .from('race_results')
              .select(
                'user_id, race_name, distance, age_grade, level, raceDate, time_seconds',
              )
              .gte('raceDate', weekStartDate.toIso8601String())
              .lt('raceDate', weekEndDate.toIso8601String())
              .order('raceDate', ascending: true)
        : await client
              .from('race_results')
              .select(
                'user_id, race_name, distance, age_grade, level, raceDate, time_seconds',
              )
              .inFilter('user_id', allowedUserIds.toList())
              .gte('raceDate', weekStartDate.toIso8601String())
              .lt('raceDate', weekEndDate.toIso8601String())
              .order('raceDate', ascending: true);

    if (rows.isEmpty) return null;

    final Set<String> userIds = {};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      if (userId != null) {
        userIds.add(userId);
      }
    }

    final Map<String, String> idToName = {};
    if (userIds.isNotEmpty) {
      final profiles = await client
          .from('user_profiles')
          .select('id, full_name')
          .inFilter('id', userIds.toList());

      for (final p in profiles) {
        final id = p['id'] as String?;
        if (id == null) continue;
        final name = (p['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          idToName[id] = name;
        }
      }
    }

    final weekEndInclusive = weekStartDate.add(const Duration(days: 6));

    final buffer = StringBuffer();
    buffer.writeln("Sunday's Running Report");
    buffer.writeln(
      'Week of '
      '${weekStartDate.day.toString().padLeft(2, '0')} '
      '${_monthShort(weekStartDate.month)} ${weekStartDate.year} '
      'to '
      '${weekEndInclusive.day.toString().padLeft(2, '0')} '
      '${_monthShort(weekEndInclusive.month)} ${weekEndInclusive.year}',
    );
    buffer.writeln('');

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final name = idToName[userId] ?? 'Unknown member';
      final raceName = (row['race_name'] as String?)?.trim();
      final distance = (row['distance'] as String?) ?? '';
      final level = (row['level'] as String?) ?? '';
      final ageGradeRaw = row['age_grade'];
      final ageGrade = ageGradeRaw is num ? ageGradeRaw.toDouble() : 0.0;
      final timeSecondsRaw = row['time_seconds'];
      final timeSeconds = timeSecondsRaw is num ? timeSecondsRaw.toInt() : 0;

      final raceDateStr = row['raceDate'] as String?;
      String dateLabel = '';
      if (raceDateStr != null) {
        final dt = DateTime.tryParse(raceDateStr);
        if (dt != null) {
          final weekday = weekdays[dt.weekday - 1];
          dateLabel =
              '$weekday ${dt.day.toString().padLeft(2, '0')} ${_monthShort(dt.month)}';
        }
      }

      final timeLabel = timeSeconds > 0 ? _formatTime(timeSeconds) : null;

      buffer.writeln(
        '• ${dateLabel.isNotEmpty ? '$dateLabel — ' : ''}'
        '$name — ${raceName ?? 'Unknown race'} '
        '(${distance.isNotEmpty ? distance : 'distance n/a'})'
        '${timeLabel != null ? ' — $timeLabel' : ''}'
        '${ageGrade > 0 ? ' — ${ageGrade.toStringAsFixed(1)}%' : ''}'
        '${level.isNotEmpty ? ' — [$level]' : ''}',
      );
    }

    final text = buffer.toString().trimRight();
    return text.isEmpty ? null : text;
  }

  Widget _buildAdminAwardsSection() {
    if (!_isAdmin) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Icon(
                Icons.admin_panel_settings,
                color: Colors.redAccent,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                "The Secretary's Vault",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Admin-only reports based on all submitted race records.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final awardeesByLevel = await _loadAllAwardsSnapshot();
              if (!mounted) return;

              if (awardeesByLevel.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No members currently meet Club Standards.'),
                  ),
                );
                return;
              }

              final now = DateTime.now();
              final title =
                  'Latest Club Standard Awardees'
                  ' — updated to '
                  '${now.day.toString().padLeft(2, '0')} '
                  '${_monthShort(now.month)} ${now.year}';

              final buffer = StringBuffer();
              buffer.writeln(title);
              buffer.writeln('');
              for (final level in _awardLevels.reversed) {
                final names = awardeesByLevel[level];
                if (names == null || names.isEmpty) continue;
                buffer.writeln('$level Award');
                for (final name in names) {
                  buffer.writeln(' - $name');
                }
                buffer.writeln('');
              }

              final content = buffer.toString().trimRight();
              await _showVaultReportSheet(title: title, content: content);
            },
            icon: const Icon(Icons.workspace_premium, size: 18),
            label: const Text('Latest Club Standard Awardees'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final content = await _buildAgeGradeTopsReport();
              if (!mounted) return;
              if (content == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No age-grade records found yet.'),
                  ),
                );
                return;
              }

              const title = 'Latest Age-Grade Tops';
              await _showVaultReportSheet(title: title, content: content);
            },
            icon: const Icon(Icons.leaderboard, size: 18),
            label: const Text('Latest Age-Grade Tops'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0055FF),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              final content = await _buildWeeklyRunningReport();
              if (!mounted) return;
              if (content == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No race results found for this week yet.'),
                  ),
                );
                return;
              }

              const title = "Sunday's Running Report";
              await _showVaultReportSheet(title: title, content: content);
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text("Sunday's Running Report"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasEmergencyPhone(Map<String, dynamic> user) {
    final hasConsent = user['emergency_details_consent'] == true;
    final number = (user['emergency_contact_number'] as String?)?.trim();
    return hasConsent && number != null && number.isNotEmpty;
  }

  String _iceMemberName(Map<String, dynamic> user) {
    final fullName = (user['full_name'] as String?)?.trim();
    return (fullName != null && fullName.isNotEmpty) ? fullName : 'Member';
  }

  String _iceFieldValue(dynamic value, {String fallback = 'Not set'}) {
    final text = (value as String?)?.trim();
    return (text != null && text.isNotEmpty) ? text : fallback;
  }

  List<Map<String, dynamic>> _sortedIceMembers(
    List<Map<String, dynamic>> rows,
  ) {
    final members = rows.where(_hasEmergencyPhone).toList();
    members.sort(
      (a, b) => _iceMemberName(
        a,
      ).toLowerCase().compareTo(_iceMemberName(b).toLowerCase()),
    );
    return members;
  }

  Stream<List<Map<String, dynamic>>> _adminIceMembersStream() {
    final clubName = _clubName?.trim();
    if (clubName == null || clubName.isEmpty) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }

    return Supabase.instance.client
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('club', clubName)
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  String _buildIceFullListContent({
    required List<Map<String, dynamic>> allMembers,
    required List<Map<String, dynamic>> iceMembers,
  }) {
    final clubName = (_clubName?.trim().isNotEmpty ?? false)
        ? _clubName!.trim()
        : 'Current club';
    final lines = <String>[
      'ICE Full List - $clubName',
      'Generated: ${DateTime.now().toLocal()}',
      'Total members: ${allMembers.length}',
      'Members with consented ICE details: ${iceMembers.length}',
      '',
    ];

    if (iceMembers.isEmpty) {
      lines.add('No consented ICE contacts found.');
      return lines.join('\n');
    }

    for (var index = 0; index < iceMembers.length; index++) {
      final user = iceMembers[index];

      lines
        ..add('${index + 1}. ${_iceMemberName(user)}')
        ..add(
          '   ICE contact: ${_iceFieldValue(user['emergency_contact_name'])}',
        )
        ..add(
          '   Relation: ${_iceFieldValue(user['emergency_contact_relation'])}',
        )
        ..add('   Phone: ${_iceFieldValue(user['emergency_contact_number'])}');

      lines.add('');
    }

    return lines.join('\n');
  }

  Future<void> _showAdminIceFullListSheet() async {
    final clubName = _clubName?.trim();
    if (clubName == null || clubName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine your club.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              media.viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: media.size.height * 0.78,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _adminIceMembersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load ICE list: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allMembers = snapshot.data!;
                  final iceMembers = _sortedIceMembers(allMembers);
                  final exportText = _buildIceFullListContent(
                    allMembers: allMembers,
                    iceMembers: iceMembers,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ICE Full List',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: iceMembers.isEmpty
                            ? const Center(
                                child: Text(
                                  'No consented ICE contacts found for this club.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: iceMembers.length,
                                separatorBuilder: (_, __) => const Divider(
                                  color: Colors.white12,
                                  height: 14,
                                ),
                                itemBuilder: (_, index) {
                                  final user = iceMembers[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      _iceMemberName(user),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'ICE contact: ${_iceFieldValue(user['emergency_contact_name'])}\n'
                                        'Relation: ${_iceFieldValue(user['emergency_contact_relation'])}\n'
                                        'Phone: ${_iceFieldValue(user['emergency_contact_number'])}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final navigator = Navigator.of(sheetContext);
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(
                                  ClipboardData(text: exportText),
                                );
                                if (navigator.canPop()) {
                                  navigator.pop();
                                }
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Copied ICE full list to clipboard.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white38,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _exportVaultReportAsPdf(
                                  'ICE Full List',
                                  exportText,
                                );
                              },
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Export PDF'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white38,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _searchIceMembers(String term) async {
    final trimmed = term.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _iceSearchResults = [];
        _searchingIceMembers = false;
      });
      return;
    }

    setState(() => _searchingIceMembers = true);

    try {
      var query = Supabase.instance.client
          .from('user_profiles')
          .select(
            'id, full_name, emergency_contact_name, emergency_contact_number, emergency_contact_relation, emergency_details_consent, medical_notes, club',
          );

      if (_clubName != null && _clubName!.trim().isNotEmpty) {
        query = query.eq('club', _clubName!.trim());
      }

      final rows = await query.ilike('full_name', '$trimmed%').limit(12);

      final results = List<Map<String, dynamic>>.from(
        rows,
      ).where(_hasEmergencyPhone).toList();

      if (!mounted) return;
      setState(() {
        _iceSearchResults = results;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ICE search failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _searchingIceMembers = false);
      }
    }
  }

  Future<void> _showEmergencyContactDialog(Map<String, dynamic> user) async {
    final emergencyName =
        (user['emergency_contact_name'] as String?)?.trim() ?? 'Not set';
    final emergencyNumber =
        (user['emergency_contact_number'] as String?)?.trim() ?? '';
    final emergencyRelation =
        (user['emergency_contact_relation'] as String?)?.trim() ?? 'Not set';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Emergency contact',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emergencyName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Relation: $emergencyRelation',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: emergencyNumber.isEmpty
                  ? null
                  : () async {
                      final launched = await launchUrl(
                        Uri(scheme: 'tel', path: emergencyNumber),
                      );
                      if (!launched && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open phone dialler'),
                          ),
                        );
                      }
                    },
              child: Text(
                emergencyNumber.isEmpty ? 'Number not set' : emergencyNumber,
                style: TextStyle(
                  color: emergencyNumber.isEmpty
                      ? Colors.white70
                      : Colors.lightBlueAccent,
                  decoration: emergencyNumber.isEmpty
                      ? TextDecoration.none
                      : TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showIceActions(Map<String, dynamic> user) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (user['full_name'] as String?)?.trim().isNotEmpty == true
                  ? (user['full_name'] as String).trim()
                  : 'Member',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Emergency contact',
                  onPressed: () => _showEmergencyContactDialog(user),
                  icon: const Icon(
                    Icons.phone_in_talk,
                    color: Colors.lightBlueAccent,
                    size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIceSearchSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 80),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.manage_search,
                color: Colors.lightBlueAccent,
                size: 24,
              ),
              SizedBox(height: 6),
              Text(
                'ICE Search',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Your health and safety is your Club's paramount concern.\nIn case of emergency whilst on training/race, call 999, then inform the next of kin via the ICE search below.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _iceSearchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search member name',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF151828),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _searchIceMembers,
          ),
          const SizedBox(height: 12),
          if (_searchingIceMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_iceSearchController.text.trim().length < 2)
            const Text(
              'Type at least 2 letters to search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          else if (_iceSearchResults.isEmpty)
            const Text(
              'No matching consented ICE contacts found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _iceSearchResults.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12, height: 14),
              itemBuilder: (_, index) {
                final user = _iceSearchResults[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (user['full_name'] as String?)?.trim().isNotEmpty == true
                        ? (user['full_name'] as String).trim()
                        : 'Member',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () => _showIceActions(user),
                );
              },
            ),
          if (_isAdmin) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _showAdminIceFullListSheet,
                icon: const Icon(Icons.list_alt),
                label: const Text('View Full List'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _publishListAsPostFromStandards({
    required String title,
    required String content,
  }) async {
    if (await UserService.isBlocked(context: context)) {
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post.')),
        );
      }
      return;
    }

    try {
      String authorName = 'Unknown';
      try {
        final profile = await client
            .from('user_profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          authorName = name.trim();
        } else {
          final displayName = user.userMetadata?['full_name'] as String?;
          if (displayName != null && displayName.trim().isNotEmpty) {
            authorName = displayName.trim();
          }
        }
      } catch (_) {
        final displayName = user.userMetadata?['full_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          authorName = displayName.trim();
        }
      }

      final isAdmin = await UserService.isAdmin();
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 100));

      await client.from('club_posts').insert({
        'title': title,
        'content': content,
        'author_id': user.id,
        'author_name': authorName,
        'expiry_date': expiry.toIso8601String(),
        'created_at': now.toIso8601String(),
        'is_approved': isAdmin,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdmin
                  ? 'Post published with Club Standards awardees.'
                  : 'Post created — awaiting admin approval.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error publishing post: $e')));
      }
    }
  }

  // ---------------------------------------------------------
  // BUILD UI with CustomScrollView
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Avoid showing a partial layout while we don't yet know the
    // user's club/profile; once loaded, the full UI appears in
    // one go instead of elements popping in.
    if (!_profileLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    final baseTheme = Theme.of(context);
    final clubLower = (_clubName ?? '').toLowerCase();
    final isNNBR = clubLower.contains('north norfolk beach runners');

    // For NNBR, restore the classic blue/yellow field borders
    // while keeping other clubs using the app-wide theme.
    final themedData = isNNBR
        ? baseTheme.copyWith(
            inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF0055FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFFD700),
                  width: 2,
                ),
              ),
            ),
          )
        : baseTheme;

    return Theme(
      data: themedData,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // HEADER
                  SliverAppBar(
                    backgroundColor: Colors.black,
                    elevation: _scrollOffset > 0 ? 4 : 0,
                    floating: false,
                    pinned: true,
                    expandedHeight: 130,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.yellowAccent.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white30,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.yellowAccent.withValues(
                                  alpha: _scrollOffset > 0 ? 0.4 : 0.3,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Image.asset(
                                'assets/images/rank_logo.png',
                                height: 70,
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'CLUB STANDARDS',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                          color: Color.fromARGB(
                                            255,
                                            77,
                                            3,
                                            224,
                                          ),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: SlideTransition(
                                        position: _slideAnimation,
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Race And Admin Team On The Go',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.normal,
                                              fontWeight: FontWeight.w700,
                                              color: Color.from(
                                                alpha: 0.886,
                                                red: 0.349,
                                                green: 0.008,
                                                blue: 0.024,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // TOP CLUB PHOTO (static)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      child: Builder(
                        builder: (context) {
                          final club = (_clubName ?? '').toLowerCase();
                          final isNRR = club.contains('norwich road runners');
                          final isNNBR = club.contains(
                            'north norfolk beach runners',
                          );

                          // While club is unknown/loading, don't show a club hero at all
                          // to avoid a noticeable flash before the club-specific UI.
                          if (_clubName == null || (!isNRR && !isNNBR)) {
                            return const SizedBox.shrink();
                          }

                          // Common container with rounded corners & clipping so
                          // both clubs get visibly rounded images.
                          return Container(
                            height: isNRR ? 180 : 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.black,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              isNRR
                                  ? 'assets/images/NRRmain.png'
                                  : 'assets/images/nnbr_cover.png',
                              width: double.infinity,
                              fit: isNRR ? BoxFit.cover : BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // INPUT FORM
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 12),
                          ],
                        ),
                        child: _buildInputForm(),
                      ),
                    ),
                  ),

                  // RESULT MESSAGE
                  SliverToBoxAdapter(
                    child: _resultMessage == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Text(
                              _resultMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),

                  // INFO SECTIONS (Scrollable)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildInfoSection(
                          'Club Standards',
                          _clubStandardsDescription(),
                          url: _clubStandardsUrl(),
                          linkLabel: _clubStandardsLinkLabel(),
                        ),
                        _buildInfoSection(
                          'Age-Grading',
                          'Age-graded percentages are provided for guidance only and do not form part of the Club Standards assessment.\n\n'
                              'Age record tables used are from ARRS, the Association of Road Racing Statisticians, which they maintained and updates as necessary.\n\n'
                              'The distance record updates are as follows:\n'
                              '\u2022 5km last update on 06 December 2017\n'
                              '\u2022 10km last update on 28 November 2017\n'
                              '\u2022 5miles last update on 10 December 2017\n'
                              '\u2022 10miles last update on 16 March 2020\n'
                              '\u2022 Half Marathon last update on 20 November 2017\n'
                              '\u2022 Marathon last update on 01 November 2019\n\n'
                              'ARRS is actively looking for people to help maintain their records, as well as sponsorships.',
                          url: 'https://arrs.run/',
                          linkLabel:
                              'View full age-grading tables at ARRS (arrs.run)',
                        ),
                        const SizedBox(height: 8),
                        _buildCurrentStatusSection(),
                        _buildAdminAwardsSection(),
                        _buildIceSearchSection(),
                        const SizedBox(height: 80),
                      ]),
                    ),
                  ),
                ],
              ),
              _buildTop10SnapView(),
            ],
          ),
        ),

        // FIXED BUTTON BAR at bottom (equal-width buttons)
        bottomNavigationBar: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Builder(
            builder: (context) {
              final isNRR =
                  _clubName != null &&
                  _clubName!.toLowerCase().contains('norwich road runners');

              return Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          ElevatedButton(
                            onPressed: _onCalculate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isNRR
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFFFFC107),
                              foregroundColor: isNRR
                                  ? Colors.white
                                  : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isNRR
                                      ? Colors.white70
                                      : Colors.black87,
                                  width: 1.3,
                                ),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Check\nAchievement',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _toggleTop10Snap,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Icon(
                                      Icons.attach_file,
                                      size: 18,
                                      color: isNRR
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HistoryScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isNRR
                                  ? Colors.white
                                  : const Color(0xFF0D47A1),
                              foregroundColor: isNRR
                                  ? Colors.black
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isNRR
                                      ? Colors.black87
                                      : Colors.white70,
                                  width: 1.3,
                                ),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'View My\nRace Records',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_showBadgeOnRecordsButton)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      _levelColor(_awardLevel!),
                                      const Color(0xFF001133),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTop10SnapView() {
    final isNRR =
        _clubName != null &&
        _clubName!.toLowerCase().contains('norwich road runners');

    return Positioned(
      left: 16,
      bottom: 10,
      child: IgnorePointer(
        ignoring: !_showTop10Snap,
        child: AnimatedSlide(
          offset: _showTop10Snap ? Offset.zero : const Offset(0, 0.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _showTop10Snap ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isNRR ? Colors.white70 : const Color(0xFFFFD700),
                  width: 1,
                ),
              ),
              child: _loadingTop10Snap
                  ? const SizedBox(
                      height: 60,
                      width: 60,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'My Top 10',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final distance in _snapDistances)
                          _buildSnapRow(distance, _top10Positions[distance]),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnapRow(String distance, int? position) {
    Widget trailing;

    if (position == null || position > 10) {
      trailing = const Text(
        '×',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      );
    } else if (position == 1 || position == 2 || position == 3) {
      final String medal;
      if (position == 1) {
        medal = '🥇';
      } else if (position == 2) {
        medal = '🥈';
      } else {
        medal = '🥉';
      }

      trailing = Text(medal, style: const TextStyle(fontSize: 16));
    } else {
      trailing = Text(
        _ordinal(position),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              distance,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          trailing,
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) {
      return '${n}th';
    }
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
