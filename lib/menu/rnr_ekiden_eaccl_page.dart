import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RnrEkidenEacclPage extends StatelessWidget {
  const RnrEkidenEacclPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'RNR, Ekiden & EACCL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          _HeroHeader(),
          SizedBox(height: 12),
          _RnrCard(),
          SizedBox(height: 12),
          _EkidenCard(),
          SizedBox(height: 12),
          _EacclCard(),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1A3A), Color(0xFF0D2F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Color(0xFF1E406A), width: 1),
      ),
      child: Row(
        children: const [
          Icon(Icons.groups, color: Color(0xFFFFD700), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Managing Team and Relay Participations',
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
}

class _CardBase extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> actions;
  final Widget? image;
  const _CardBase({
    required this.title,
    required this.description,
    this.actions = const [],
    this.image,
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
        border: Border.all(color: Color(0xFF1F2A3A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          if (image != null) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: image!),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

class _RnrCard extends StatelessWidget {
  const _RnrCard();
  @override
  Widget build(BuildContext context) {
    return _CardBase(
      title: 'Round Norfolk Relay (RNR)',
      description:
          'Club-managed multi-stage relay around Norfolk. Entry, team selection, and leg allocations will be coordinated here.',
      actions: const [
        Expanded(child: _SoonButton(label: 'Details coming soon')),
      ],
    );
  }
}

class _EkidenCard extends StatelessWidget {
  const _EkidenCard();
  @override
  Widget build(BuildContext context) {
    return _CardBase(
      title: 'Ekiden Relays',
      description:
          'Club teams at Ekiden events. Manage interest, teams, and legs here. Admin tools will follow.',
      actions: const [
        Expanded(child: _SoonButton(label: 'Details coming soon')),
      ],
    );
  }
}

class _EacclCard extends StatelessWidget {
  const _EacclCard();
  @override
  Widget build(BuildContext context) {
    return _CardBase(
      title: 'East Anglian Cross Country League',
      description:
          'Winter cross-country league across Norfolk and Suffolk. Around ten races per season; team and individual awards.',
      image: Image.asset(
        'assets/images/eaccl.jpg',
        height: 110,
        width: double.infinity,
        fit: BoxFit.cover,
        color: Colors.black.withOpacity(0.2),
        colorBlendMode: BlendMode.darken,
      ),
      actions: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://eaccl.org.uk/winter-events/');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Visit EACCL website'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF56D3FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SoonButton extends StatelessWidget {
  final String label;
  const _SoonButton({required this.label});
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.hourglass_empty, color: Colors.white70, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white70)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
