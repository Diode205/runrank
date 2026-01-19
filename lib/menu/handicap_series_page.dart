import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HandicapSeriesPage extends StatefulWidget {
  const HandicapSeriesPage({super.key});

  @override
  State<HandicapSeriesPage> createState() => _HandicapSeriesPageState();
}

class _HandicapSeriesPageState extends State<HandicapSeriesPage> {
  bool _isAdmin = false;
  final Map<String, List<String>> _top3 =
      {}; // raceId -> [gold, silver, bronze]

  final List<_HandicapRace> _races = [
    _HandicapRace(id: 'h1', title: 'Handicap Race 1', date: '', venue: ''),
    _HandicapRace(id: 'h2', title: 'Handicap Race 2', date: '', venue: ''),
    _HandicapRace(id: 'h3', title: 'Handicap Race 3', date: '', venue: ''),
    _HandicapRace(id: 'h4', title: 'Handicap Race 4', date: '', venue: ''),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFromSupabase();
  }

  Future<void> _load() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
  }

  Future<void> _loadFromSupabase() async {
    try {
      final rows = await Supabase.instance.client
          .from('handicap_top3')
          .select('race_id, date_label, venue, gold, silver, bronze');
      for (final r in rows) {
        final id = (r['race_id'] as String?) ?? '';
        if (id.isEmpty) continue;
        final dateLabel = (r['date_label'] as String?)?.trim();
        final venue = (r['venue'] as String?)?.trim();
        for (final hr in _races) {
          if (hr.id == id) {
            if (dateLabel != null && dateLabel.isNotEmpty) hr.date = dateLabel;
            if (venue != null && venue.isNotEmpty) hr.venue = venue;
            break;
          }
        }
        final gold = ((r['gold'] as String?) ?? '').trim();
        final silver = ((r['silver'] as String?) ?? '').trim();
        final bronze = ((r['bronze'] as String?) ?? '').trim();
        final winners = [
          gold,
          silver,
          bronze,
        ].where((s) => s.isNotEmpty).toList(growable: false);
        if (winners.isNotEmpty) _top3[id] = winners;
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Ignore read failures; page still renders with placeholders
    }
  }

  Future<void> _editDate(_HandicapRace r) async {
    final controller = TextEditingController(text: r.date);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit date — ${r.title}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'e.g. 25 May 2026'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => r.date = controller.text.trim());
      _saveRemote(r);
    }
  }

  Future<void> _editVenue(_HandicapRace r) async {
    final controller = TextEditingController(text: r.venue);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Edit venue — ${r.title}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Venue name/address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => r.venue = controller.text.trim());
      _saveRemote(r);
    }
  }

  Future<void> _saveRemote(_HandicapRace r) async {
    try {
      await Supabase.instance.client.from('handicap_top3').upsert({
        'race_id': r.id,
        'date_label': r.date.isNotEmpty ? r.date : null,
        'venue': r.venue.isNotEmpty ? r.venue : null,
      });
    } catch (_) {}
  }

  Future<void> _openSeriesSite() async {
    final uri = Uri.parse(
      'https://www.northnorfolkbeachrunners.com/club-handicap-series',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Club Handicap Series',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFFD700),
        backgroundColor: Colors.black,
        onRefresh: () async {
          await _loadFromSupabase();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 12),
            _seriesInfo(),
            const SizedBox(height: 14),
            ..._races.map((r) => _raceCard(r)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.asset(
            'assets/images/handicappic.png',
            height: 170,
            width: double.infinity,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.15),
            colorBlendMode: BlendMode.darken,
          ),
          Container(
            height: 170,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x800057B7), Color(0x80FFD300)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                'NNBR Handicap Series',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seriesInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A3A), Color(0xFF0D2F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1E406A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About The Series',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Handicap races level the playing field across runner abilities. Points are awarded across events and prizes at the end of the series.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openSeriesSite,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Visit series page for full details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF56D3FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _raceCard(_HandicapRace r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF141A24), Color(0xFF0D0F18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1F2A3A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  (r.date.trim().isEmpty || r.date.toLowerCase() == 'tbd')
                      ? 'Date'
                      : r.date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isAdmin)
                IconButton(
                  tooltip: 'Edit date',
                  onPressed: () => _editDate(r),
                  icon: const Icon(
                    Icons.edit_calendar,
                    color: Color(0xFFFFD700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  (r.venue.trim().isEmpty || r.venue.toLowerCase() == 'tbd')
                      ? 'Venue'
                      : r.venue,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (_isAdmin)
                IconButton(
                  tooltip: 'Edit venue',
                  onPressed: () => _editVenue(r),
                  icon: const Icon(
                    Icons.edit_location_alt,
                    color: Color(0xFFFFD700),
                  ),
                ),
            ],
          ),
          // Top 3 display (visible to all if present in Supabase)
          if ((_top3[r.id] ?? const []).isNotEmpty) ...[
            const SizedBox(height: 10),
            _top3Box(_top3[r.id]!),
          ],
        ],
      ),
    );
  }

  Widget _top3Box(List<String> winners) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Top 3 Finishers',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (winners.isNotEmpty)
            _medalRow('Gold', winners.elementAt(0), const Color(0xFFFFD700)),
          if (winners.length > 1)
            _medalRow('Silver', winners.elementAt(1), const Color(0xFFC0C0C0)),
          if (winners.length > 2)
            _medalRow('Bronze', winners.elementAt(2), const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _medalRow(String label, String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandicapRace {
  final String id;
  final String title;
  String date;
  String venue;
  _HandicapRace({
    required this.id,
    required this.title,
    required this.date,
    required this.venue,
  });
}
