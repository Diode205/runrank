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

class _ClubStandardsViewState extends State<ClubStandardsView> {
  // Form inputs
  final TextEditingController _raceNameController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _selectedGender = 'M';
  String _selectedDistance = '5K';

  // Optional race date
  DateTime? _selectedRaceDate;

  String? _resultMessage;

  @override
  void dispose() {
    _raceNameController.dispose();
    _timeController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // -----------------------------
  // DATE PICKER
  // -----------------------------
  Future<void> _pickRaceDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: "Select Race Date",
    );
    if (selected != null) {
      setState(() => _selectedRaceDate = selected);
    }
  }

  // -----------------------------
  // SUBMIT TO SUPABASE
  // -----------------------------
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

  // -----------------------------
  // CALCULATE + SHOW DIALOG
  // -----------------------------
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
        title: const Text('WELL DONE!'),
        content: ResultCard(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
            child: const Text('Submit Result'),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // INPUT FORM (inside card)
  // -----------------------------
  Widget _buildInputForm() {
    return Column(
      children: [
        // Race + Date row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _raceNameController,
                decoration: const InputDecoration(labelText: 'Running Event'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _pickRaceDate,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedRaceDate == null
                              ? 'Date'
                              : '${_selectedRaceDate!.day}/${_selectedRaceDate!.month}/${_selectedRaceDate!.year}',
                          style: TextStyle(
                            color: _selectedRaceDate == null
                                ? Colors.grey.shade600
                                : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Distance + Time row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedDistance,
                items: distances
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedDistance = v);
                },
                decoration: const InputDecoration(labelText: 'Distance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (hh:mm:ss)',
                  hintText: 'e.g. 1:12:45 or 22:30',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Gender + Age row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Male')),
                  DropdownMenuItem(value: 'F', child: Text('Female')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _selectedGender = v);
                },
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        const Text(
          'NNBR Club Standards require members to achieve qualifying times '
          'in four of six distances over a calendar year to earn an award. '
          'Qualifying races must be UKA licensed, or Club Handicap events. '
          'Parkruns and training runs do not count. Awards are based on '
          'runners’ performances within their Age Group category. Higher '
          'standard award is given if a runner achieved different levels '
          'in their qualifying races.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // -----------------------------
  // BUTTONS ROW
  // -----------------------------
  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Check Achievement (now shows dialog with optional submit)
          Expanded(
            child: ElevatedButton(
              onPressed: _onCalculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellowAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
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

          Flexible(
            child: Image.asset(
              'assets/images/runners_group.JPG',
              height: 70,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(width: 10),

          // Blue Club Training & Events button
          // Blue button → Check Race Records
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
                padding: const EdgeInsets.symmetric(vertical: 18),
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

  // -----------------------------
  // BUILD
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // 🟨 FIXED TOP HEADER (original look)
            Container(
              width: double.infinity,
              color: Colors.yellowAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              margin: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/rank_logo.png', height: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'CLUB STANDARDS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔳 SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // 🖼 COVER IMAGE (original behaviour)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/nnbr_cover.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                          width: double.infinity,
                          height: 170,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 📦 INPUT CARD
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 16),
                          ],
                        ),
                        child: _buildInputForm(),
                      ),
                    ),

                    if (_resultMessage != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _resultMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 5),

                    // 🔘 BUTTONS
                    _buildButtons(),

                    const SizedBox(height: 40),
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
