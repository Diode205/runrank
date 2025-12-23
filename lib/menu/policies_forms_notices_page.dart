import 'package:flutter/material.dart';

class PoliciesFormsNoticesPage extends StatelessWidget {
  const PoliciesFormsNoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policies, Forms, and Notices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Policies, forms, and club notices will appear here.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          Text(
            'If you need something that is not listed yet, please contact the Administrative Team.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
