import 'package:flutter/material.dart';

class RacesEacclPage extends StatelessWidget {
  const RacesEacclPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Races and EACCL'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeading('Upcoming fixtures'),
          _PlaceholderCard('Add race list here'),
          SizedBox(height: 16),
          _SectionHeading('Results'),
          _PlaceholderCard('Post results and links here'),
          SizedBox(height: 16),
          _SectionHeading('EACCL league'),
          _PlaceholderCard('League fixtures, standings, and sign-ups'),
          SizedBox(height: 24),
          Text(
            'Replace these placeholders when data/API is ready.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String label;
  const _PlaceholderCard(this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.upcoming, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
