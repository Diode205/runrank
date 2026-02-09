import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/widgets/club_standards_view.dart';
import 'package:runrank/widgets/club_events_calendar.dart';
import 'package:runrank/posts_feed_facebook.dart';
import 'package:runrank/notifications_screen.dart';
import 'package:runrank/menu_screen.dart';
import 'package:runrank/services/notification_service.dart';

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _unread = 0;
  int _postActivityCount = 0;

  // Track which tabs have been visited to load them lazily
  final List<bool> _activatedTabs = [true, false, false, false, false];

  Timer? _postActivityTimer;
  StreamSubscription<int>? _unreadSubscription;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _loadInitialUnreadCount();

    _unreadSubscription = NotificationService.watchUnreadCountStream().listen((count) {
      if (mounted) setState(() => _unread = count);
    });

    _setupPostActivityListener();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _glowController.dispose();
    _postActivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialUnreadCount() async {
    final count = await NotificationService.unreadCount();
    if (mounted) setState(() => _unread = count);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _activatedTabs[index] = true; // Activate the tab the first time it's clicked
      if (index == 2) _postActivityCount = 0;
    });
  }

  Future<void> _setupPostActivityListener() async {
    final supabase = Supabase.instance.client;
    // Simple listener for badges, much lighter than the full feed logic
    supabase.channel('public:club_posts').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'club_posts',
      callback: (_) {
        if (mounted && _selectedIndex != 2) setState(() => _postActivityCount++);
      },
    ).subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _activatedTabs[0] ? const ClubStandardsView() : const SizedBox.shrink(),
          _activatedTabs[1] ? const ClubEventsCalendar() : const SizedBox.shrink(),
          _activatedTabs[2] ? const PostsFeedFacebookScreen() : const SizedBox.shrink(),
          _activatedTabs[3] ? const NotificationsScreen() : const SizedBox.shrink(),
          _activatedTabs[4] ? const MenuScreen() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.directions_run_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.directions_run, color: Colors.white),
            label: 'RunHome',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.groups, color: Colors.white),
            label: 'Club Hub',
          ),
          NavigationDestination(
            icon: _buildBadgeIcon(Icons.article_outlined, _postActivityCount, Colors.amber),
            selectedIcon: _buildBadgeIcon(Icons.article, _postActivityCount, Colors.amber),
            label: 'Posts',
          ),
          NavigationDestination(
            icon: _buildBadgeIcon(Icons.notifications_outlined, _unread, Colors.redAccent),
            selectedIcon: _buildBadgeIcon(Icons.notifications, _unread, Colors.redAccent),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu, color: Colors.white70),
            selectedIcon: Icon(Icons.menu, color: Colors.white),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count, Color color) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: count > 0
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: _glowAnimation.value,
                          spreadRadius: _glowAnimation.value * 0.4,
                        ),
                      ],
                    )
                  : null,
              child: Icon(icon, color: count > 0 ? color : Colors.white70),
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
