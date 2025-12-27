import 'dart:ui';
import 'package:flutter/material.dart';

class ClubMilestonesPage extends StatelessWidget {
  const ClubMilestonesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key moments and achievements that have shaped our club\'s journey over the years.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),

            _buildMilestone(
              year: 'Mid 1980s',
              title: 'Club Founded',
              description:
                  'Informal group begins running out of Cromer and East Runton',
              icon: Icons.flag,
            ),

            _buildMilestone(
              year: 'Early Days',
              title: 'First Female Members',
              description:
                  'The club welcomes its first two lady members, marking the beginning of a more inclusive community',
              icon: Icons.people,
            ),

            _buildMilestone(
              year: 'Evolution',
              title: 'Boxing Day Dip Tradition',
              description:
                  'Annual Boxing Day sea dip becomes a massive fundraising event for local charities',
              icon: Icons.waves,
            ),

            _buildMilestone(
              year: '2020s',
              title: 'Modern Era',
              description:
                  'Established as one of Norfolk\'s premier running clubs, welcoming runners of all abilities',
              icon: Icons.emoji_events,
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0055FF).withOpacity(0.3),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF0055FF),
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'More milestones coming soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestone({
    required String year,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0055FF), Color(0xFF00AAFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0055FF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              Container(
                width: 2,
                height: 60,
                color: Colors.white.withOpacity(0.2),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  year,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0055FF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
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
