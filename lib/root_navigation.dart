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

class _RootNavigationState extends State<RootNavigation>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _unread = 0;

  final List<Widget> _screens = [
    ClubStandardsView(),
    TrainingEventsCalendar(),
    NotificationsScreen(),
    MenuScreen(),
  ];
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // pulsing glow

    _glowAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
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
          NavigationDestination(
            icon: Icon(
              Icons.directions_run_outlined,
              color: const Color.fromARGB(221, 233, 232, 237),
            ),
            selectedIcon: Icon(
              Icons.directions_run,
              color: Color.fromARGB(255, 246, 245, 239),
            ),
            label: 'RunHome',
          ),
          const NavigationDestination(
            icon: Icon(
              Icons.groups_outlined,
              color: Color.fromARGB(240, 236, 240, 236),
            ),
            selectedIcon: Icon(
              Icons.groups,
              color: Color.fromARGB(255, 234, 234, 239),
            ),
            label: 'Club Hub',
          ),
          NavigationDestination(
            icon: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 🔥 GLOW EFFECT around icon only when unread > 0
                    Container(
                      decoration: _unread > 0
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.6),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: _glowAnimation.value * 0.6,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        _unread > 0
                            ? Icons.notifications
                            : Icons.notifications_outlined,
                        color: _unread > 0
                            ? Colors.redAccent
                            : Colors.grey.shade300,
                      ),
                    ),

                    if (_unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
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
                );
              },
            ),

            selectedIcon: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: _unread > 0
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.6),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: _glowAnimation.value * 0.6,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        Icons.notifications,
                        color: _unread > 0 ? Colors.redAccent : Colors.white,
                      ),
                    ),

                    if (_unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
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
                );
              },
            ),

            label: 'Alerts',
          ),

          const NavigationDestination(
            icon: Icon(Icons.menu, color: Color.fromARGB(255, 236, 234, 234)),
            selectedIcon: Icon(
              Icons.directions_run,
              color: Color.fromARGB(255, 239, 236, 236),
            ),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
