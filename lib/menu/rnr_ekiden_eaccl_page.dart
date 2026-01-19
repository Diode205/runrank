import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
// import 'package:shared_preferences/shared_preferences.dart';

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
      // Swipeable pages: RNR, EKIDEN, EACCL
      body: PageView(children: const [_RnrPage(), _EkidenPage(), _EacclPage()]),
    );
  }
}

// Header removed per request

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

// New swipe pages
class _RnrPage extends StatefulWidget {
  const _RnrPage();
  @override
  State<_RnrPage> createState() => _RnrPageState();
}

class _RnrPageState extends State<_RnrPage> {
  bool _expanded = false;
  bool _isAdmin = false;
  final List<_StageInfo> _stages = const [
    _StageInfo(
      label: "S1: King's Lynn — PE30 2NB",
      query: "King's Lynn PE30 2NB",
    ),
    _StageInfo(
      label: 'S2: Hunstanton — PE36 6EL',
      query: 'Hunstanton PE36 6EL',
    ),
    _StageInfo(
      label: 'S3: Burnham Overy Staithe — PE31 8JF',
      query: 'Burnham Overy Staithe PE31 8JF',
    ),
    _StageInfo(
      label: 'S4: Wells-next-the-Sea — NR23 1DR',
      query: 'Wells-next-the-Sea NR23 1DR',
    ),
    _StageInfo(
      label: 'S5: Cley-next-the-Sea — NR25 7RZ',
      query: 'Cley-next-the-Sea NR25 7RZ',
    ),
    _StageInfo(label: 'S6: Cromer — NR27 9BA', query: 'Cromer NR27 9BA'),
    _StageInfo(label: 'S7: Mundesley — NR11 8BE', query: 'Mundesley NR11 8BE'),
    _StageInfo(
      label: 'S8: Lessingham — NR12 0SF',
      query: 'Lessingham NR12 0SF',
    ),
    _StageInfo(label: 'S9: Horsey — NR29 4EF', query: 'Horsey NR29 4EF'),
    _StageInfo(label: 'S10: Belton — NR31 9LN', query: 'Belton NR31 9LN'),
    _StageInfo(label: 'S11: Earsham — NR35 2TQ', query: 'Earsham NR35 2TQ'),
    _StageInfo(label: 'S12: Scole — IP21 4EE', query: 'Scole IP21 4EE'),
    _StageInfo(label: 'S13: Thetford — IP24 2DS', query: 'Thetford IP24 2DS'),
    _StageInfo(label: 'S14: Feltwell — IP26 4AB', query: 'Feltwell IP26 4AB'),
    _StageInfo(
      label: 'S15: Wissington — PE33 9QG',
      query: 'Wissington PE33 9QG',
    ),
    _StageInfo(
      label: 'S16: Downham Market — PE38 9HS',
      query: 'Downham Market PE38 9HS',
    ),
    _StageInfo(
      label: 'S17: Stowbridge — PE34 3PW',
      query: 'Stowbridge PE34 3PW',
    ),
  ];

  static const String _visiblePara =
      'The course of the Round Norfolk Relay mirrors the county boundary over a distance of 198 miles, divided into 17 unequal stages. Norfolk\'s enormous skies, vast sandy beaches, open spaces and picturesque towns and villages, with their attractive cottages and medieval churches, all contribute to making the race a unique running experience. But it is likely to be the spectacular skies at sunset and sunrise which will provide the most vivid memories.';

