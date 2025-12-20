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
  }

  Future<void> loadData() async {
    try {
      print("DEBUG: Loading notifications...");

      final data = await NotificationService.fetchNotifications();

      print("DEBUG: NotificationsScreen received: $data");

      await NotificationService.markAllRead();

      if (!mounted) return;

      setState(() {
        notifications = data;
        loading = false;
      });
    } catch (e) {
      print("DEBUG ERROR in loadData(): $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _getNotificationIcon(String title) {
    if (title.contains('Event')) return '📅';
    if (title.contains('Response') || title.contains('joined')) return '👤';
    if (title.contains('Cancelled')) return '❌';
    if (title.contains('Deleted')) return '🗑️';
    if (title.contains('Comment')) return '💬';
    if (title.contains('Marshal')) return '🦺';
    return '🔔';
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey[900],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Stay tuned for event updates",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final n = notifications[i];
                final title = n['title'] ?? '';
                final body = n['body'] ?? '';
                final createdAt = n['created_at'] as String?;
                final icon = _getNotificationIcon(title);
                final timeAgo = _formatDateTime(createdAt);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  color: Colors.grey[800],
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[800]!,
                          Colors.grey[850] ?? Colors.grey[800]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.5),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chevron
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
