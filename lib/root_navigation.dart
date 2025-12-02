import 'package:flutter/material.dart';
import 'package:runrank/widgets/club_standards_view.dart';
import 'package:runrank/widgets/training_events_calendar.dart';
import 'package:runrank/notifications_screen.dart';
import 'package:runrank/menu_screen.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/app_routes.dart';

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _selectedIndex = 0;

  int _unread = 0;

  final List<Widget> _screens = const [
    ClubStandardsView(),
    TrainingEventsCalendar(),
    NotificationsScreen(),
    MenuScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnread();
    NotificationService.setListener((count) {
      setState(() => _unread = count);
    });
    NotificationService.listenRealtime();
  }

  Future<void> _loadUnread() async {
    final c = await NotificationService.unreadCount();
    setState(() => _unread = c);
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
