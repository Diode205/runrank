import 'package:flutter/material.dart';

class ContactNNBRPage extends StatelessWidget {
  const ContactNNBRPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact NNBR'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header photo
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/runners_group.JPG',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          const _ContactCard(
            label: 'General enquiries',
            detail: 'hello@nnbr.run',
            icon: Icons.email_outlined,
          ),
          const _ContactCard(
            label: 'Membership',
            detail: 'membership@nnbr.run',
            icon: Icons.badge_outlined,
          ),
          const _ContactCard(
            label: 'Club kit',
            detail: 'kit@nnbr.run',
            icon: Icons.shopping_bag_outlined,
          ),
          const _ContactCard(
            label: 'Press',
            detail: 'press@nnbr.run',
            icon: Icons.campaign_outlined,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;

  const _ContactCard({
    required this.label,
    required this.detail,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, size: 26),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(detail),
      ),
    );
  }
}