  static const String _morePara =
      'The race starts at Lynnsport in Kings Lynn and then, from Hunstanton, follows the stunning coastline through 5 multi terrain stages taking the Norfolk Coastal path as far as Cromer. The 40 miles (4 stages) from Cromer through to Horsey Mill and on to Belton are on the road. By the time the teams reach Belton it is dark.\n\nFrom Belton, the course turns south-west following main roads for 62 miles (4 stages), all run in darkness. It is during these mostly flat stages through Breckland that the time stagger unwinds and the race is invariably won or lost. From Feltwell (Stage 14) the four remaining stages covering the last 33 miles are run across the flat Fens through the early morning mist. Finally, following the Great Ouse River into historic King\'s Lynn runners pass by the old Custom house, through the famous Tuesday Market Place and then on to the Finish at Lynnsport.\n\nUnique in character and concept, the race presents not only a tough physical challenge, but also a test of the organisational prowess of a club. Run over 24 hours, without a break (and carrying a baton), the event is much more than just a normal relay for it requires special preparation, planning and support. It is not an event for a club without a spirit of adventure. But the sense of satisfaction and achievement after completing the race is simply \"Second to None\".\n\nA staggered start, based on anticipated finishing times, ensures that teams of similar ability start together, with faster teams chasing. If the stagger works, all teams should finish the race by 9:15am to 10:00am on the Sunday. With the first teams starting at 5:30 am on Saturday this allows for teams running an average of 8mins 40secs per mile throughout the course.';

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps(String query) async {
    final options = await _availableMapOptions(query);
    if (options.isEmpty) {
      // Fallback to browser Google Maps
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (options.length == 1) {
      await options.first.launcher();
      return;
    }
    if (!mounted) return;
    // Show chooser for user preference
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Open with',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final opt in options)
              ListTile(
                leading: Icon(opt.icon, color: Colors.white70),
                title: Text(
                  opt.label,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await opt.launcher();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<List<_MapOption>> _availableMapOptions(String query) async {
    final encoded = Uri.encodeComponent(query);
    final List<_MapOption> opts = [];

    // Apple Maps (primarily iOS)
    if (Platform.isIOS) {
      final uri = Uri.parse('http://maps.apple.com/?q=$encoded');
      opts.add(
        _MapOption(
          label: 'Apple Maps',
          icon: Icons.map,
          launcher: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      );
    }

    // Google Maps app
    final googleScheme = Platform.isIOS
        ? Uri.parse('comgooglemaps://')
        : Uri.parse('geo:0,0?q=$encoded');
    if (await canLaunchUrl(googleScheme)) {
      final uri = Platform.isIOS
          ? Uri.parse('comgooglemaps://?q=$encoded')
          : Uri.parse('geo:0,0?q=$encoded');
      opts.add(
        _MapOption(
          label: 'Google Maps',
          icon: Icons.location_on,
          launcher: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      );
    }

    // Waze
    final wazeScheme = Uri.parse('waze://');
    if (await canLaunchUrl(wazeScheme)) {
      final uri = Uri.parse('waze://?q=$encoded&navigate=yes');
      opts.add(
        _MapOption(
          label: 'Waze',
          icon: Icons.directions_car,
          launcher: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      );
    }

    // Browser fallback (always available)
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );
    opts.add(
      _MapOption(
        label: 'Browser',
        icon: Icons.language,
        launcher: () => launchUrl(web, mode: LaunchMode.externalApplication),
      ),
    );

    return opts;
  }

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    if (mounted) setState(() {});
  }

  void _createEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Race',
          initialVenue: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 240;
    return Stack(
      children: [
        // Background: opaque main photo
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Image.asset(
              'assets/images/rnr.png',
              height: heroHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Foreground: scrollable content overlaying the hero
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, heroHeight - 60, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main content card with border and padding
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF141A24), Color(0xFF0D0F18)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD700),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Centered second image, overlapping the hero
                      Center(
                        child: Image.asset(
                          'assets/images/RNR26.png',
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _visiblePara,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Row: Create Event (left) and Read more (right)
                      Row(
                        children: [
                          if (_isAdmin)
                            IconButton(
                              tooltip: 'Create event',
                              onPressed: _createEvent,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFFFFD700),
                              ),
                            )
                          else
                            const SizedBox(width: 48),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                            child: Text(
                              _expanded ? 'Show less' : 'Read more…',
                              style: const TextStyle(color: Color(0xFF56D3FF)),
                            ),
                          ),
                        ],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 6),
                        Text(
                          _morePara,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Blue link button, centered label
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openLink('https://theroundnorfolkrelay.com/'),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Visit The RNR Site'),
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
                  ),
                ),
                const SizedBox(height: 12),
                // Bottom action buttons: Results and Drive (+ stages dropdown)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openLink(
                          'https://rnr.totalracetiming.co.uk/result',
                        ),
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Results'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E406A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PopupMenuButton<int>(
                        tooltip: 'Drive to stage',
                        itemBuilder: (context) => [
                          for (int i = 0; i < _stages.length; i++)
                            PopupMenuItem<int>(
                              value: i,
                              child: Text(_stages[i].label),
                            ),
                        ],
                        onSelected: (index) {
                          final s = _stages[index];
                          _openMaps(s.query);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.directions, size: 18, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                'Drive To',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_drop_down, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StageInfo {
  final String label;
  final String query;
  const _StageInfo({required this.label, required this.query});
}

class _MapOption {
  final String label;
  final IconData icon;
  final Future<void> Function() launcher;
  const _MapOption({
    required this.label,
    required this.icon,
    required this.launcher,
  });
}

class _EkidenPage extends StatelessWidget {
  const _EkidenPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [_EkidenCard()],
    );
  }
}

class _EacclPage extends StatelessWidget {
  const _EacclPage();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [_EacclCard()],
    );
  }
}
