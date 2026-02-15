import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:runrank/calculator_logic.dart';
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
  final List<String> _carouselImages = [
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
  late AnimationController _imageController;
  late Animation<double> _imageFadeAnimation;

  // ---------------------------------------------------------
  // Current Club Standard award status (from race history)
  // ---------------------------------------------------------
  final List<String> _awardLevels = const [
    'Copper',
    'Bronze',
    'Silver',
    'Gold',
    'Diamond',
  ];

  final List<String> _awardDistances = const [
    '5K',
    '5M',
    '10K',
    '10M',
    'Half M',
    'Marathon',
  ];

  // Distances for the input form dropdown
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

  // Input controllers
  final TextEditingController _raceNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _ultraDistanceController =
      TextEditingController();

  DateTime? _selectedRaceDate;
  String _selectedDistance = '5K';
  String _selectedGender = 'M';
  String? _resultMessage;

  // Award / badge state
  bool _loadingAwardStatus = false;
  String? _awardLevel;
  int _awardCount = 0;
  String? _awardError;
  bool _showBadgeOnRecordsButton = false;

  // Admin flag
  bool _isAdmin = false;

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
          .select('distance, level')
          .eq('user_id', user.id);

      if (rows.isEmpty) {
        setState(() {
          _awardLevel = null;
          _awardCount = 0;
          _awardError =
              'Once you have race records across our six key club distances, you\'ll see your overall Club Standard Award here.';
          _showBadgeOnRecordsButton = false;
        });
        return;
      }

      final Map<String, String> bestByDistance = {
        for (final d in _awardDistances) d: '',
      };

      for (final row in rows) {
        final distance = (row['distance'] as String?) ?? '';
        final level = (row['level'] as String?) ?? '';

        if (!_awardDistances.contains(distance)) continue;
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
        if (count >= 4) {
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
      firstDate: DateTime(now.year - 5),
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

    // After a successful submission, ensure club records stay in sync.
    // For 20M/Ultra we always create a matching club record entry so
    // their pages populate immediately. For standard distances, we only
    // add a club record when this performance beats the current holder.
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final recordsService = ClubRecordsService();
    bool shouldEnsureRecord = false;

    if (distance == '20M' || distance == 'Ultra') {
      shouldEnsureRecord = true;
    } else {
      final currentHolder = await recordsService.getClubRecordHolder(distance);
      if (currentHolder == null || seconds < currentHolder.timeSeconds) {
        shouldEnsureRecord = true;
      }
    }

    if (shouldEnsureRecord) {
      await recordsService.ensureRecordForResult(
        userId: user.id,
        distance: distance,
        timeSeconds: seconds,
        raceName: race,
        raceDate: raceDate,
      );
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
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final gender = _selectedGender;
    final distance = _selectedDistance;
    // Special handling for non-standard distances (20M, Ultra)
    if (distance == '20M' || distance == 'Ultra') {
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
    final eval = RunCalculator.evaluate(
      gender: gender,
      age: age,
      distance: distance,
      finishSeconds: seconds,
    );

    final level = eval['level'] as String;
    final ageGrade = eval['ageGrade'] as double;
    final ageGradeMessage = eval['ageGradeMessage'] as String;

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
          child: ResultCard(
            standard: level,
            ageGrade: ageGrade,
            ageGradeMessage: ageGradeMessage,
            guidance:
                'Age-grade compares your performance to world-class standards.\n\n'
                '90%+ World Class/Elite\n'
                '80–89% National Class\n'
                '70–79% Regional Class\n'
                '60–69% Local Level\n'
                '50–59% Good Skill Level',
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
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
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
                onTap: _pickRaceDate,
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDistance,
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
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _ultraDistanceController,
                        decoration: const InputDecoration(
                          labelText: 'Ultra',
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
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // --------------------------------------
        // IMAGE CAROUSEL
        // --------------------------------------
        FadeTransition(
          opacity: _imageFadeAnimation,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0055FF), width: 2),
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
            'Based on $_awardCount of the 6 club standard distances you\'ve raced,',
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
            'Tap "Check Your Award" to see your current overall Club Standard once you have race records across our six key club distances.',
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
    final rows = await client
        .from('race_results')
        .select('user_id, distance, level, raceDate');

    final Map<String, Map<String, String>> perUserBestByDistance = {};

    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final distance = (row['distance'] as String?) ?? '';
      final level = (row['level'] as String?) ?? '';

      if (userId == null) continue;
      if (!_awardDistances.contains(distance)) continue;
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

    // Compute overall award for each user using the same rule (4 of 6 distances)
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
        if (count >= 4) {
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
    final profiles = await client
        .from('user_profiles')
        .select('id, full_name')
        .inFilter('id', userIds);

    final Map<String, String> idToName = {};
    for (final p in profiles) {
      final id = p['id'] as String?;
      if (id == null) continue;
      final name = (p['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        idToName[id] = name;
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
    final rows = await client
        .from('race_results')
        .select('user_id, race_name, distance, age_grade, level, raceDate')
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

    final rows = await client
        .from('race_results')
        .select(
          'user_id, race_name, distance, age_grade, level, raceDate, time_seconds',
        )
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
              backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
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
      final expiry = now.add(const Duration(days: 365));

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
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
                      border: Border.all(color: Colors.white30, width: 1.5),
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
                        Image.asset('assets/images/rank_logo.png', height: 70),
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
                                    color: Color.fromARGB(255, 77, 3, 224),
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
                                        fontWeight: FontWeight.w600,
                                        color: Color.fromARGB(221, 235, 81, 5),
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

            // TOP NNBR PHOTO (static)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/nnbr_cover.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // INPUT FORM
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildInfoSection(
                    'Club Standards',
                    'NNBR Club Standards require members to achieve qualifying times '
                        'in four of six distances over a calendar year to earn an award.\n\n'
                        'Qualifying races are UKA licensed and Club Handicap events. Parkruns and training runs do not count.\n\n'
                        'A runner may achieve different standards in all categories during the year but only the lowest category will be awarded.\n\n'
                        'Awards will be presented at the Annual Awards evening.',
                    url:
                        'https://www.northnorfolkbeachrunners.com/club-standards',
                    linkLabel: 'View full club standards on NNBR website',
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
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),

      // FIXED BUTTON BAR at bottom
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.black,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onCalculate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Check\nAchievement',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HistoryScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check\nRace Records',
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
        ),
      ),
    );
  }
}
