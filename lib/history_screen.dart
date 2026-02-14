import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/club_records_service.dart';
import 'package:runrank/menu/club_records_page.dart';
import 'calculator_logic.dart';

class RaceRecord {
  final String id;
  final String raceName;
  final String distance;
  final int? finishSeconds;
  final String? timeText;
  final DateTime raceDate;
  final String level;
  final double ageGrade;
  final String gender;
  final int age;

  RaceRecord({
    required this.id,
    required this.raceName,
    required this.distance,
    required this.finishSeconds,
    required this.timeText,
    required this.raceDate,
    required this.level,
    required this.ageGrade,
    required this.gender,
    required this.age,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _distances = const [
    '5K',
    '5M',
    '10K',
    '10M',
    'Half M',
    'Marathon',
    '20M',
    'Ultra',
  ];
  final _clubRecordsService = ClubRecordsService();

  bool _loading = true;
  bool _error = false;

  Map<String, List<RaceRecord>> _byDistance = {};
  Map<String, ClubRecord?> _clubRecords = {};

  @override
  void initState() {
    super.initState();
    _fetchRaceHistory();
  }

  Future<void> _fetchRaceHistory() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    try {
      final rows = await client
          .from('race_results')
          .select('''
            id,
            race_name,
            distance,
            time_seconds,
            raceDate,
            level,
            age_grade,
            gender,
            age,
            created_at
          ''')
          .eq('user_id', user.id)
          .order('raceDate', ascending: false)
          .order('created_at', ascending: false);

      final List<RaceRecord> allRecords = [];

      for (final row in rows) {
        final id = row['id'] as String? ?? '';
        final raceName =
            (row['race_name'] as String?)?.trim().isNotEmpty == true
            ? row['race_name']
            : 'Untitled race';

        final distance = row['distance'] as String? ?? '';
        final finishSeconds = row['time_seconds'] ?? 0;
        final timeText = formatTime(finishSeconds);

        final level = row['level'] as String? ?? 'Unknown';

        final ageGradeRaw = row['age_grade'];
        final ageGrade = ageGradeRaw is num ? ageGradeRaw.toDouble() : 0.0;

        final gender = (row['gender'] as String?) ?? '';
        final age = row['age'] is int ? row['age'] as int : 0;

        DateTime raceDate;
        if (row['raceDate'] != null) {
          raceDate = DateTime.parse(row['raceDate']);
        } else if (row['created_at'] != null) {
          raceDate = DateTime.parse(row['created_at']);
        } else {
          raceDate = DateTime.now();
        }

        allRecords.add(
          RaceRecord(
            id: id,
            raceName: raceName,
            distance: distance,
            finishSeconds: finishSeconds,
            timeText: timeText,
            raceDate: raceDate,
            level: level,
            ageGrade: ageGrade,
            gender: gender,
            age: age,
          ),
        );
      }

      final Map<String, List<RaceRecord>> grouped = {
        for (final d in _distances) d: [],
      };

      for (final r in allRecords) {
        if (grouped.containsKey(r.distance)) {
          grouped[r.distance]!.add(r);
        }
      }

      for (final d in _distances) {
        grouped[d]!.sort((a, b) => b.raceDate.compareTo(a.raceDate));
      }

      if (!mounted) return;
      setState(() {
        _byDistance = grouped;
        _loading = false;
      });

      // Fetch club records for all distances
      _fetchClubRecords();
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _fetchClubRecords() async {
    try {
      for (final distance in _distances) {
        final record = await _clubRecordsService.getClubRecordHolder(distance);
        if (mounted) {
          setState(() {
            _clubRecords[distance] = record;
          });
        }
      }
    } catch (e) {
      print('Error fetching club records: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _distances.length,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Race Records',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          bottom: TabBar(
            // Fixed tabs so all distances are always visible
            isScrollable: false,
            indicatorColor: Colors.yellow,
            labelColor: Colors.yellow,
            unselectedLabelColor: Colors.white70,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            tabs: _distances
                .map(
                  (d) => Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(d, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: ElevatedButton(
          onPressed: _fetchRaceHistory,
          child: const Text('Retry'),
        ),
      );
    }

    return TabBarView(children: _distances.map(_buildDistanceTab).toList());
  }

  Widget _buildDistanceTab(String distance) {
    final records = _byDistance[distance] ?? [];

    return Column(
      children: [
        // Fixed summary card at the top
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildSummaryCard(distance, records),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    'No records yet for $distance.\nSubmit some results to see them here!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRaceHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(records[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // 🟦 ELECTRIC BLUE SUMMARY CARD
  Widget _buildSummaryCard(String distance, List<RaceRecord> records) {
    if (records.isEmpty) return const SizedBox.shrink();

    final isSpecialDistance = distance == '20M' || distance == 'Ultra';

    final bestTime = records.reduce(
      (a, b) =>
          (a.finishSeconds ?? 999999) < (b.finishSeconds ?? 999999) ? a : b,
    );
    final bestAge = records.reduce((a, b) => a.ageGrade >= b.ageGrade ? a : b);
    final mostRecent = records.first;

    // Count standards
    final Map<String, int> standardCounts = {};
    for (final r in records) {
      standardCounts[r.level] = (standardCounts[r.level] ?? 0) + 1;
    }

    final standardsText = standardCounts.entries
        .map((e) => '${e.key} × ${e.value}')
        .join('   •   ');

    final clubRecord = _clubRecords[distance];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A78FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFFD700), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$distance Summary',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),

          // Club Record Holder - prominently displayed
          if (clubRecord != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClubRecordsPage(initialDistance: distance),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CLUB RECORD',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              clubRecord.runnerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        clubRecord.formattedTime,
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
          ],

          _summaryRow(
            Icons.timer,
            'Best time: ${formatTime(bestTime.finishSeconds)}',
          ),
          const SizedBox(height: 6),
          if (isSpecialDistance)
            _summaryRow(
              Icons.leaderboard,
              'Club Standard & Age Grade are not calculated for this distance.',
            )
          else
            _summaryRow(
              Icons.leaderboard,
              'Best age grade: ${bestAge.ageGrade.toStringAsFixed(1)}%',
            ),
          const SizedBox(height: 6),

          _summaryRow(
            Icons.event,
            'Most recent: ${_formatDate(mostRecent.raceDate)}',
          ),
          const SizedBox(height: 8),

          if (!isSpecialDistance && standardsText.isNotEmpty)
            _summaryRow(Icons.workspace_premium, standardsText),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ▶️ INDIVIDUAL RECORD CARD — DARK FLOATING GREY
  Widget _buildRecordCard(RaceRecord r) {
    final timeString = formatTime(r.finishSeconds);
    final ageGradeString = 'Age-Grade: ${r.ageGrade.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF4A78FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showRaceOptions(r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First line: race name, date, distance
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.raceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(r.raceDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.distance,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Second line: time, level, age-grade (age-grade right-aligned)
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.level,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ageGradeString,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRaceOptions(RaceRecord r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text(
                  'Edit race',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editRaceRecord(r);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete race',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteRaceRecord(r);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  // ⏱ Format HH:MM:SS or MM:SS
  String formatTime(int? seconds, {String fallback = '-'}) {
    if (seconds == null) return fallback;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    } else {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }

  String _formatDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _confirmDeleteRaceRecord(RaceRecord r) async {
    final client = Supabase.instance.client;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Delete race?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'Are you sure you want to delete "${r.raceName}" on ${_formatDate(r.raceDate)}?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Delete from race_results
      await client.from('race_results').delete().eq('id', r.id);

      // Also remove any matching club record for this performance
      final user = client.auth.currentUser;
      final timeSeconds = r.finishSeconds;
      if (user != null && timeSeconds != null) {
        await client
            .from('club_records')
            .delete()
            .eq('user_id', user.id)
            .eq('distance', r.distance)
            .eq('time_seconds', timeSeconds);
      }

      await _fetchRaceHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to delete race: $e'),
        ),
      );
    }
  }

  Future<void> _editRaceRecord(RaceRecord r) async {
    final client = Supabase.instance.client;

    final timeController = TextEditingController(
      text: formatTime(r.finishSeconds, fallback: ''),
    );
    final raceNameController = TextEditingController(text: r.raceName);
    DateTime selectedDate = r.raceDate;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D2E),
          title: const Text(
            'Edit race',
            style: TextStyle(color: Color(0xFFFFD700)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: raceNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Race name',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Time (hh:mm:ss or mm:ss)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Race date',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  subtitle: Text(
                    _formatDate(selectedDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFFFFD700),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated != true) return;

    final parsedSeconds = RunCalculator.parseTimeToSeconds(
      timeController.text.trim(),
    );
    if (parsedSeconds == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Invalid time format.'),
        ),
      );
      return;
    }

    try {
      // Re-evaluate level + age grade for standard distances
      String level = r.level;
      double ageGrade = r.ageGrade;
      if (_distances.contains(r.distance) &&
          r.distance != '20M' &&
          r.distance != 'Ultra') {
        final eval = RunCalculator.evaluate(
          gender: r.gender,
          age: r.age,
          distance: r.distance,
          finishSeconds: parsedSeconds,
        );
        level = eval['level'] as String;
        ageGrade = eval['ageGrade'] as double;
      }

      final rawName = raceNameController.text.trim();
      final safeRaceName = rawName.isEmpty ? 'Untitled race' : rawName;

      // Update the underlying race_results row
      await client
          .from('race_results')
          .update({
            'race_name': safeRaceName,
            'time_seconds': parsedSeconds,
            'raceDate': selectedDate.toIso8601String(),
            'level': level,
            'age_grade': ageGrade,
          })
          .eq('id', r.id);

      // Keep any related club_records entry in sync with the edited result
      final user = client.auth.currentUser;
      final oldSeconds = r.finishSeconds;
      if (user != null && oldSeconds != null) {
        final existing = await client
            .from('club_records')
            .select('id')
            .eq('user_id', user.id)
            .eq('distance', r.distance)
            .eq('time_seconds', oldSeconds)
            .maybeSingle();

        if (existing != null && existing['id'] != null) {
          await client
              .from('club_records')
              .update({
                'time_seconds': parsedSeconds,
                'race_name': safeRaceName,
                'race_date': selectedDate.toIso8601String().split('T')[0],
              })
              .eq('id', existing['id'] as String);
        }
      }

      await _fetchRaceHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to update race: $e'),
        ),
      );
    }
  }
}
