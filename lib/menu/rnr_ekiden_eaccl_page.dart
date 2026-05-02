import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
import 'package:runrank/widgets/web_link_preview_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isNrrClubName(String? clubName) {
  final club = (clubName ?? '').trim().toLowerCase();
  return club == 'nrr' || club.contains('norwich road runners');
}

Color _clubPrimaryColor(String? clubName) {
  final lower = (clubName ?? '').trim().toLowerCase();
  if (lower.isEmpty) return const Color(0xFF3A3A3A);
  return _isNrrClubName(clubName)
      ? const Color(0xFFD32F2F)
      : const Color(0xFFF5C542);
}

Color _clubPrimaryForegroundColor(String? clubName) {
  final lower = (clubName ?? '').trim().toLowerCase();
  if (lower.isEmpty) return Colors.white;
  return _isNrrClubName(clubName) ? Colors.white : Colors.black;
}

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
      body: SafeArea(
        top: false,
        child: PageView(
          children: const [_RnrPage(), _EkidenPage(), _EacclPage()],
        ),
      ),
    );
  }
}

const double _pageInset = 16;
const double _controlHeight = 44;
const double _contentGap = 12;

ButtonStyle _primaryActionStyle(Color background, Color foreground) {
  return ElevatedButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    minimumSize: const Size.fromHeight(_controlHeight),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

// Header removed per request

// (Replaced by the new _EkidenPage layout)

// (Replaced by the new _EacclPage layout)

// New swipe pages
class _RnrPage extends StatefulWidget {
  const _RnrPage();
  @override
  State<_RnrPage> createState() => _RnrPageState();
}

class _RnrPageState extends State<_RnrPage> {
  bool _isAdmin = false;
  String? _clubName;

  Color get _accentColor => _clubPrimaryColor(_clubName);
  Color get _accentForegroundColor => _clubPrimaryForegroundColor(_clubName);
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
    _clubName = await UserService.currentClubName();
    if (mounted) setState(() {});
  }

  void _createEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Relay',
          initialVenue: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _OfficialSiteCard(
                  title: 'Round Norfolk Relay',
                  url: 'https://theroundnorfolkrelay.com/',
                  accentColor: _accentColor,
                  height: constraints.maxHeight,
                  showAddButton: _isAdmin,
                  onAddEvent: _createEvent,
                );
              },
            ),
          ),
          const SizedBox(height: _contentGap),
          SizedBox(
            height: _controlHeight,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openLink('https://rnr.totalracetiming.co.uk/result'),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Results'),
                    style: _primaryActionStyle(
                      _accentColor,
                      _accentForegroundColor,
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
                      height: _controlHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
          ),
        ],
      ),
    );
  }
}

class _OfficialSiteCard extends StatelessWidget {
  const _OfficialSiteCard({
    required this.title,
    required this.url,
    required this.accentColor,
    required this.height,
    this.showAddButton = false,
    this.onAddEvent,
  });

