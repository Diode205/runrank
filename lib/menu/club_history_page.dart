import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/menu/club_records_page.dart';
import 'package:runrank/menu/club_milestones_page.dart';
import 'package:runrank/menu/team_achievements_page.dart';
import 'package:runrank/services/user_service.dart';

class ClubHistoryPage extends StatefulWidget {
  const ClubHistoryPage({super.key});

  @override
  State<ClubHistoryPage> createState() => _ClubHistoryPageState();
}

class _ClubHistoryPageState extends State<ClubHistoryPage> {
  String? _clubName;

  bool get _isNrrClub {
    final club = _clubName?.toLowerCase() ?? '';
    return club == 'nrr' || club.contains('norwich road runners');
  }

  Color get _primaryColor =>
      _isNrrClub ? const Color(0xFFD32F2F) : const Color(0xFFF5C542);

  Color get _secondaryColor =>
      _isNrrClub ? Colors.white : const Color(0xFF0057B7);

  Color get _cardBorderColor => _isNrrClub ? _primaryColor : _secondaryColor;

  List<_HistorySection> get _sections => _isNrrClub
      ? const [
          _HistorySection(
            title: 'The Early Group',
            content:
                'Ray Lindsey, Mark Futter and Stephen Sadd were running together in 1982 under the banner of Fitt Signs. They were joined by Stephen Dixon in mid 1982 and definitely by the Fakenham 10 mile race on 11 July 1982.',
          ),
          _HistorySection(
            title: 'Midnight Runners',
            content:
                'For a brief period they ran under the banner of Midnight Runners and the results from the second Norfolk Marathon in September 1983 show that the Midnight Runners came fourth non-affiliated team: S. Dixon 3:27:04, M. Futter 3:27:06, R. Lindsay 3:31:56 and S. Sadd 4:01:58.',
          ),
          _HistorySection(
            title: 'The Wider Group Forms',
            content:
                'At the same time as this, but independently, Michael Betts had started running and, as he lived in the same road as Richard Sales in Thurling Plain, they started running together. They too ran the second Norfolk Marathon, where Richard Sales recorded 3:02:42 and Mick Betts 3:08:58, and it was there that they first met the others. It was also there that Mick Betts met up again with Ivan Loades, who he had known in childhood, and Ivan ran 3:12:33.',
          ),
          _HistorySection(
            title: 'Becoming Norwich Road Runners',
            content:
                'The six of us, Mick Betts, Stephen Dixon, Mike Futter, Ray Lindsey, Ivan Loades and Richard Sales, met more regularly. Later, in order to attract more members and keep our best runners, we made a group decision to change the name from Midnight Runners to Norwich Road Runners.',
          ),
          _HistorySection(
            title: 'Founding Members',
            content:
                'The club therefore has six founding members: Mick Betts, Stephen Dixon, Mike Futter, Ray Lindsey, Ivan Loades and Richard Sales. This took place in late 1983 to early 1984, with the first printed record being the second Ipswich Marathon on 9 September 1984, although it is possible we ran under the club name earlier in 1984.',
          ),
          _HistorySection(
            title: 'Affiliation And Growth',
            content:
                'The club was growing and so we started running from The Crome Recreation Centre on Crome Road, now demolished, and later in 1985 the club became affiliated, with Mick Betts becoming the first club secretary. The rest, as they say, is history.',
          ),
        ]
      : const [
          _HistorySection(
            title: 'The Beginning',
            content:
                'The Club began in the mid eighties with an informal group running out of Cromer and East Runton, before settling on Cromer as its base if for no other reason than it was, and still is, a superb place to launch yourself into the North Sea on Boxing Day, a tradition which has grown to the massive event which it is today, raising thousands of pounds for mainly local charities and other good causes.',
          ),
          _HistorySection(
            title: 'Early Days',
            content:
                'From a focussed racing group of just one tenth of the Club\'s current membership, with not a female member in sight, we\'ve grown steadily into a running club for all ages and abilities. Our income was frugal, to say the least, coming from modest subs augmented by income from our Holt 5 annual Road Race, later to become a 7 miler for a time before changing again into the 10K it is today.',
          ),
          _HistorySection(
            title: 'Growth & Evolution',
            content:
                'Like many things in this life, you can\'t keep a good thing down - the Club grew, and grew while keeping its friendliness. We gained our first two lady members, one of whom was to wed the only Club coach we had (Graham Davidson), a female section was to appear, proving only too ready to give the men a real run for their money whilst also making us into a far less chauvinistic membership and a more balanced and agreeable organisation.',
          ),
          _HistorySection(
            title: 'Today',
            content:
                'Today you find one of the best established, and certainly one of the county\'s finest running clubs where you\'ll find a genuine welcome as a new member whatever your level of interest or involvement!',
          ),
        ];

