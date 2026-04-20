import 'package:flutter/material.dart';
import 'package:runrank/main.dart' show routeObserver;
import 'package:runrank/services/runners_awards_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RunnersOfTheYearPage extends StatefulWidget {
  const RunnersOfTheYearPage({super.key});

  @override
  State<RunnersOfTheYearPage> createState() => _RunnersOfTheYearPageState();
}

class _RunnersOfTheYearPageState extends State<RunnersOfTheYearPage>
    with RouteAware {
  static const yellow = Color(0xFFFFD300);
  static const blue = Color(0xFF0057B7);
  static const nrrRed = Color(0xFFD32F2F);

  final _service = RunnersAwardsService();
  bool _isAdmin = false;
  final Map<String, List<AwardWinnerRow>> _winnersByAward = {};
  bool _loading = true;
  List<String> _memberNames = [];
  String? _clubName;

  bool get _isNrrClub {
    final lower = (_clubName ?? '').trim().toLowerCase();
    return lower == 'nrr' || lower.contains('norwich road runners');
  }

  List<Color> get _appBarGradient => _isNrrClub
      ? const [Color(0xFF000000), Color(0xFF6E1118)]
      : UserService.clubBrandGradient(_clubName);

  List<Color> get _pageBackgroundGradient => _isNrrClub
      ? const [Color(0xFF050505), Color(0xFF19090C), Color(0xFF000000)]
      : UserService.clubBrandGradient(
          _clubName,
        ).map((c) => c.withValues(alpha: 0.1)).toList();

  String get _heroImageAsset =>
      _isNrrClub ? 'assets/images/nrraward.png' : 'assets/images/awards.png';

  List<Color> get _heroRibbonGradient => _isNrrClub
      ? const [Color(0xFFB71C1C), Color(0xFF111111)]
      : const [blue, yellow];

  List<Color> get _heroShadeGradient => _isNrrClub
      ? const [Color(0x33000000), Color(0x99000000), Color(0xEE000000)]
      : const [Colors.transparent, Colors.black54];

  Color get _pageSurfaceColor =>
      _isNrrClub ? const Color(0xFF101010) : const Color(0xFF0F111A);

  Color get _pageBorderColor => _isNrrClub ? const Color(0x66D32F2F) : yellow;

  Color get _titleAccentColor => Colors.white;

  Color get _headerLabelColor =>
      _isNrrClub ? Colors.white70 : const Color.fromRGBO(30, 145, 233, 0.702);

  Color get _addButtonColor => _isNrrClub ? Colors.white : yellow;

  Color get _tabStripColor =>
      _isNrrClub ? const Color(0xFF050505) : const Color(0xFF0F111A);

  Color get _tabSelectedColor => _isNrrClub ? nrrRed : yellow;

  Color get _tabUnselectedColor => _isNrrClub ? Colors.white30 : Colors.white24;

  final List<Map<String, String>> _awards = const [
    {'key': 'short_performance', 'title': '🏃‍♀️Short Distance🏃‍➡️'},
    {'key': 'mid_performance', 'title': '🏃‍♀️Mid-Distance🏃‍➡️'},
    {'key': 'long_performance', 'title': '🏃‍♀️Long Distance🏃‍➡️'},
    {'key': 'ultra_performance', 'title': '🏃‍♀️Ultra Distance🏃‍➡️'},
    {'key': 'overall_performance', 'title': '🏃‍♀️Overall Performance🏃‍➡️'},
    {'key': 'newcomer', 'title': '🏃‍♀️Newcomer Of The Year🏃‍➡️'},
    {'key': 'most_improved', 'title': '🏃‍♀️Most Improved Runner🏃‍➡️'},
    {'key': 'runner_of_the_year', 'title': '🏃‍♀️Runner Of The Year🏃‍➡️'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _winnersByAward.clear();
      _memberNames = [];
    });
    try {
      final isAdmin = await UserService.isAdmin();
      final clubName = await UserService.currentClubName();
      final canonicalClub = RunnersAwardsService.canonicalClubName(clubName);
      final Map<String, List<AwardWinnerRow>> map = {};
      if (canonicalClub.isNotEmpty) {
        for (final a in _awards) {
          final key = a['key']!;
          map[key] = await _service.fetchWinners(key, clubName: canonicalClub);
        }
      }

      // Fetch member names for typeahead, scoped to the current club.
      final membersRows = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, club')
          .order('full_name');
      final names = (membersRows as List)
          .where((r) {
            final profileClub = RunnersAwardsService.canonicalClubName(
              r['club'] as String?,
            );
            return profileClub.isNotEmpty && profileClub == canonicalClub;
          })
          .map((r) => (r['full_name'] as String?)?.trim())
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
        _clubName = clubName;
        _winnersByAward.clear();
        _winnersByAward.addAll(map);
        _loading = false;
        _memberNames = names;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addWinnerDialogForAward({
    required String awardKey,
    required String title,
    required bool isNewcomer,
  }) async {
    final yearController = TextEditingController();
    final femaleController = TextEditingController();
    final maleController = TextEditingController();
    final newcomerController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Add Winner — $title',
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
                  if (_memberNames.isNotEmpty)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue tv) {
                        final q = tv.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return _memberNames.where(
                          (n) => n.toLowerCase().contains(q),
                        );
                      },
                      onSelected: (sel) {
                        femaleController.text = sel;
                      },
                      fieldViewBuilder:
                          (ctx2, controller2, focusNode, onFieldSubmitted) {
                            controller2.text = femaleController.text;
                            controller2.addListener(() {
                              femaleController.text = controller2.text;
                            });
                            return TextField(
                              controller: controller2,
                              focusNode: focusNode,
                              onSubmitted: (_) => onFieldSubmitted(),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Female Winner (Type Or Pick)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                    ),
                  if (_memberNames.isEmpty)
                    TextField(
                      controller: femaleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Female Winner',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (_memberNames.isNotEmpty)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue tv) {
                        final q = tv.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return _memberNames.where(
                          (n) => n.toLowerCase().contains(q),
                        );
                      },
                      onSelected: (sel) {
                        maleController.text = sel;
                      },
                      fieldViewBuilder:
                          (ctx2, controller2, focusNode, onFieldSubmitted) {
                            controller2.text = maleController.text;
                            controller2.addListener(() {
                              maleController.text = controller2.text;
                            });
                            return TextField(
                              controller: controller2,
                              focusNode: focusNode,
                              onSubmitted: (_) => onFieldSubmitted(),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Male Winner (Type Or Pick)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                    ),
                  if (_memberNames.isEmpty)
                    TextField(
                      controller: maleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Male Winner',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                ] else ...[
                  if (_memberNames.isNotEmpty)
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue tv) {
                        final q = tv.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return _memberNames.where(
                          (n) => n.toLowerCase().contains(q),
                        );
                      },
                      onSelected: (sel) {
                        newcomerController.text = sel;
                      },
                      fieldViewBuilder:
                          (ctx2, controller2, focusNode, onFieldSubmitted) {
                            controller2.text = newcomerController.text;
                            controller2.addListener(() {
                              newcomerController.text = controller2.text;
                            });
                            return TextField(
                              controller: controller2,
                              focusNode: focusNode,
                              onSubmitted: (_) => onFieldSubmitted(),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Winner Name (Type Or Pick)',
                                labelStyle: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                    ),
                  if (_memberNames.isEmpty)
                    TextField(
                      controller: newcomerController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Winner Name',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final year = int.tryParse(yearController.text.trim());
    final clubName = _clubName;
    if (year == null || clubName == null || clubName.trim().isEmpty) return;
    await _service.addWinner(
      awardKey: awardKey,
      clubName: clubName,
      year: year,
      femaleName: isNewcomer
          ? (newcomerController.text.trim().isEmpty
                ? null
                : newcomerController.text.trim())
          : (femaleController.text.trim().isEmpty
                ? null
                : femaleController.text.trim()),
      maleName: isNewcomer
          ? null
          : (maleController.text.trim().isEmpty
                ? null
                : maleController.text.trim()),
    );
    await _load();
  }

  Future<void> _manageAwardEntries(
    String awardKey,
    List<AwardWinnerRow> rows,
    bool isNewcomer,
  ) async {
    if (!_isAdmin) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: const Text(
          'Manage Entries',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: rows.isEmpty
              ? const Text(
                  'No entries yet',
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    final winner = isNewcomer
                        ? (r.femaleName ?? r.maleName ?? '—')
                        : '${r.femaleName ?? '—'}  |  ${r.maleName ?? '—'}';
                    return ListTile(
                      title: Text(
                        '${r.year} — $winner',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: Colors.white70),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _editWinnerDialog(awardKey, r, isNewcomer);
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF0F111A),
                                  title: const Text(
                                    'Delete Entry',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    'Delete ${r.year} entry?',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final clubName = _clubName;
                                if (clubName == null ||
                                    clubName.trim().isEmpty) {
                                  return;
                                }
                                await _service.deleteWinner(
                                  awardKey: awardKey,
                                  clubName: clubName,
                                  year: r.year,
                                );
                                await _load();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editWinnerDialog(
    String awardKey,
    AwardWinnerRow row,
    bool isNewcomer,
  ) async {
    final femaleController = TextEditingController(text: row.femaleName ?? '');
    final maleController = TextEditingController(text: row.maleName ?? '');
    final newcomerController = TextEditingController(
      text: row.femaleName ?? row.maleName ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit ${row.year}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNewcomer) ...[
                if (_memberNames.isNotEmpty)
                  Autocomplete<String>(
                    optionsBuilder: (tv) {
                      final q = tv.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _memberNames.where(
                        (n) => n.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (sel) => newcomerController.text = sel,
                    fieldViewBuilder:
                        (ctx2, controller2, focusNode, onFieldSubmitted) {
                          controller2.text = newcomerController.text;
                          controller2.addListener(() {
                            newcomerController.text = controller2.text;
                          });
                          return TextField(
                            controller: controller2,
                            focusNode: focusNode,
                            onSubmitted: (_) => onFieldSubmitted(),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Winner Name (Type Or Pick)',
                            ),
                          );
                        },
                  ),
                if (_memberNames.isEmpty)
                  TextField(
                    controller: newcomerController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Winner Name'),
                  ),
              ] else ...[
                if (_memberNames.isNotEmpty)
                  Autocomplete<String>(
                    optionsBuilder: (tv) {
                      final q = tv.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _memberNames.where(
                        (n) => n.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (sel) => femaleController.text = sel,
                    fieldViewBuilder:
                        (ctx2, controller2, focusNode, onFieldSubmitted) {
                          controller2.text = femaleController.text;
                          controller2.addListener(() {
                            femaleController.text = controller2.text;
                          });
                          return TextField(
                            controller: controller2,
                            focusNode: focusNode,
                            onSubmitted: (_) => onFieldSubmitted(),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Female Winner (Type Or Pick)',
                            ),
                          );
                        },
                  ),
                if (_memberNames.isEmpty)
                  TextField(
                    controller: femaleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Female Winner',
                    ),
                  ),
                const SizedBox(height: 8),
                if (_memberNames.isNotEmpty)
                  Autocomplete<String>(
                    optionsBuilder: (tv) {
                      final q = tv.text.trim().toLowerCase();
                      if (q.isEmpty) return const Iterable<String>.empty();
                      return _memberNames.where(
                        (n) => n.toLowerCase().contains(q),
                      );
                    },
                    onSelected: (sel) => maleController.text = sel,
                    fieldViewBuilder:
                        (ctx2, controller2, focusNode, onFieldSubmitted) {
                          controller2.text = maleController.text;
                          controller2.addListener(() {
                            maleController.text = controller2.text;
                          });
                          return TextField(
                            controller: controller2,
                            focusNode: focusNode,
                            onSubmitted: (_) => onFieldSubmitted(),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Male Winner (Type Or Pick)',
                            ),
                          );
                        },
                  ),
                if (_memberNames.isEmpty)
                  TextField(
                    controller: maleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Male Winner'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final clubName = _clubName;
    if (clubName == null || clubName.trim().isEmpty) return;
    await _service.updateWinner(
      awardKey: awardKey,
      clubName: clubName,
      year: row.year,
      femaleName: isNewcomer
          ? (newcomerController.text.trim().isEmpty
                ? null
                : newcomerController.text.trim())
          : (femaleController.text.trim().isEmpty
                ? null
                : femaleController.text.trim()),
      maleName: isNewcomer
          ? null
          : (maleController.text.trim().isEmpty
                ? null
                : maleController.text.trim()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _awards.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Runners Of The Year'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _appBarGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        floatingActionButton: null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _pageBackgroundGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Header image (use full image, slightly faded)
                    SizedBox(
                      height: 210,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: (_isNrrClub ? nrrRed : blue).withValues(
                              alpha: _isNrrClub ? 0.10 : 0.06,
                            ),
                          ),
                          Opacity(
                            opacity: _isNrrClub ? 0.82 : 0.9,
                            child: Image.asset(
                              _heroImageAsset,
                              fit: BoxFit.cover,
                              alignment: _isNrrClub
                                  ? Alignment.center
                                  : Alignment.topCenter,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _heroShadeGradient,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          if (_isNrrClub)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.28),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _heroRibbonGradient,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "🏆The Winners' List🏆",
                                  style: TextStyle(
                                    color: _isNrrClub
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tight, even spacing around dots indicator
                    const SizedBox(height: 2),
                    Container(
                      color: _tabStripColor,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Builder(
                        builder: (ctx) => TabPageSelector(
                          selectedColor: _tabSelectedColor,
                          color: _tabUnselectedColor,
                          controller: DefaultTabController.of(ctx),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Swipeable pages
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final a in _awards)
                            Builder(
                              builder: (ctx) {
                                final rows =
                                    _winnersByAward[a['key']!] ?? const [];
                                final isNewcomer = a['key'] == 'newcomer';
                                return _awardPage(
                                  awardKey: a['key']!,
                                  title: a['title']!,
                                  rows: rows,
                                  isNewcomer: isNewcomer,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _awardPage({
    required String awardKey,
    required String title,
    required List<AwardWinnerRow> rows,
    required bool isNewcomer,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Card(
        color: _pageSurfaceColor,
        elevation: 0,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _pageBorderColor, width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _isNrrClub
                  ? const [Color(0xFF181818), Color(0xFF080808)]
                  : const [Color(0xFF141722), Color(0xFF0F111A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isNrrClub ? 0.28 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: Column(
                key: ValueKey<String>(awardKey),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _titleAccentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_isAdmin) ...[
                          Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.redAccent,
                              tooltip: 'Manage entries',
                              onPressed: () => _manageAwardEntries(
                                awardKey,
                                rows,
                                isNewcomer,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: _addButtonColor,
                              tooltip: 'Add winner',
                              onPressed: () => _addWinnerDialogForAward(
                                awardKey: awardKey,
                                title: title,
                                isNewcomer: isNewcomer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10),
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
        ),
      ),
    );
  }

  Widget _columnsHeader({required bool isNewcomer}) {
    final style = TextStyle(
      color: _headerLabelColor,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        if (!isNewcomer) ...[
          Expanded(
            child: Text('Female', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('Year', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('Male', style: style, textAlign: TextAlign.center),
          ),
        ] else ...[
          Expanded(
            child: Text('Year', style: style, textAlign: TextAlign.center),
          ),
          Expanded(
            child: Text('Winner', style: style, textAlign: TextAlign.center),
          ),
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
            textAlign: TextAlign.center,
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
            textAlign: TextAlign.center,
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
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            winner,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
