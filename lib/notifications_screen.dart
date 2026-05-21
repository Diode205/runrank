import 'dart:async';

import 'package:flutter/material.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/event_details_page.dart';
import 'package:runrank/menu/malcolm_ball_award_page.dart';
import 'package:runrank/widgets/post_detail_page.dart';
import 'package:runrank/menu/policies_forms_notices_page.dart';
import 'package:runrank/menu/club_records_page.dart';
import 'package:runrank/menu/team_achievements_page.dart';
import 'package:runrank/menu/club_milestones_page.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];
  StreamSubscription<int>? _unreadSubscription;
  RealtimeChannel? _notificationsChannel;
  Timer? _refreshTimer;
  String? _clubName = UserService.cachedClubName;

  // Extract a route tag from text like: "[route:malcolm_ball_award] ..."
  String? _extractRoute(String text) {
    final match = RegExp(r"\[route:([\w\-/]+)\]").firstMatch(text);
    return match != null ? match.group(1) : null;
  }

  // Remove the route tag from the display text
  String _stripRouteTag(String text) {
    return text.replaceAll(RegExp(r"\[route:[^\]]+\]\s*"), "");
  }

  String? _normalizeClubRecordGenderRoute(String? value) {
    final gender = value?.trim().toUpperCase();
    if (gender == 'M' || gender == 'MALE' || gender == "MEN'S") return 'M';
    if (gender == 'F' || gender == 'FEMALE' || gender == "WOMEN'S") {
      return 'F';
    }
    return null;
  }

  Future<String?> _inferClubRecordGenderFromNotification({
    required String body,
    required String? distance,
  }) async {
    if (distance == null || distance.isEmpty) return null;
    final match = RegExp(r'^(.+?)\s+set a new\s+').firstMatch(body);
    final runnerName = match?.group(1)?.trim();
    if (runnerName == null || runnerName.isEmpty) return null;

    try {
      final currentClub = await UserService.currentClubName();
      final profileRows = await Supabase.instance.client
          .from('user_profiles')
          .select('gender, club')
          .eq('full_name', runnerName)
          .limit(10);
      for (final raw in profileRows as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final profileClub = NotificationService.canonicalClubName(
          row['club'] as String?,
        );
        if (currentClub != null &&
            profileClub != NotificationService.canonicalClubName(currentClub)) {
          continue;
        }
        final gender = _normalizeClubRecordGenderRoute(
          row['gender'] as String?,
        );
        if (gender != null) return gender;
      }

      final row = await Supabase.instance.client
          .from('club_records')
          .select('gender')
          .eq('distance', distance)
          .eq('runner_name', runnerName)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return _normalizeClubRecordGenderRoute(row?['gender'] as String?);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadClubName();
    loadData();

    // Listen for unread-count changes so the list refreshes
    _unreadSubscription = NotificationService.watchUnreadCountStream().listen((
      _,
    ) {
      // Whenever a notification is inserted/updated/deleted, reload the list
      if (mounted) {
        loadData();
      }
    });

    // Also subscribe directly to notifications table changes for this user
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      _notificationsChannel = supabase
          .channel('notifications_list_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (_) {
              if (mounted) {
                loadData();
              }
            },
          )
          .subscribe();
    }

    // Periodic fallback refresh in case realtime events are missed
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        loadData();
      }
    });
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    if (_notificationsChannel != null) {
      Supabase.instance.client.removeChannel(_notificationsChannel!);
    }
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadClubName() async {
    try {
      final name = await UserService.currentClubName();
      if (!mounted) return;
      setState(() {
        _clubName = name;
      });
    } catch (_) {
      // Best-effort only; fall back to default gradient on error.
    }
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

  Future<void> _confirmDeleteAllNotifications() async {
    if (notifications.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text(
          'This will tick and remove all notifications from your alerts bar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await NotificationService.deleteAllNotificationsForCurrentUser();
      if (!mounted) return;
      setState(() {
        notifications.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting all notifications: $e')),
      );
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final unread = notifications
        .where((n) => !(n['is_read'] ?? false))
        .toList();
    if (unread.isEmpty) return;

    try {
      await NotificationService.markAllRead();
      await NotificationService.refreshUnreadCount();

      if (!mounted) return;
      setState(() {
        notifications = notifications
            .map((n) => {...n, 'is_read': true})
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notifications as read: $e')),
      );
    }
  }

  Future<void> _markAsReadAndNavigate(Map<String, dynamic> notification) async {
    final dynamic rawEventId = notification['event_id'];
    final String? eventId = rawEventId == null ? null : rawEventId.toString();
    final dynamic rawNotificationId = notification['id'];
    final String? notificationId = rawNotificationId == null
        ? null
        : rawNotificationId.toString();
    final title = (notification['title'] ?? '').toString();
    final rawBody = (notification['body'] ?? '').toString();
    final body = _stripRouteTag(rawBody);

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

    // First, if route tag is present, use it
    final route = _extractRoute(rawBody);
    if (route != null) {
      if (!mounted) return;

      if (route == 'malcolm_ball_award') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MalcolmBallAwardPage()),
        ).then((_) => loadData());
        return;
      }

      if (route == 'club_committee') {
        // For committee messages (including account deletion
        // requests), show the full text and optionally allow
        // sending an acknowledgement email to the member.
        String? ackEmail;
        String? ackName;

        if (title == 'Account deletion requested') {
          final match = RegExp(
            r'^(.+?)\s+\(([^)]+)\)\s+has requested',
          ).firstMatch(body);
          if (match != null) {
            final name = match.group(1)?.trim();
            final email = match.group(2)?.trim();
            if (email != null && email.contains('@')) {
              ackEmail = email;
            }
            if (name != null && name.isNotEmpty) {
              ackName = name;
            }
          }
        }

        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F111A),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SingleChildScrollView(
                child: Text(
                  body,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ),
              actions: [
                if (ackEmail != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final subject =
                          'RunRank account deletion request – acknowledgement';
                      final namePart = ackName != null
                          ? 'Hi $ackName,'
                          : 'Hello,';
                      final bodyText =
                          '$namePart\n\nThank you for your request to delete your RunRank club account. '
                          'We will aim to complete this within seven (7) days of your original request, '
                          'in line with club policy. If you change your mind within this 7-day window, '
                          'please contact your club admins to cancel the request.\n\nYour Admin Team';
                      await _composeEmail(
                        to: ackEmail,
                        subject: subject,
                        body: bodyText,
                      );
                    },
                    child: const Text('Send acknowledgement email'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
        await loadData();
        return;
      }

      if (route.startsWith('club_records')) {
        // Route may be:
        // - club_records
        // - club_records/<distance>
        // - club_records/<distance>/<gender>
        String? initialDistance;
        String? initialGender;
        final parts = route.split('/');
        if (parts.length > 1 && parts[1].isNotEmpty) {
          // Decode distance token (e.g. 'Half_M' -> 'Half M')
          initialDistance = parts[1].replaceAll('_', ' ');
        }
        if (parts.length > 2 && parts[2].isNotEmpty) {
          initialGender = _normalizeClubRecordGenderRoute(parts[2]);
        }
        initialGender ??= await _inferClubRecordGenderFromNotification(
          body: body,
          distance: initialDistance,
        );
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubRecordsPage(
              initialDistance: initialDistance,
              initialGender: initialGender,
            ),
          ),
        ).then((_) => loadData());
        return;
      }

      if (route == 'team_achievements') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeamAchievementsPage()),
        ).then((_) => loadData());
        return;
      }

      if (route == 'club_milestones') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClubMilestonesPage()),
        ).then((_) => loadData());
        return;
      }

      // Deep-link to a specific post when route encodes a post ID
      if (route.startsWith('post_')) {
        final postId = route.substring('post_'.length);
        if (postId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PostDetailPage(postId: postId, initialClubName: _clubName),
            ),
          ).then((_) => loadData());
          return;
        }
      }

      // Deep-link to policies screen when route is 'policies'
      if (route == 'policies') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PoliciesFormsNoticesPage()),
        ).then((_) => loadData());
        return;
      }
    }

    // Navigate to event if eventId exists. For host/coach messages,
    // deep-link straight into the private chat sheet.
    if (eventId != null && eventId.isNotEmpty) {
      final isHostMessage = title.toLowerCase().startsWith('new message about');
      await _navigateToEvent(eventId, openHostChat: isHostMessage);
      return;
    }

    // Malcolm Ball Award: comment notifications have title 'New Comment' and no event_id
    if (title.toLowerCase() == 'new comment' &&
        (eventId == null || eventId.isEmpty)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MalcolmBallAwardPage()),
      ).then((_) => loadData());
      return;
    }

    // Navigate to Malcolm Ball Award page if notification relates to it
    final text = '${title.toLowerCase()} ${body.toLowerCase()}';
    if (text.contains('malcolm ball')) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MalcolmBallAwardPage()),
      ).then((_) {
        // Refresh when coming back
        loadData();
      });
      return;
    }
  }

  Future<void> _composeEmail({
    String? to,
    required String subject,
    String? body,
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = body != null && body.isNotEmpty
        ? Uri.encodeComponent(body)
        : null;
    final query = [
      'subject=$encodedSubject',
      if (encodedBody != null) 'body=$encodedBody',
    ].join('&');

    final uri = Uri(scheme: 'mailto', path: to, query: query);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _navigateToEvent(
    String eventId, {
    bool openHostChat = false,
  }) async {
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
        MaterialPageRoute(
          builder: (_) =>
              EventDetailsPage(event: event, openHostChat: openHostChat),
        ),
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

  Color _alertAccentColor() {
    final lower = (_clubName ?? '').toLowerCase();
    if (lower.isEmpty) {
      return const Color(0xFF3A3A3A);
    }
    if (lower.contains('norwich road runners')) {
      return const Color(0xFFD32F2F); // NRR red
    }
    return const Color(0xFF0057B7); // NNBR blue / default
  }

  @override
  Widget build(BuildContext context) {
    final brandColors = UserService.clubBrandGradient(_clubName);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!loading && notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markAllNotificationsRead,
            ),
          if (!loading && notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete all notifications',
              onPressed: _confirmDeleteAllNotifications,
            ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: brandColors,
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
                final dynamic rawId = n['id'];
                final String? notificationId = rawId == null
                    ? null
                    : rawId.toString();
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
                              : _alertAccentColor().withOpacity(0.5),
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
                                        color: _alertAccentColor(),
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
                                    _stripRouteTag(body),
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