  String get _headline => _isNrrClub
      ? 'Brief History Of The\nRoad Runners'
      : 'Brief History of the\nBlue and Yellows';

  String get _footerText => _isNrrClub
      ? 'Founding history of Norwich Road Runners'
      : 'By Noel Spruce';

  IconData get _footerIcon => _isNrrClub ? Icons.groups : Icons.person;

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  Future<void> _loadClub() async {
    final clubName = await UserService.currentClubName();
    if (!mounted) return;
    setState(() {
      _clubName = clubName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Club History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            automaticallyImplyLeading: false,
            floating: false,
            pinned: true,
            expandedHeight: 520,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: _HistoryPhotoCarousel(
                        isNrrClub: _isNrrClub,
                        borderColor: _cardBorderColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Three glassy buttons in a single row
                    Row(
                      children: [
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.emoji_events_outlined,
                            label: 'Individual Records',
                            borderColor: _cardBorderColor,
                            iconColor: _primaryColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClubRecordsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.groups_outlined,
                            label: 'Team Awards',
                            borderColor: _cardBorderColor,
                            iconColor: _primaryColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeamAchievementsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.timeline_outlined,
                            label: 'Historical Milestones',
                            borderColor: _cardBorderColor,
                            iconColor: _primaryColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClubMilestonesPage(),
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
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(
                _headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (var i = 0; i < _sections.length; i++) ...[
                  _buildSection(
                    title: _sections[i].title,
                    content: _sections[i].content,
                  ),
                  if (i < _sections.length - 1) const SizedBox(height: 24),
                ],
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_footerIcon, color: _primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _footerText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _secondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _HistorySection {
  final String title;
  final String content;

  const _HistorySection({required this.title, required this.content});
}

class _HistoryPhotoCarousel extends StatefulWidget {
  const _HistoryPhotoCarousel({
    required this.isNrrClub,
    required this.borderColor,
  });

  final bool isNrrClub;
  final Color borderColor;

  @override
  State<_HistoryPhotoCarousel> createState() => _HistoryPhotoCarouselState();
}

class _HistoryPhotoCarouselState extends State<_HistoryPhotoCarousel> {
  int _currentPage = 0;
  Timer? _carouselTimer;

  List<String> get _imagePaths => widget.isNrrClub
      ? const [
          'assets/images/nrrhistory.png',
          'assets/images/nrr11.png',
          'assets/images/nrr12.png',
        ]
      : const [
          'assets/images/club_history_runner.jpg',
          'assets/images/nnbr_cover.png',
          'assets/images/nnbrdocs.png',
        ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _imagePaths.length < 2) {
        return;
      }

      setState(() {
        _currentPage = (_currentPage + 1) % _imagePaths.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.borderColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 900),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Container(
            key: ValueKey(_imagePaths[_currentPage]),
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              _imagePaths[_currentPage],
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color borderColor;
  final Color iconColor;

  const _GlassyButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.borderColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Glassy background
            Container(color: Colors.white.withValues(alpha: 0.06)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, color: iconColor, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            height: 1.1,
                          ),
                        ),
                      ],
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
