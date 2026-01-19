import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RacesEacclPage extends StatefulWidget {
  const RacesEacclPage({super.key});

  @override
  State<RacesEacclPage> createState() => _RacesEacclPageState();
}

class _RacesEacclPageState extends State<RacesEacclPage> {
  bool _isAdmin = false;

  final Map<String, String> _raceDates = {
    'holt': '25 May 2026',
    'worstead': '25 July 2026',
    'chase': '2 Nov 2026',
  };

  final List<_HandicapRace> _handicapRaces = [
    _HandicapRace(id: 'h1', title: '5 Km Race', date: '', venue: ''),
    _HandicapRace(id: 'h2', title: '8.8 Mile Beach Run', date: '', venue: ''),
    _HandicapRace(id: 'h3', title: '10 Mile Race', date: '', venue: ''),
    _HandicapRace(id: 'h4', title: '5 Mile Race', date: '', venue: ''),
    _HandicapRace(id: 'h5', title: '10 Km Race', date: '', venue: ''),
    _HandicapRace(id: 'h6', title: '7 Mile', date: '', venue: ''),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _loadSavedRaceData();
    _loadSavedHandicapData();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedRaceData() async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    for (final key in ['holt', 'worstead', 'chase']) {
      final saved = prefs.getString('signature_date_' + key);
      if (saved != null && saved.isNotEmpty) {
        _raceDates[key] = saved;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _saveSignatureDate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signature_date_' + key, _raceDates[key] ?? '');
  }

  Future<void> _loadSavedHandicapData() async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;
    for (final r in _handicapRaces) {
      final d = prefs.getString('handicap_' + r.id + '_date');
      final v = prefs.getString('handicap_' + r.id + '_venue');
      if (d != null) {
        r.date = d;
        changed = true;
      }
      if (v != null) {
        r.venue = v;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _saveHandicap(_HandicapRace r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('handicap_' + r.id + '_date', r.date);
    await prefs.setString('handicap_' + r.id + '_venue', r.venue);
  }

  // Save to Supabase so non-admin users see the admin-entered details
  Future<void> _saveHandicapRemote(_HandicapRace r) async {
    try {
      await Supabase.instance.client.from('handicap_top3').upsert({
        'race_id': r.id,
        'date_label': r.date.isNotEmpty ? r.date : null,
        'venue': r.venue.isNotEmpty ? r.venue : null,
      });
    } catch (_) {
      // Ignore remote write errors; local persistence still applies
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  void _editDate(String key, String title) {
    final controller = TextEditingController(text: _raceDates[key]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Update date for $title',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'e.g. 25 May 2026',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _raceDates[key] = controller.text.trim());
              _saveSignatureDate(key);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _pickDateForRace(String key) {
    final now = DateTime.now();
    final current = _parseDateLabel(_raceDates[key] ?? '') ?? now;
    showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    ).then((picked) {
      if (picked != null) {
        setState(() => _raceDates[key] = _formatDate(picked));
        _saveSignatureDate(key);
      }
    });
  }

  void _editHandicapDate(_HandicapRace r) {
    final now = DateTime.now();
    showDatePicker(
      context: context,
      initialDate: _parseDateLabel(r.date) ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    ).then((picked) {
      if (picked != null) {
        setState(() => r.date = _formatDate(picked));
        _saveHandicap(r);
        _saveHandicapRemote(r);
      }
    });
  }

  void _editHandicapVenue(_HandicapRace r) {
    final controller = TextEditingController(text: r.venue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F111A),
        title: Text(
          'Update venue — ${r.title}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Venue name/address',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => r.venue = controller.text.trim());
              _saveHandicap(r);
              _saveHandicapRemote(r);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

  DateTime? _parseDateLabel(String s) {
    final text = s.trim();
    if (text.isEmpty || text.toLowerCase() == 'tbd') return null;
    final parts = text.split(' ');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final monthStr = parts[1].toLowerCase();
    final year = int.tryParse(parts[2]);
    if (day == null || year == null) return null;
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    final month = months[monthStr];
    if (month == null) return null;
    return DateTime(year, month, day);
  }

  void _createEventFrom(_HandicapRace r) {
    String? distance;
    final t = r.title.toLowerCase();
    if (t.contains('5k')) distance = '5K';
    if (t.contains('10k')) distance = '10K';
    if (t.contains('10 mile') || t.contains('10m')) distance = '10M';
    if (t.contains('5 mile') || t.contains('5m')) distance = '5M';
    if (t.contains('7 mile') || t.contains('7m')) distance = '7M';
    if (t.contains('beach')) distance = 'Beach Run';

    final initialDate = _parseDateLabel(r.date);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Handicap Series',
          initialHandicapDistance: distance,
          initialDate: initialDate,
          initialVenue: r.venue.trim().isEmpty ? null : r.venue.trim(),
        ),
      ),
    );
  }

  void _createSignatureEvent(_RaceInfo info) {
    final initialDate = _parseDateLabel(info.date);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Race',
          initialDate: initialDate,
          initialVenue: info.location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Signature and Handicap Races',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(children: [Expanded(child: _raceCards())]),
    );
  }

  Widget _raceCards() {
    final races = [
      _RaceInfo(
        keyId: 'holt',
        title: 'Holt 10K',
        overview:
            'Fast, mostly flat mix of quiet roads and trail. Perfect for personal bests.',
        location: "Gresham's School, Holt",
        date: _raceDates['holt']!,
        registration: 'Registration from 08:45',
        raceStart: 'Race start 10:00',
        specialNote: 'Part of Sportlink Grand Prix Series',
        specialNoteUrl: 'https://www.sportlinkgp.run/',
        ticketsUrl: 'https://totalracetiming.co.uk/race/596',
        resultsUrl: 'https://totalracetiming.co.uk/result',
        mapUrl: 'https://goo.gl/maps/7hhzQwfBWNtfySbU6',
        facilities:
            'Free parking (NR25 6EA) · Toilets · Prizes (age categories & teams) · First aid · Cake & refreshments · No bag drop/changing',
      ),
      _RaceInfo(
        keyId: 'worstead',
        title: 'Worstead 5 Miles',
        overview:
            'Summer evening race with festival vibes. Undulating rural roads on the Worstead Festival weekend.',
        location: 'Worstead village square',
        date: _raceDates['worstead']!,
        registration: 'Numbers posted in advance',
        raceStart: 'Race start 19:00',
        specialNote: 'Part of Sportlink Grand Prix Series',
        specialNoteUrl: 'https://www.sportlinkgp.run/',
        ticketsUrl: 'https://totalracetiming.co.uk/race/594',
        resultsUrl: 'https://totalracetiming.co.uk/result',
        mapUrl: 'https://goo.gl/maps/bAfXx4dkocZTWD8X6',
        facilities:
            'Parking (festival car park, NR28 9SD) · Toilets (limited) · No changing facilities · Prizes (age group trophies) · First aid',
      ),
      _RaceInfo(
        keyId: 'chase',
        title: 'Chase The Train',
        overview:
            'Highly popular 8.9 miles scenic flat trail alongside the train tracks. Special train back for all runners.',
        location: 'Aylsham → Wroxham (Bure Valley Railway)',
        date: _raceDates['chase']!,
        registration: 'Briefing 10:15',
        raceStart: 'Race start 10:30',
        specialNote: null,
        specialNoteUrl: null,
        ticketsUrl: 'https://entries.sublimetiming.com/race/32',
        resultsUrl: 'https://www.sublimetiming.com/results',
        mapUrl: 'https://goo.gl/maps/mKE2PoEV1gM6yZC79',
        facilities:
            'Bag drop via special train · Parking (limited at start) · Toilets (start & finish) · First aid · Very limited changing · No prizes/refreshments included',
      ),
    ];

    final pages = <Widget>[
      for (final r in races)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _RaceCard(
            info: r,
            isAdmin: _isAdmin,
            onEditDate: () => _editDate(r.keyId, r.title),
            onPickDate: () => _pickDateForRace(r.keyId),
            onCreateEvent: () => _createSignatureEvent(r),
            onOpen: _openLink,
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _HandicapCard(
          races: _handicapRaces,
          isAdmin: _isAdmin,
          onEditDate: _editHandicapDate,
          onEditVenue: _editHandicapVenue,
          onCreateEvent: _createEventFrom,
        ),
      ),
    ];

    return PageView.builder(
      itemCount: pages.length,
      controller: PageController(viewportFraction: 0.92),
      itemBuilder: (context, index) => pages[index],
    );
  }
}

class _RaceInfo {
  final String keyId;
  final String title;
  final String overview;
  final String location;
  final String date;
  final String registration;
  final String raceStart;
  final String? specialNote;
  final String? specialNoteUrl;
  final String ticketsUrl;
  final String resultsUrl;
  final String mapUrl;
  final String facilities;

  _RaceInfo({
    required this.keyId,
    required this.title,
    required this.overview,
    required this.location,
    required this.date,
    required this.registration,
    required this.raceStart,
    this.specialNote,
    this.specialNoteUrl,
    required this.ticketsUrl,
    required this.resultsUrl,
    required this.mapUrl,
    required this.facilities,
  });
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

class _HandicapCard extends StatefulWidget {
  final List<_HandicapRace> races;
  final bool isAdmin;
  final void Function(_HandicapRace) onEditDate;
  final void Function(_HandicapRace) onEditVenue;
  final void Function(_HandicapRace) onCreateEvent;

  const _HandicapCard({
    required this.races,
    required this.isAdmin,
    required this.onEditDate,
    required this.onEditVenue,
    required this.onCreateEvent,
  });

  @override
  State<_HandicapCard> createState() => _HandicapCardState();
}

class _MedalWinner {
  final String name;
  final String? userId;
  const _MedalWinner({required this.name, this.userId});
}

class _HandicapCardState extends State<_HandicapCard> {
  bool _expanded = false;
  final Map<String, List<_MedalWinner>> _top3 =
      {}; // raceId -> [gold, silver, bronze]

  // Visible intro: single paragraph
  static const String _visiblePara =
      'Each year the club holds a series of handicap races from which points are scored in relation to finishing positions. These points count towards a league table. Prizes are presented at the presentation evening. This is an in-house competition but guest runners are most welcome to run with us.';

  // Hidden content includes the second intro paragraph + detailed explanation
  static const String _hiddenParas =
      'Each runner is given a predicted time and then the runners are set off with the slowest first and fastest last. Everybody is staggered accordingly to their time in-between. The idea being that everybody finishes pretty much at the same time.\n\n'
      'A running handicap race is a type of running event in which runners are given a "handicap" or head start based on their expected finish time. The goal of a handicap race is to level the playing field for runners of different abilities, so that everyone has an equal chance of winning.\n\n'
      'In a handicap race, the fastest runners will start last, while the slower runners will start first. The idea is that the faster runners will have to work harder to catch up to the slower runners, while the slower runners will have the advantage of a head start.\n\n'
      'Handicap races are often used in club and community running events, as well as in charity races. They can be organized as both road races and trail races, and can be held at distances ranging from 5K to marathon.\n\n'
      "The handicaps are usually calculated based on a runner's past performance, or on their estimated finish time. Some races will use a formula to calculate the handicaps, while others will rely on the judgment of the race organizers.\n\n"
      'In the race, the winner is not the one who finishes first, but the one who crosses the finish line first after all the handicaps has been taken into account.\n\n'
      'Overall, the Handicap Race is an exciting way to make the race more fair and keep the competition fierce, as well as create an encouraging environment for all the participants by providing everyone with a chance to win, regardless of their running abilities.';

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 160.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF141A24), Color(0xFF0D0F18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1F2A3A), width: 1),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header photo that scrolls away
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: headerHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/handicappic.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black54],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        'The Handicap Series',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F111A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF5C542), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _visiblePara,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.45),
                  ),
                  if (!_expanded) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = true),
                        child: const Text('What is a Handicap Race ⌄'),
                      ),
                    ),
                  ],
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    Text(
                      _hiddenParas,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, height: 1.45),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = false),
                        child: const Text('Show less ⌃'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final r in widget.races) ...[
              _handicapRow(r),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _handicapRow(_HandicapRace r) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header: flag (left), centered title, plus (right)
          Row(
            children: [
              SizedBox(
                width: 36,
                child: widget.isAdmin
                    ? IconButton(
                        tooltip: 'Top 3 Finishers',
                        onPressed: () => _openTop3Dialog(r),
                        icon: const Icon(
                          Icons.flag_circle_outlined,
                          color: Color(0xFFFFD700),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    r.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 36,
                child: widget.isAdmin
                    ? IconButton(
                        tooltip: 'Create Event',
                        onPressed: () => widget.onCreateEvent(r),
                        icon: const Icon(
                          Icons.add_box_outlined,
                          color: Color(0xFFFFD700),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Combined row: Date (left half) and Venue (right half)
          Row(
            children: [
              // Left: Date section
              Expanded(
                child: Row(
                  children: [
                    if (widget.isAdmin)
                      IconButton(
                        tooltip: 'Pick date',
                        onPressed: () => widget.onEditDate(r),
                        icon: const Icon(
                          Icons.calendar_month,
                          color: Color(0xFFFFD700),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      const Icon(
                        Icons.event,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child:
                          (r.date.trim().isEmpty ||
                              r.date.toLowerCase() == 'tbd')
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(0xFF4A90E2),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Date',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text(
                              r.date,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Right: Venue section
              Expanded(
                child: Row(
                  children: [
                    if (widget.isAdmin)
                      IconButton(
                        tooltip: 'Edit venue',
                        onPressed: () => widget.onEditVenue(r),
                        icon: const Icon(
                          Icons.edit_location_alt,
                          color: Color(0xFFFFD700),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      const Icon(
                        Icons.place,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child:
                          (r.venue.trim().isEmpty ||
                              r.venue.toLowerCase() == 'tbd')
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Color(0xFF4A90E2),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Venue',
                                style: TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text(
                              r.venue,
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Top 3 finishers box below details
          _top3Box(r),
        ],
      ),
    );
  }

  Widget _top3Box(_HandicapRace r) {
    final winners = _top3[r.id] ?? [];
    final nonEmpty = winners.where((w) => w.name.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromRGBO(0, 0, 255, 1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Top 3 Finishers',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < 3; i++)
            if (i < winners.length && winners[i].name.trim().isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: i == 0
                        ? const Color(0xFFFFD700)
                        : i == 1
                        ? const Color(0xFFC0C0C0)
                        : const Color(0xFFCD7F32),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      winners[i].name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (i < 2) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }

  Future<void> _openTop3Dialog(_HandicapRace r) async {
    final initial =
        (_top3[r.id] ??
        [
          const _MedalWinner(name: '', userId: null),
          const _MedalWinner(name: '', userId: null),
          const _MedalWinner(name: '', userId: null),
        ]);
    final goldCtrl = TextEditingController(text: initial[0].name);
    final silverCtrl = TextEditingController(text: initial[1].name);
    final bronzeCtrl = TextEditingController(text: initial[2].name);
    String? goldUserId = initial[0].userId;
    String? silverUserId = initial[1].userId;
    String? bronzeUserId = initial[2].userId;

    List<Map<String, String>> goldSuggestions = const [];
    List<Map<String, String>> silverSuggestions = const [];
    List<Map<String, String>> bronzeSuggestions = const [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F111A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: Color.fromRGBO(21, 0, 255, 1),
                  width: 1,
                ),
              ),
              title: const Text(
                'Top 3 Finishers',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _medalField(
                      label: 'Gold',
                      controller: goldCtrl,
                      color: const Color(0xFFFFD700),
                      suggestions: goldSuggestions,
                      onChanged: (q) async {
                        goldSuggestions = await _searchUsers(q);
                        setDState(() {});
                      },
                      onPick: (opt) {
                        goldCtrl.text = opt['full_name'] ?? '';
                        goldUserId = opt['id'];
                        goldSuggestions = const [];
                        setDState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    _medalField(
                      label: 'Silver',
                      controller: silverCtrl,
                      color: const Color(0xFFC0C0C0),
                      suggestions: silverSuggestions,
                      onChanged: (q) async {
                        silverSuggestions = await _searchUsers(q);
                        setDState(() {});
                      },
                      onPick: (opt) {
                        silverCtrl.text = opt['full_name'] ?? '';
                        silverUserId = opt['id'];
                        silverSuggestions = const [];
                        setDState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    _medalField(
                      label: 'Bronze',
                      controller: bronzeCtrl,
                      color: const Color(0xFFCD7F32),
                      suggestions: bronzeSuggestions,
                      onChanged: (q) async {
                        bronzeSuggestions = await _searchUsers(q);
                        setDState(() {});
                      },
                      onPick: (opt) {
                        bronzeCtrl.text = opt['full_name'] ?? '';
                        bronzeUserId = opt['id'];
                        bronzeSuggestions = const [];
                        setDState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final winners = [
                      _MedalWinner(
                        name: goldCtrl.text.trim(),
                        userId: goldUserId,
                      ),
                      _MedalWinner(
                        name: silverCtrl.text.trim(),
                        userId: silverUserId,
                      ),
                      _MedalWinner(
                        name: bronzeCtrl.text.trim(),
                        userId: bronzeUserId,
                      ),
                    ];
                    setState(() => _top3[r.id] = winners);
                    await _saveTop3(r.id, winners);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _medalField({
    required String label,
    required TextEditingController controller,
    required Color color,
    required List<Map<String, String>> suggestions,
    required ValueChanged<String> onChanged,
    required ValueChanged<Map<String, String>> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '$label finisher',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF4A90E2), width: 1),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0xFF4A90E2),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F111A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A90E2), width: 1),
            ),
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (ctx, i) {
                final opt = suggestions[i];
                final name = opt['full_name'] ?? '';
                return ListTile(
                  dense: true,
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => onPick(opt),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<List<Map<String, String>>> _searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('user_profiles')
          .select('id, full_name')
          .ilike('full_name', '%$q%')
          .limit(6);
      return rows
          .map<Map<String, String>>(
            (r) => {
              'id': (r['id'] as String?) ?? '',
              'full_name': ((r['full_name'] as String?) ?? '').trim(),
            },
          )
          .where((opt) => (opt['full_name'] ?? '').isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveTop3(String raceId, List<_MedalWinner> winners) async {
    // Try Supabase first (table: handicap_top3 with columns: race_id, gold, silver, bronze)
    try {
      await Supabase.instance.client.from('handicap_top3').upsert({
        'race_id': raceId,
        'gold': winners.isNotEmpty ? winners[0].name : null,
        'silver': winners.length > 1 ? winners[1].name : null,
        'bronze': winners.length > 2 ? winners[2].name : null,
        'gold_user_id': winners.isNotEmpty ? winners[0].userId : null,
        'silver_user_id': winners.length > 1 ? winners[1].userId : null,
        'bronze_user_id': winners.length > 2 ? winners[2].userId : null,
      });
    } catch (_) {
      // Fallback to local persistence
      final prefs = await SharedPreferences.getInstance();
      final lines = winners
          .map((w) => '${w.name}|${w.userId ?? ''}')
          .join('\n');
      await prefs.setString('handicap_' + raceId + '_top3', lines);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTop3FromStorage();
  }

  Future<void> _loadTop3FromStorage() async {
    // Try loading from Supabase; if not available, use SharedPreferences
    try {
      final rows = await Supabase.instance.client
          .from('handicap_top3')
          .select();
      for (final r in rows) {
        final id = (r['race_id'] as String?) ?? '';
        if (id.isEmpty) continue;
        _top3[id] = [
          _MedalWinner(
            name: (r['gold'] as String?) ?? '',
            userId: r['gold_user_id'] as String?,
          ),
          _MedalWinner(
            name: (r['silver'] as String?) ?? '',
            userId: r['silver_user_id'] as String?,
          ),
          _MedalWinner(
            name: (r['bronze'] as String?) ?? '',
            userId: r['bronze_user_id'] as String?,
          ),
        ];

        // Hydrate date/venue for visibility to all users if provided by admin
        final dateLabel = (r['date_label'] as String?)?.trim();
        final venue = (r['venue'] as String?)?.trim();
        if ((dateLabel != null && dateLabel.isNotEmpty) ||
            (venue != null && venue.isNotEmpty)) {
          for (final hr in widget.races) {
            if (hr.id == id) {
              if (dateLabel != null && dateLabel.isNotEmpty)
                hr.date = dateLabel;
              if (venue != null && venue.isNotEmpty) hr.venue = venue;
              break;
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      for (final r in widget.races) {
        final s = prefs.getString('handicap_' + r.id + '_top3');
        if (s != null && s.isNotEmpty) {
          final lines = s.split('\n');
          _top3[r.id] = lines.map((line) {
            final parts = line.split('|');
            return _MedalWinner(
              name: parts.isNotEmpty ? parts[0] : '',
              userId: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
            );
          }).toList();
        }
      }
      if (mounted) setState(() {});
    }
  }
}

class _RaceCard extends StatelessWidget {
  final _RaceInfo info;
  final bool isAdmin;
  final VoidCallback onEditDate;
  final VoidCallback? onPickDate;
  final VoidCallback? onCreateEvent;
  final Future<void> Function(String url) onOpen;

  const _RaceCard({
    required this.info,
    required this.isAdmin,
    required this.onEditDate,
    this.onPickDate,
    this.onCreateEvent,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF141A24), Color(0xFF0D0F18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF1F2A3A), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: info.keyId == 'eaccl'
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: info.keyId == 'eaccl'
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: info.keyId == 'eaccl'
                            ? TextAlign.center
                            : null,
                      ),
                      if (info.keyId == 'eaccl') ...[
                        const SizedBox(height: 6),
                        Text(
                          info.location,
                          style: const TextStyle(
                            color: Color(0xFF56D3FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        info.overview,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                          fontSize: 14,
                        ),
                        textAlign: info.keyId == 'eaccl'
                            ? TextAlign.center
                            : null,
                      ),
                    ],
                  ),
                ),
                // Per latest request, no edit icons on title row
              ],
            ),
            if (info.keyId != 'eaccl') ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  if (isAdmin && onPickDate != null) ...[
                    IconButton(
                      onPressed: onPickDate,
                      icon: const Icon(
                        Icons.calendar_month,
                        color: Color(0xFFFFD700),
                      ),
                      tooltip: 'Pick race date',
                    ),
                  ] else ...[
                    const Icon(Icons.event, color: Color(0xFFFFD700), size: 20),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    info.date,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Keep Create Event on the right for admins (icon-only)
                  if (isAdmin && onCreateEvent != null)
                    IconButton(
                      onPressed: onCreateEvent,
                      tooltip: 'Create Event',
                      icon: const Icon(
                        Icons.add_box_outlined,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Photo placed below date, slightly zoomed and smaller
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Transform.scale(
                        scale: 1.07,
                        child: Image.asset(
                          _imageForRace(info.keyId),
                          fit: BoxFit.cover,
                        ),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Race Info box (Venue, Registration, Start)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(icon: Icons.place, text: info.location),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.assignment_ind,
                      text: info.registration,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(icon: Icons.flag_circle, text: info.raceStart),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 14),
            if (info.specialNote != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: info.specialNoteUrl != null
                    ? () => onOpen(info.specialNoteUrl!)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0F1E3A)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4A90E2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Color(0xFF4A90E2),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          info.specialNote!,
                          style: const TextStyle(
                            color: Color(0xFF4A90E2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (info.specialNoteUrl != null)
                        const Icon(
                          Icons.open_in_new,
                          color: Color(0xFF4A90E2),
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Facilities',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                info.facilities,
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Results',
                    icon: Icons.emoji_events,
                    onPressed: () => onOpen(info.resultsUrl),
                    color: const Color(0xFFFFD700),
                    textColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Drive',
                    icon: Icons.map,
                    onPressed: () => onOpen(info.mapUrl),
                    color: const Color(0xFF1E88E5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _imageForRace(String keyId) {
    switch (keyId) {
      case 'holt':
        return 'assets/images/holt10.png';
      case 'worstead':
        return 'assets/images/worstead5m.png';
      case 'chase':
        return 'assets/images/chasetrain.jpg';
      default:
        return 'assets/images/eaccl.jpg';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
