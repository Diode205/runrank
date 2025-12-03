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
    try {
      final data = await NotificationService.fetchNotifications();

      print("DEBUG: NotificationsScreen received: $data"); // 🔥 Add this

      await NotificationService.markAllRead(); // mark first

      if (!mounted) return;
      setState(() {
        notifications = data;
        loading = false;
      });
    } catch (e) {
      print("DEBUG ERROR in loadData(): $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("DEBUG: NotificationsScreen BUILD triggered");

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
