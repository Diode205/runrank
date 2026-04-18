import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/menu/club_records_page.dart';
import 'package:runrank/menu/club_milestones_page.dart';
import 'package:runrank/menu/team_achievements_page.dart';

class ClubHistoryPage extends StatelessWidget {
  const ClubHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            floating: false,
            pinned: true,
            expandedHeight: 490,
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
                      child: _HistoryPhotoCarousel(colorScheme: colorScheme),
                    ),

                    const SizedBox(height: 16),

                    // Three glassy buttons in a single row
                    Row(
                      children: [
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.emoji_events_outlined,
                            label: 'Individual Records',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClubRecordsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.groups_outlined,
                            label: 'Team Awards',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TeamAchievementsPage(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.timeline_outlined,
                            label: 'Historical Milestones',
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
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Text(
                'Brief History Of The\nRoad Runners',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection(
                  title: 'The Early Group',
                  content:
                      'Ray Lindsey, Mark Futter and Stephen Sadd were running together in 1982 under the banner of Fitt Signs. They were joined by Stephen Dixon in mid 1982 and definitely by the Fakenham 10 mile race on 11 July 1982.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Midnight Runners',
                  content:
                      'For a brief period they ran under the banner of Midnight Runners and the results from the second Norfolk Marathon in September 1983 show that the Midnight Runners came fourth non-affiliated team: S. Dixon 3:27:04, M. Futter 3:27:06, R. Lindsay 3:31:56 and S. Sadd 4:01:58.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'The Wider Group Forms',
                  content:
                      'At the same time as this, but independently, Michael Betts had started running and, as he lived in the same road as Richard Sales in Thurling Plain, they started running together. They too ran the second Norfolk Marathon, where Richard Sales recorded 3:02:42 and Mick Betts 3:08:58, and it was there that they first met the others. It was also there that Mick Betts met up again with Ivan Loades, who he had known in childhood, and Ivan ran 3:12:33.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Becoming Norwich Road Runners',
                  content:
                      'The six of us, Mick Betts, Stephen Dixon, Mike Futter, Ray Lindsey, Ivan Loades and Richard Sales, met more regularly. Later, in order to attract more members and keep our best runners, we made a group decision to change the name from Midnight Runners to Norwich Road Runners.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Founding Members',
                  content:
                      'The club therefore has six founding members: Mick Betts, Stephen Dixon, Mike Futter, Ray Lindsey, Ivan Loades and Richard Sales. This took place in late 1983 to early 1984, with the first printed record being the second Ipswich Marathon on 9 September 1984, although it is possible we ran under the club name earlier in 1984.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Affiliation And Growth',
                  content:
                      'The club was growing and so we started running from The Crome Recreation Centre on Crome Road, now demolished, and later in 1985 the club became affiliated, with Mick Betts becoming the first club secretary. The rest, as they say, is history.',
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Founding history of Norwich Road Runners',
                        style: TextStyle(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
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
        Builder(
          builder: (context) => Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
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

class _HistoryPhotoCarousel extends StatefulWidget {
  const _HistoryPhotoCarousel({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  State<_HistoryPhotoCarousel> createState() => _HistoryPhotoCarouselState();
}

class _HistoryPhotoCarouselState extends State<_HistoryPhotoCarousel> {
  int _currentPage = 0;
  Timer? _carouselTimer;

  static const List<String> _imagePaths = [
    'assets/images/nrrhistory.png',
    'assets/images/nrr11.png',
    'assets/images/nrr12.png',
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
        border: Border.all(color: widget.colorScheme.primary, width: 2),
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

  const _GlassyButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary, width: 1.5),
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
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, color: colorScheme.primary, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
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
