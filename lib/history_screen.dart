import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/club_records_service.dart';
import 'package:runrank/menu/club_records_page.dart';

class RaceRecord {
  final String raceName;
  final String distance;
  final int? finishSeconds;
  final String? timeText;
  final DateTime raceDate;
  final String level;
  final double ageGrade;

  RaceRecord({
    required this.raceName,
    required this.distance,
    required this.finishSeconds,
    required this.timeText,
    required this.raceDate,
    required this.level,
    required this.ageGrade,
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
            race_name,
            distance,
            time_seconds,
            raceDate,
            level,
            age_grade,
            created_at
          ''')
          .eq('user_id', user.id)
          .order('raceDate', ascending: false)
          .order('created_at', ascending: false);

      final List<RaceRecord> allRecords = [];

      for (final row in rows) {
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
            raceName: raceName,
            distance: distance,
            finishSeconds: finishSeconds,
            timeText: timeText,
            raceDate: raceDate,
            level: level,
            ageGrade: ageGrade,
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
            // Show all distances without horizontal scrolling
            isScrollable: false,
            indicatorColor: Colors.yellow,
            labelColor: Colors.yellow,
            unselectedLabelColor: Colors.white70,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: _distances.map((d) => Tab(text: d)).toList(),
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
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                r.distance,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        ],
      ),
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
}