  final String title;
  final String url;
  final Color accentColor;
  final double height;
  final bool showAddButton;
  final VoidCallback? onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            WebLinkPreviewCard(
              url: url,
              buttonLabel: 'Visit Site',
              height: height,
              forceMobileViewport: url.contains('theroundnorfolkrelay.com'),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (showAddButton && onAddEvent != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onAddEvent,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        color: accentColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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

class _EkidenPage extends StatefulWidget {
  const _EkidenPage();
  @override
  State<_EkidenPage> createState() => _EkidenPageState();
}

class _EkidenPageState extends State<_EkidenPage> {
  bool _isAdmin = false;
  String? _clubName;

  Color get _accentColor => _clubPrimaryColor(_clubName);
  Color get _accentForegroundColor => _clubPrimaryForegroundColor(_clubName);

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    _clubName = await UserService.currentClubName();
    if (mounted) setState(() {});
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps(String query) async {
    final options = await _availableMapOptionsEkiden(query);
    if (options.isEmpty) {
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

  Future<List<_MapOption>> _availableMapOptionsEkiden(String query) async {
    final encoded = Uri.encodeComponent(query);
    final List<_MapOption> opts = [];

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

  void _createEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Relay',
          initialVenue: null,
          initialRelayFormat: 'Ekiden',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const registerHeight = 36.0;

    return Padding(
      padding: const EdgeInsets.all(_pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _OfficialSiteCard(
                  title: 'Ipswich Ekiden',
                  url: 'https://www.ipswichekiden.co.uk/',
                  accentColor: _accentColor,
                  height: constraints.maxHeight,
                  showAddButton: _isAdmin,
                  onAddEvent: _createEvent,
                );
              },
            ),
          ),
          const SizedBox(height: _contentGap),
          SizedBox(
            height: registerHeight,
            child: TextButton.icon(
              onPressed: () => _openLink('https://portal.ipswichekiden.co.uk/'),
              icon: Icon(Icons.group_add, color: _accentColor, size: 18),
              label: Text(
                'Register your team',
                style: TextStyle(color: _accentColor),
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _controlHeight,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(
                      'https://onedrive.live.com/:x:/g/personal/56EC7C0093D7DC62/ETMLmCH7WGxNopw0rw_OZeQBnNhrEjr7s9hko8_u5tzu6A?resid=56EC7C0093D7DC62!s21980b3358fb4d6ca29c34af0fce65e4&ithint=file%2Cxlsx&migratedtospo=true&redeem=aHR0cHM6Ly8xZHJ2Lm1zL3gvYy81NmVjN2MwMDkzZDdkYzYyL0VUTUxtQ0g3V0d4Tm9wdzByd19PWmVRQm5OaHJFanI3czloa284X3U1dHp1NkE',
                    ),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Results'),
                    style: _primaryActionStyle(
                      _accentColor,
                      _accentForegroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaps(
                      'Ipswich High School, Woolverstone, Ipswich IP9 1AZ',
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Drive To'),
                    style: _primaryActionStyle(Colors.white, Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EacclPage extends StatefulWidget {
  const _EacclPage();
  @override
  State<_EacclPage> createState() => _EacclPageState();
}

class _EacclPageState extends State<_EacclPage> {
  bool _isAdmin = false;
  String? _clubName;

  Color get _accentColor => _clubPrimaryColor(_clubName);
  Color get _accentForegroundColor => _clubPrimaryForegroundColor(_clubName);

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    _loadRaceOverrides();
  }

  Future<void> _loadAdmin() async {
    _isAdmin = await UserService.isAdmin();
    _clubName = await UserService.currentClubName();
    if (mounted) setState(() {});
  }

  Future<void> _loadRaceOverrides() async {
    // Try Supabase first; fall back to local storage if unavailable
    try {
      final rows = await Supabase.instance.client
          .from('handicap_top3')
          .select('race_id, date_label, venue');

      for (final row in rows) {
        final id = (row['race_id'] as String?) ?? '';
        if (id.isEmpty) continue;

        final dateLabel = (row['date_label'] as String?)?.trim();
        final venue = (row['venue'] as String?)?.trim();
        if ((dateLabel == null || dateLabel.isEmpty) &&
            (venue == null || venue.isEmpty)) {
          continue;
        }

        for (final r in _races) {
          if (r.id == id) {
            if (dateLabel != null && dateLabel.isNotEmpty) {
              r.date = dateLabel;
            }
            if (venue != null && venue.isNotEmpty) {
              r.venue = venue;
            }
            break;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final r in _races) {
          final raw = prefs.getString('eaccl_${r.id}_meta');
          if (raw == null || raw.isEmpty) continue;
          final parts = raw.split('|');
          if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
            r.date = parts[0].trim();
          }
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            r.venue = parts[1].trim();
          }
          if (parts.length > 2 && parts[2].trim().isNotEmpty) {
            r.postcode = parts[2].trim();
          }
        }
        if (mounted) setState(() {});
      } catch (_) {
        // Ignore local storage errors; fall back to hard-coded values
      }
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps(String query) async {
    final options = await _availableMapOptionsEaccl(query);
    if (options.isEmpty) {
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

  Future<List<_MapOption>> _availableMapOptionsEaccl(String query) async {
    final encoded = Uri.encodeComponent(query);
    final List<_MapOption> opts = [];

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

  DateTime? _parseEacclDate(String raw) {
    try {
      final parts = raw.split(' ');
      if (parts.length < 3) return null;

      final dayStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
      final day = int.tryParse(dayStr);
      final monthName = parts[1];
      final year = int.tryParse(parts[2]);

      if (day == null || year == null) return null;

      const monthMap = {
        'January': 1,
        'February': 2,
        'March': 3,
        'April': 4,
        'May': 5,
        'June': 6,
        'July': 7,
        'August': 8,
        'September': 9,
        'October': 10,
        'November': 11,
        'December': 12,
      };

      final month = monthMap[monthName];
      if (month == null) return null;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _formatEacclDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    String suffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    final day = date.day;
    final monthName = months[date.month - 1];
    final year = date.year;
    return '$day${suffix(day)} $monthName $year';
  }

  void _createEventFor(String venue, String postcode, String date, int raceNo) {
    final parsedDate = _parseEacclDate(date);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEventPage(
          userRole: _isAdmin ? 'admin' : 'social',
          initialEventType: 'Cross Country',
          initialRaceName: 'EACCL Race $raceNo',
          initialVenue: venue,
          initialVenueAddress: postcode,
          initialDate: parsedDate,
        ),
      ),
    );
  }

  Future<void> _saveRaceOverride(_EacclRace race) async {
    final dateLabel = race.date.trim();
    final venue = race.venue.trim();

    try {
      await Supabase.instance.client.from('handicap_top3').upsert({
        'race_id': race.id,
        'date_label': dateLabel,
        'venue': venue,
      });
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'eaccl_${race.id}_meta',
        '$dateLabel|$venue|${race.postcode}',
      );
    }
  }

  Future<void> _editRace(_EacclRace race) async {
    final dateController = TextEditingController(text: race.date);
    final venueController = TextEditingController(text: race.venue);
    final postcodeController = TextEditingController(text: race.postcode);

    Future<void> pickDate() async {
      final now = DateTime.now();
      final initial = _parseEacclDate(dateController.text) ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 365 * 3)),
      );
      if (picked != null) {
        dateController.text = _formatEacclDate(picked);
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Race ${race.no}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dateController,
                readOnly: true,
                onTap: pickDate,
                decoration: InputDecoration(
                  labelText: 'Date label',
                  helperText: 'Tap calendar to pick date',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date',
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: pickDate,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: venueController,
                decoration: const InputDecoration(labelText: 'Venue'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: postcodeController,
                decoration: const InputDecoration(labelText: 'Postcode'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        race.date = dateController.text.trim().isEmpty
            ? race.date
            : dateController.text.trim();
        race.venue = venueController.text.trim().isEmpty
            ? race.venue
            : venueController.text.trim();
        race.postcode = postcodeController.text.trim().isEmpty
            ? race.postcode
            : postcodeController.text.trim();
      });

      await _saveRaceOverride(race);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Race ${race.no} updated')));
      }
    }
  }

  final List<_EacclRace> _races = [
    _EacclRace(
      id: 'eaccl_r1',
      no: 1,
      venue: 'Chilton Fields (Stowmarket) Rugby Club',
      postcode: 'IP14 1SZ',
      date: '29th October 2025',
    ),
    _EacclRace(
      id: 'eaccl_r2',
      no: 2,
      venue: 'Mousehold Heath',
      postcode: 'NR3 4JB',
      date: '12th November 2025',
    ),
    _EacclRace(
      id: 'eaccl_r3',
      no: 3,
      venue: 'Cart Gap',
      postcode: 'NR12 0QL',
      date: '26th November 2025',
    ),
    _EacclRace(
      id: 'eaccl_r4',
      no: 4,
      venue: 'Whitwell Station',
      postcode: 'NR10 4GA',
      date: '10th December 2025',
    ),
    _EacclRace(
      id: 'eaccl_r5',
      no: 5,
      venue: 'Broadland Country Park',
      postcode: 'NR10 3FB',
      date: '14th January 2026',
    ),
    _EacclRace(
      id: 'eaccl_r6',
      no: 6,
      venue: 'Woburn Farm, Corton',
      postcode: 'NR32 5LE',
      date: '28th January 2026',
    ),
    _EacclRace(
      id: 'eaccl_r7',
      no: 7,
      venue: 'Cromer',
      postcode: 'NR27 9AU',
      date: '4th February 2026',
    ),
    _EacclRace(
      id: 'eaccl_r8',
      no: 8,
      venue: 'Ladybelt Country Park',
      postcode: 'NR14 8HX',
      date: '11th February 2026',
    ),
    _EacclRace(
      id: 'eaccl_r9',
      no: 9,
      venue: 'Cawston Park',
      postcode: 'NR10 4JD',
      date: '11th March 2026',
    ),
    _EacclRace(
      id: 'eaccl_r10',
      no: 10,
      venue: 'High Lodge, Thetford Forest',
      postcode: 'IP27 0AF',
      date: '25th March 2026',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final raceListHeight = (constraints.maxHeight * 0.16)
            .clamp(84.0, 118.0)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.all(_pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, previewConstraints) {
                    return _OfficialSiteCard(
                      title: 'East Anglian Cross Country League',
                      url: 'https://eaccl.org.uk/',
                      accentColor: _accentColor,
                      height: previewConstraints.maxHeight,
                    );
                  },
                ),
              ),
              const SizedBox(height: _contentGap),
              Container(
                height: raceListHeight,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0x0FFFFFFF),
                  border: Border.all(color: _accentColor, width: 1),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _races.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12),
                    itemBuilder: (context, index) {
                      final r = _races[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_isAdmin)
                            IconButton(
                              tooltip: 'Add event',
                              onPressed: () => _createEventFor(
                                r.venue,
                                r.postcode,
                                r.date,
                                r.no,
                              ),
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: _accentColor,
                              ),
                            ),
                          if (_isAdmin) const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Race ${r.no}: ${r.venue}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${r.postcode}  -  ${r.date}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          if (_isAdmin)
                            IconButton(
                              tooltip: 'Edit race details',
                              onPressed: () => _editRace(r),
                              icon: Icon(Icons.edit, color: _accentColor),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: _contentGap),
              SizedBox(
                height: _controlHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _openLink('https://eaccl.org.uk/winter-results/'),
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Results'),
                        style: _primaryActionStyle(
                          _accentColor,
                          _accentForegroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PopupMenuButton<int>(
                        tooltip: 'Drive to venue',
                        itemBuilder: (context) => [
                          for (final r in _races)
                            PopupMenuItem<int>(
                              value: r.no,
                              child: Text(
                                'R${r.no}: ${r.venue} - ${r.postcode}',
                              ),
                            ),
                        ],
                        onSelected: (no) {
                          final r = _races.firstWhere((e) => e.no == no);
                          _openMaps('${r.venue} ${r.postcode}');
                        },
                        child: Container(
                          height: _controlHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.directions,
                                size: 18,
                                color: Colors.black,
                              ),
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
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EacclRace {
  final String id;
  final int no;
  String venue;
  String postcode;
  String date;
  _EacclRace({
    required this.id,
    required this.no,
    required this.venue,
    required this.postcode,
    required this.date,
  });
}
