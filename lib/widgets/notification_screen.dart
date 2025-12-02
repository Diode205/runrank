// lib/widgets/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:runrank/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadData();
    NotificationService.watchUnreadCount((_) => loadData());
  }

  Future<void> loadData() async {
    final data = await NotificationService.fetchNotifications();
    setState(() {
      notifications = data;
      loading = false;
    });

    // mark everything read
    await NotificationService.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(child: Text("No notifications yet"))
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final n = notifications[i];
                return ListTile(
                  title: Text(n['title'] ?? ''),
                  subtitle: Text(n['body'] ?? ''),
                  trailing: Text(
                    DateTime.parse(
                      n['created_at'],
                    ).toLocal().toString().substring(0, 16),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
