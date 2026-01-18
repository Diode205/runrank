import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/user_service.dart';

class HandicapSeriesPage extends StatefulWidget {
  const HandicapSeriesPage({super.key});

  @override
  State<HandicapSeriesPage> createState() => _HandicapSeriesPageState();
}

class _HandicapSeriesPageState extends State<HandicapSeriesPage> {
  bool _isAdmin = false;

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
  }

  Future<void> _load() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
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
    if (ok == true) setState(() => r.date = controller.text.trim());
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
    if (ok == true) setState(() => r.venue = controller.text.trim());
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _hero(),
          const SizedBox(height: 12),
          _seriesInfo(),
          const SizedBox(height: 14),
          ..._races.map((r) => _raceCard(r)).toList(),
        ],
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
