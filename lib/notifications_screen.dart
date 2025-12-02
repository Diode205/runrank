import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: const Center(
        child: Text(
          'No notifications yet.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }
}
