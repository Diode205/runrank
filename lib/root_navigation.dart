import 'package:flutter/material.dart';
import 'package:runrank/widgets/club_standards_view.dart';
import 'package:runrank/widgets/training_events_calendar.dart';
import 'package:runrank/notifications_screen.dart';
import 'package:runrank/menu_screen.dart';
import 'package:runrank/services/notification_service.dart';

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _selectedIndex = 0;
  int _unread = 0;

  final List<Widget> _screens = [
    ClubStandardsView(),
    TrainingEventsCalendar(),
    NotificationsScreen(),
    MenuScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Initial load
    _loadUnread();

    // Live listener
    NotificationService.watchUnreadCount((count) {
      if (mounted) {
        setState(() => _unread = count);
      }
    });
  }

  Future<void> _loadUnread() async {
    final count = await NotificationService.unreadCount();
    setState(() => _unread = count);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'RunHome',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Club Hub',
          ),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }
}
