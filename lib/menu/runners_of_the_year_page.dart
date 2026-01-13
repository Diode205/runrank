import 'package:flutter/material.dart';
import 'package:runrank/services/runners_awards_service.dart';
import 'package:runrank/services/user_service.dart';

class RunnersOfTheYearPage extends StatefulWidget {
  const RunnersOfTheYearPage({super.key});

  @override
  State<RunnersOfTheYearPage> createState() => _RunnersOfTheYearPageState();
}

class _RunnersOfTheYearPageState extends State<RunnersOfTheYearPage> {
  static const yellow = Color(0xFFFFD300);
  static const blue = Color(0xFF0057B7);

  final _service = RunnersAwardsService();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isAdmin = false;
  final Map<String, List<AwardWinnerRow>> _winnersByAward = {};
  bool _loading = true;

  final List<Map<String, String>> _awards = const [
    {
      'key': 'short_performance',
      'title': 'Short Distance Performance Of The Year',
    },
    {
      'key': 'mid_performance',
      'title': 'Mid-Distance Performance Of The Year',
    },
    {
      'key': 'long_performance',
      'title': 'Long Distance Performance Of The Year',
    },
    {
      'key': 'ultra_performance',
      'title': 'Ultra Distance Performance Of The Year',
    },
    {
      'key': 'overall_performance',
      'title': 'Overall Performance Of The Year',
    },
    {
      'key': 'newcomer',
      'title': 'Newcomer Of The Year',
    },
    {
      'key': 'most_improved',
      'title': 'Most Improved Runner',
    },
    {
      'key': 'runner_of_the_year',
      'title': 'Runner Of The Year',
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final isAdmin = await UserService.isAdmin();
      final Map<String, List<AwardWinnerRow>> map = {};
      for (final a in _awards) {
        final key = a['key']!;
        map[key] = await _service.fetchWinners(key);
      }
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _winnersByAward.clear();
        _winnersByAward.addAll(map);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _jumpToPage(int index) {
    setState(() => _currentPage = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _addWinnerDialog() async {
    final award = _awards[_currentPage];
    final isNewcomer = award['key'] == 'newcomer';
    final yearController = TextEditingController();
    final femaleController = TextEditingController();
    final maleController = TextEditingController();
    String newcomerGender = 'Female';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Add Winner — ${award['title']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                if (!isNewcomer) ...[
                  TextField(
                    controller: femaleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Female Winner',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Male Winner',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Text('Gender:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: newcomerGender,
                        dropdownColor: const Color(0xFF0F111A),
                        items: const [
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                        ],
                        onChanged: (v) => setState(() => newcomerGender = v ?? 'Female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newcomerGender == 'Female' ? femaleController : maleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Winner Name (${newcomerGender})',
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final year = int.tryParse(yearController.text.trim());
    if (year == null) return;
    await _service.addWinner(
      awardKey: award['key']!,
      year: year,
      femaleName: femaleController.text.trim().isEmpty ? null : femaleController.text.trim(),
      maleName: maleController.text.trim().isEmpty ? null : maleController.text.trim(),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Runners Of The Year'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x4DFFD300), Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              backgroundColor: yellow,
              foregroundColor: Colors.black,
              onPressed: _addWinnerDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header image
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/awards.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black54],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'The Winners\' List',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _pageIndicator(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs as chips
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemBuilder: (ctx, i) {
                      final selected = i == _currentPage;
                      return ChoiceChip(
                        label: Text(_awards[i]['title']!),
                        selected: selected,
                        selectedColor: yellow,
                        backgroundColor: blue.withOpacity(0.12),
                        labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                        side: BorderSide(color: selected ? yellow : blue.withOpacity(0.4)),
                        onSelected: (_) => _jumpToPage(i),
                      );
                    },
                    separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                    itemCount: _awards.length,
                  ),
                ),
                const SizedBox(height: 8),
                // Swipeable pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _awards.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (ctx, i) {
                      final a = _awards[i];
                      final rows = _winnersByAward[a['key']!] ?? const [];
                      final isNewcomer = a['key'] == 'newcomer';
                      return _awardPage(a['title']!, rows, isNewcomer: isNewcomer);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pageIndicator() {
    return Row(
      children: [
        for (int i = 0; i < _awards.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _currentPage ? 14 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _currentPage ? yellow : Colors.white24,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
      ],
    );
  }

  Widget _awardPage(String title, List<AwardWinnerRow> rows, {required bool isNewcomer}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: const Color(0xFF0F111A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: yellow, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: yellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _columnsHeader(isNewcomer: isNewcomer),
              const Divider(color: Colors.white12),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          'No winners recorded yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (ctx, i) {
                          final r = rows[i];
                          return isNewcomer
                              ? _rowNewcomer(r)
                              : _rowStandard(r);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columnsHeader({required bool isNewcomer}) {
    final style = const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600);
    return Row(
      children: [
        if (!isNewcomer) ...[
          Expanded(child: Text('Female', style: style)),
          Expanded(child: Text('Year', style: style, textAlign: TextAlign.center)),
          Expanded(child: Text('Male', style: style, textAlign: TextAlign.right)),
        ] else ...[
          Expanded(child: Text('Year', style: style)),
          Expanded(child: Text('Winner', style: style, textAlign: TextAlign.right)),
        ],
      ],
    );
  }

  Widget _rowStandard(AwardWinnerRow r) {
    return Row(
      children: [
        Expanded(
          child: Text(
            r.femaleName ?? '—',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: Text(
            r.year.toString(),
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            r.maleName ?? '—',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _rowNewcomer(AwardWinnerRow r) {
    final winner = r.femaleName ?? r.maleName ?? '—';
    return Row(
      children: [
        Expanded(
          child: Text(
            r.year.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: Text(
            winner,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
