import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/calculator_logic.dart';
import 'package:runrank/standards_data.dart';
import 'package:runrank/widgets/result_card.dart';
import 'package:runrank/services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();

    _subTitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _subTitleController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _subTitleController, curve: Curves.easeOut),
        );
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset * 0.25;
        });
      });

    // Image carousel animation
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _imageFadeAnimation = CurvedAnimation(
      parent: _imageController,
      curve: Curves.easeInOut,
    );

    // Start image carousel
    _imageController.forward();
    _imageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _imageController.reverse().then((_) {
          setState(() {
            _currentImageIndex =
                (_currentImageIndex + 1) % _carouselImages.length;
          });
          _imageController.forward();
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _subTitleController.forward();
    });
  }

  // ---------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------
  final TextEditingController _raceNameController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  String _selectedGender = 'M';
  String _selectedDistance = '5K';
  DateTime? _selectedRaceDate;

  String? _resultMessage;

  @override
  void dispose() {
    _raceNameController.dispose();
    _timeController.dispose();
    _ageController.dispose();
    _dateController.dispose();
    _subTitleController.dispose();
    _scrollController.dispose();
    _imageTimer.cancel();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  // ---------------------------------------------------------
  // Month formatting
  // ---------------------------------------------------------
  String _monthShort(int m) {
    const months = [
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
    return months[m - 1];
  }

  // ---------------------------------------------------------
  // Date picker
  // ---------------------------------------------------------
  Future<void> _pickRaceDate() async {
    final today = DateTime.now();
    final lastDate = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: lastDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
    );

    if (picked != null) {
      _selectedRaceDate = picked;
      setState(() {
        _dateController.text =
            "${picked.day.toString().padLeft(2, '0')} "
            "${_monthShort(picked.month)} "
            "${picked.year % 100}";
      });
    }
  }

  // ---------------------------------------------------------
  // Submit to Supabase
  // ---------------------------------------------------------
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

    await AuthService.submitRaceResult(
      raceName: race,
      gender: gender,
      age: age,
      distance: distance,
      finishSeconds: seconds,
      level: level,
      ageGrade: ageGrade,
      raceDate: raceDate,
    );
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
            // ← Add this optional flag inside ResultCard (next section)
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
        // DISTANCE + TIME
        // --------------------------------------
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedDistance,
                items: distances
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDistance = v);
                },
                decoration: const InputDecoration(labelText: 'Distance'),
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
                                      'Calculate your club standard!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
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
                child: ElevatedButton(
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
