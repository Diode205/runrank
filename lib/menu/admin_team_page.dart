import 'package:flutter/material.dart';

class AdministrativeTeamPage extends StatelessWidget {
  const AdministrativeTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrative Team'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TeamCard(title: 'Chair', name: 'TBD', email: 'chair@nnbr.run'),
          _TeamCard(
            title: 'Secretary',
            name: 'TBD',
            email: 'secretary@nnbr.run',
          ),
          _TeamCard(
            title: 'Treasurer',
            name: 'TBD',
            email: 'treasurer@nnbr.run',
          ),
          SizedBox(height: 12),
          Text(
            'Update these details in code or wire to CMS when available.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String title;
  final String name;
  final String email;

  const _TeamCard({
    required this.title,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.person_outline, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name),
            Text(email, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
