import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:runrank/menu/club_records_page.dart';
import 'package:runrank/menu/club_milestones_page.dart';

class ClubHistoryPage extends StatelessWidget {
  const ClubHistoryPage({super.key});

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
            floating: false,
            pinned: true,
            toolbarHeight: 390,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header photo (asset) replacing the yellow placeholder
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF0055FF),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/club_history_runner.jpg',
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Two slightly glassy buttons: Records & Milestones
                    Row(
                      children: [
                        Expanded(
                          child: _GlassyButton(
                            icon: Icons.emoji_events_outlined,
                            label: 'Records',
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
                            icon: Icons.timeline_outlined,
                            label: 'Milestones',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Text(
                'Brief History of the Blue and Yellows',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 237, 244, 15),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSection(
                  title: 'The Beginning',
                  content:
                      'The Club began in the mid eighties with an informal group '
                      'running out of Cromer and East Runton, before settling on Cromer '
                      'as its base if for no other reason than it was, and still is, a '
                      'superb place to launch yourself into the North Sea on Boxing Day, '
                      'a tradition which has grown to the massive event which it is today, '
                      'raising thousands of pounds for mainly local charities and other good causes.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Early Days',
                  content:
                      'From a focussed racing group of just one tenth of the Club\'s '
                      'current membership, with not a female member in sight, we\'ve grown '
                      'steadily into a running club for all ages and abilities. Our income '
                      'was frugal, to say the least, coming from modest subs augmented by '
                      'income from our Holt 5 annual Road Race, later to become a 7 miler '
                      'for a time before changing again into the 10K it is today.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Growth & Evolution',
                  content:
                      'Like many things in this life, you can\'t keep a good thing down – '
                      'the Club grew, and grew while keeping its friendliness. We gained our '
                      'first two lady members, one of whom was to wed the only Club coach we '
                      'had (Graham Davidson), a female section was to appear, proving only too '
                      'ready to give the men a real run for their money whilst also making us '
                      'into a far less chauvinistic membership and a more balanced and agreeable organisation.',
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: 'Today',
                  content:
                      'Today you find one of the best established, and certainly one of '
                      'the county\'s finest running clubs where you\'ll find a genuine welcome '
                      'as a new member whatever your level of interest or involvement!',
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person, color: Color(0xFFFFD700), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'By Noel Spruce',
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
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0055FF),
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
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0055FF), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Glassy background
            Container(color: Colors.white.withOpacity(0.06)),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(icon, color: const Color(0xFFFFD700)),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
