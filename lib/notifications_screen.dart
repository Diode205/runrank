import 'package:flutter/material.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/event_details_page.dart';

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

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('notifications').delete().eq('id', notificationId);

      // Refresh the unread count badge
      await NotificationService.refreshUnreadCount();

      setState(() {
        notifications.removeWhere((n) => n['id'] == notificationId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting notification: $e")),
      );
    }
  }

  Future<void> _markAsReadAndNavigate(Map<String, dynamic> notification) async {
    final eventId = notification['event_id'] as String?;
    final notificationId = notification['id'] as String?;

    // Mark as read
    if (notificationId != null && !(notification['is_read'] ?? false)) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);

        // Refresh the unread count badge
        await NotificationService.refreshUnreadCount();
      } catch (e) {
        print("Error marking notification as read: $e");
      }
    }

    // Navigate to event if eventId exists
    if (eventId != null && eventId.isNotEmpty) {
      await _navigateToEvent(eventId);
    }
  }

  Future<void> _navigateToEvent(String eventId) async {
    try {
      final supabase = Supabase.instance.client;
      final eventData = await supabase
          .from('club_events')
          .select()
          .eq('id', eventId)
          .single();

      if (!mounted) return;

      final event = ClubEvent.fromSupabase(eventData);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailsPage(event: event)),
      ).then((_) {
        // Refresh when coming back
        loadData();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Event not found")));
    }
  }

  String _getNotificationIcon(String title) {
    if (title.contains('Event')) return '📅';
    if (title.contains('Response') || title.contains('joined')) return '��';
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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                final notificationId = n['id'] as String?;
                final title = n['title'] ?? '';
                final body = n['body'] ?? '';
                final createdAt = n['created_at'] as String?;
                final isRead = n['is_read'] ?? false;
                final icon = _getNotificationIcon(title);
                final timeAgo = _formatDateTime(createdAt);

                return Dismissible(
                  key: Key(notificationId ?? 'notification_$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  onDismissed: (direction) {
                    if (notificationId != null) {
                      _deleteNotification(notificationId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Notification deleted"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: GestureDetector(
                    onTap: () => _markAsReadAndNavigate(n),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRead
                              ? Colors.white.withOpacity(0.1)
                              : Colors.blue.withOpacity(0.3),
                          width: isRead ? 1 : 2,
                        ),
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
                            // Icon with unread indicator
                            Stack(
                              children: [
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
                                if (!isRead)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[800]!,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
                                      fontWeight: isRead
                                          ? FontWeight.w500
                                          : FontWeight.w600,
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
                    ),
                  ),
                );
              },
            ),
    );
  }
}
