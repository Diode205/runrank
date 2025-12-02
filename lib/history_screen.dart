import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _distances = const ['5K', '5M', '10K', '10M', 'Half M', 'Marathon'];

  bool _loading = true;
  bool _error = false;

  // distance → list of records (sorted newest → oldest)
  Map<String, List<RaceRecord>> _byDistance = {};

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
            gender,
            age,
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
            ? row['race_name'] as String
            : 'Untitled race';

        // distance stored as text (your Supabase table uses text)
        final distance = row['distance'] as String? ?? '';

        // Supabase uses "time_seconds"
        final finishSeconds = row['time_seconds'] as int? ?? 0;

        // build user-friendly time format
        final timeText = formatTime(finishSeconds);

        // level is text
        final level = row['level'] as String? ?? 'Unknown';

        // age_grade numeric
        final ageGradeRaw = row['age_grade'];
        final ageGrade = ageGradeRaw is num ? ageGradeRaw.toDouble() : 0.0;

        DateTime raceDate;

        // parse raceDate column
        if (row['raceDate'] != null) {
          raceDate = DateTime.parse(row['raceDate']);
        }
        // if created_at available
        else if (row['created_at'] != null) {
          if (row['created_at'] is String) {
            raceDate = DateTime.parse(row['created_at']);
          } else if (row['created_at'] is DateTime) {
            raceDate = row['created_at'];
          } else {
            raceDate = DateTime.now();
          }
        } else {
          raceDate = DateTime.now();
        }

        // finally add to list
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

      // Group by distance and sort newest → oldest for each
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
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching race history: $e');
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _distances.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Race Records',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Could not load race records.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchRaceHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(children: _distances.map(_buildDistanceTab).toList());
  }

  Widget _buildDistanceTab(String distance) {
    final records = _byDistance[distance] ?? [];

    if (records.isEmpty) {
      return Center(
        child: Text(
          'No records yet for $distance.\nSubmit some results to see them here!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRaceHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length + 1, // +1 for summary card
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryCard(distance, records);
          }
          final record = records[index - 1];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  Widget _buildSummaryCard(String distance, List<RaceRecord> records) {
    if (records.isEmpty) return const SizedBox.shrink();

    // Best time (smallest finishSeconds with non-null)
    final recordsWithTime = records
        .where((r) => r.finishSeconds != null)
        .toList();
    recordsWithTime.sort(
      (a, b) => (a.finishSeconds ?? 0).compareTo(b.finishSeconds ?? 0),
    );
    final bestTime = recordsWithTime.isNotEmpty ? recordsWithTime.first : null;

    // Best age grade
    final bestAge = records.reduce((a, b) => a.ageGrade >= b.ageGrade ? a : b);

    // Most recent (already sorted newest → oldest)
    final mostRecent = records.first;

    // Count standards
    final Map<String, int> standardCounts = {};
    for (final r in records) {
      standardCounts[r.level] = (standardCounts[r.level] ?? 0) + 1;
    }

    final standardsText = standardCounts.entries
        .map((e) => '${e.key} × ${e.value}')
        .join('   •   ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$distance Summary',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (bestTime != null) ...[
            Row(
              children: [
                const Icon(Icons.timer, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Best time: ${formatTime(bestTime.finishSeconds, fallback: bestTime.timeText ?? '-')}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Icon(Icons.leaderboard, size: 18),
              const SizedBox(width: 6),
              Text(
                'Best age grade: ${bestAge.ageGrade.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event, size: 18),
              const SizedBox(width: 6),
              Text(
                'Most recent: ${_formatDate(mostRecent.raceDate)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (standardsText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.workspace_premium, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    standardsText,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordCard(RaceRecord r) {
    final timeString = formatTime(r.finishSeconds, fallback: r.timeText ?? '-');
    final ageGradeString = '${r.ageGrade.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Race name
          Text(
            r.raceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          // Date + distance line
          Row(
            children: [
              const Icon(Icons.event, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                _formatDate(r.raceDate),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.straighten, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                r.distance,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Time + level + age-grade
          Row(
            children: [
              const Icon(Icons.timer, size: 18),
              const SizedBox(width: 4),
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Chip(
                label: Text(
                  r.level,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.yellow.shade200,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const Spacer(),
              Text(
                ageGradeString,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
      return '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
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
