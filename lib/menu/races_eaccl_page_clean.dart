import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _HandicapRace(id: 'h1', title: '5K Handicap', date: '', venue: ''),
    _HandicapRace(id: 'h2', title: '8.8 Mile Beach', date: '', venue: ''),
    _HandicapRace(id: 'h3', title: '10 Mile', date: '', venue: ''),
    _HandicapRace(id: 'h4', title: '5 Mile', date: '', venue: ''),
    _HandicapRace(id: 'h5', title: '10K', date: '', venue: ''),
    _HandicapRace(id: 'h6', title: '7 Mile', date: '', venue: ''),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
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
      }
    });
  }

  void _editHandicapVenue(_HandicapRace r) {
    final controller = TextEditingController(text: '');
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

class _HandicapCardState extends State<_HandicapCard> {
  bool _expanded = false;

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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.isAdmin)
                TextButton.icon(
                  onPressed: () => widget.onCreateEvent(r),
                  icon: const Icon(
                    Icons.add_box_outlined,
                    color: Color(0xFFFFD700),
                  ),
                  label: const Text('Create Event'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: (r.date.trim().isEmpty || r.date.toLowerCase() == 'tbd')
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                        ),
                      )
                    : Text(
                        r.date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              if (widget.isAdmin)
                IconButton(
                  tooltip: 'Edit date',
                  onPressed: () => widget.onEditDate(r),
                  icon: const Icon(
                    Icons.edit_calendar,
                    color: Color(0xFFFFD700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child:
                    (r.venue.trim().isEmpty || r.venue.toLowerCase() == 'tbd')
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                        ),
                      )
                    : Text(
                        r.venue,
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
              if (widget.isAdmin)
                IconButton(
                  tooltip: 'Edit venue',
                  onPressed: () => widget.onEditVenue(r),
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

class _RaceCard extends StatelessWidget {
  final _RaceInfo info;
  final bool isAdmin;
  final VoidCallback onEditDate;
  final Future<void> Function(String url) onOpen;

  const _RaceCard({
    required this.info,
    required this.isAdmin,
    required this.onEditDate,
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
                  const Icon(Icons.event, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    info.date,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (isAdmin)
                    IconButton(
                      onPressed: onEditDate,
                      icon: const Icon(
                        Icons.edit_calendar,
                        color: Color(0xFFFFD700),
                      ),
                      tooltip: 'Edit race date',
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
