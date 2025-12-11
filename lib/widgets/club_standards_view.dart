import 'package:flutter/material.dart';
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
  // Animation for subtitle fade + slide
  // ---------------------------------------------------------
  late AnimationController _subTitleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

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

    super.dispose();
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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
                value: _selectedDistance,
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
                value: _selectedGender,
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

        const SizedBox(height: 12),

        // --------------------------------------
        // INFO TEXT
        // --------------------------------------
        const Text(
          'NNBR Club Standards require members to achieve qualifying times '
          'in four of six distances over a calendar year to earn an award.\n'
          'Qualifying races are UKA licensed and Club Handicap events. Parkruns and training runs do not count.\n'
          'A runner may achieve different standards in all categories during the year but only the lowest category will be awarded.\n'
          'Awards will be presented at the Annual Awards evening.',
          style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------
  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _onCalculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Check\nAchievement',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HistoryScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Check\nRace Records',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER (unchanged except spacing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellowAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/rank_logo.png', height: 70),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'CLUB STANDARDS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: Color.fromARGB(255, 77, 3, 224),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 1),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: const Text(
                                'Race & Team Admin On The Go',
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            //SCROLL AREA
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Cover Image
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 170, // visible height
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final parallax = (_scrollOffset * 0.25).clamp(
                                0.0,
                                60.0,
                              );

                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  parallax,
                                ), // <<< REAL PARALLAX
                                child: Image.asset(
                                  'assets/images/nnbr_cover.png',
                                  height: 230, // larger than container
                                  width: constraints.maxWidth,
                                  fit: BoxFit.cover,
                                  alignment: Alignment(
                                    1.0,
                                    0,
                                  ), // keeps NNBR logo visible
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // INPUT FORM
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    // RESULT MESSAGE
                    if (_resultMessage != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            // FIXED BUTTON BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onCalculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check\nAchievement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HistoryScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check\nRace Records',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
