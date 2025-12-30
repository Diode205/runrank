import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Club Races & EACCL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _hero(),
          ),
          Expanded(child: _raceCards()),
        ],
      ),
    );
  }

  Widget _hero() {
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
      child: Row(
        children: [
          const Icon(Icons.flag, color: Color(0xFFFFD700), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Signature Races & EACC League',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
      _RaceInfo(
        keyId: 'eaccl',
        title: 'East Anglian Cross Country League',
        overview:
            'Winter cross-country league across Norfolk and Suffolk. Around ten races per season, two drop scores allowed for individual awards. Open to clubs and individuals.',
        location: 'The Wednesday League',
        date: 'Season: Late Oct → Mid Mar',
        registration: 'Approx. 10 races per season',
        raceStart: '2 drop scores allowed',
        specialNote: null,
        specialNoteUrl: null,
        ticketsUrl: 'https://eaccl.org.uk/winter-events/',
        resultsUrl: 'https://eaccl.org.uk/winter-events/',
        mapUrl: 'https://eaccl.org.uk/winter-events/',
        facilities:
            'Mixed clubs, friendly atmosphere · Team and individual competitions · Forces and domestic clubs · Running since early 1960s',
      ),
    ];

    return PageView.builder(
      itemCount: races.length,
      controller: PageController(viewportFraction: 0.92),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: _RaceCard(
          info: races[index],
          isAdmin: _isAdmin,
          onEditDate: () => _editDate(races[index].keyId, races[index].title),
          onOpen: _openLink,
        ),
      ),
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
            color: Colors.black.withValues(alpha: 0.35),
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
                if (isAdmin && info.keyId != 'eaccl')
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
                ],
              ),
              const SizedBox(height: 14),
              if (info.keyId == 'holt') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/holt10.png',
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.2),
                        colorBlendMode: BlendMode.darken,
                      ),
                      Container(
                        height: 110,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x990D0F18),
                              Colors.transparent,
                              Color(0xB30D0F18),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (info.keyId == 'worstead') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/worstead5m.png',
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.2),
                        colorBlendMode: BlendMode.darken,
                      ),
                      Container(
                        height: 110,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x990D0F18),
                              Colors.transparent,
                              Color(0xB30D0F18),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else if (info.keyId == 'chase') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/chasetrain.jpg',
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.2),
                        colorBlendMode: BlendMode.darken,
                      ),
                      Container(
                        height: 110,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x990D0F18),
                              Colors.transparent,
                              Color(0xB30D0F18),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(icon: Icons.place, text: info.location),
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.schedule, text: info.registration),
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.flag, text: info.raceStart),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
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
            if (info.keyId == 'eaccl') ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/images/eaccl.jpg',
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.2),
                      colorBlendMode: BlendMode.darken,
                    ),
                    Container(
                      height: 110,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x990D0F18),
                            Colors.transparent,
                            Color(0xB30D0F18),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              info.keyId == 'eaccl'
                  ? 'Race, Dates, Venues and Facilities'
                  : 'Facilities',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              textAlign: info.keyId == 'eaccl' ? TextAlign.center : null,
            ),
            const SizedBox(height: 10),
            if (info.keyId != 'eaccl')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  info.facilities,
                  style: const TextStyle(color: Colors.white70, height: 1.6),
                ),
              ),
            const SizedBox(height: 16),
            if (info.keyId == 'eaccl')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onOpen(info.ticketsUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text(
                    'Visit EACCL website',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF56D3FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Results',
                      icon: Icons.emoji_events,
                      onPressed: () => onOpen(info.ticketsUrl),
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
