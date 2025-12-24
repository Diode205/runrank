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
  DateTime _postLastSeen = DateTime.now();

  Timer? _postActivityTimer;

  final List<Widget> _screens = [
    ClubStandardsView(),
    ClubEventsCalendar(),
    PostsFeedFacebookScreen(),
    NotificationsScreen(),
    MenuScreen(),
  ];
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late Stream<int> _unreadStream;

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

    // Load initial unread count
    _loadInitialUnreadCount();

    // Set up real-time unread count stream
    _unreadStream = NotificationService.watchUnreadCountStream();
    _unreadStream.listen((count) {
      print("DEBUG: Unread count updated to: $count");
      if (mounted) {
        setState(() => _unread = count);
      }
    });

    // Set up real-time post activity listener
    _setupPostActivityListener();

    // Fallback polling in case Realtime is unavailable
    _postActivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _pollPostActivity(),
    );
  }

  Future<void> _setupPostActivityListener() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      debugPrint('RootNav: Setting up post activity listener...');

      // Listen for new posts
      supabase
          .channel('public:club_posts')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'club_posts',
            callback: (payload) {
              debugPrint(
                'RootNav: New post detected! _selectedIndex=$_selectedIndex',
              );
              if (mounted && _selectedIndex != 2) {
                setState(() => _postActivityCount++);
              }
            },
          )
          .subscribe();

      debugPrint('RootNav: club_posts subscription active');

      // Listen for new reactions
      supabase
          .channel('public:club_post_reactions')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'club_post_reactions',
            callback: (payload) {
              if (mounted && _selectedIndex != 2) {
                setState(() => _postActivityCount++);
              }
            },
          )
          .subscribe();

      // Listen for new comments
      supabase
          .channel('public:club_post_comments')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'club_post_comments',
            callback: (payload) {
              if (mounted && _selectedIndex != 2) {
                setState(() => _postActivityCount++);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('RootNav: Error setting up post activity listener: $e');
    }
  }

  Future<void> _loadInitialUnreadCount() async {
    final count = await NotificationService.unreadCount();
    print("DEBUG: Initial unread count: $count");
    if (mounted) {
      setState(() => _unread = count);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _postActivityTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Clear post activity badge when Posts tab is selected
      if (index == 2) {
        _postActivityCount = 0;
        _postLastSeen = DateTime.now();
      }
    });
  }

  Future<void> _pollPostActivity() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final since = _postLastSeen.toIso8601String();
    try {
      // New posts the user can see (approved, or authored by user)
      final postsData = await supabase
          .from('club_posts')
          .select('id')
          .gte('created_at', since)
          .or('is_approved.eq.true,author_id.eq.${user.id}');

      // New reactions since last check
      final reactionsData = await supabase
          .from('club_post_reactions')
          .select('id, post_id')
          .gte('created_at', since);

      // New comments since last check
      final commentsData = await supabase
          .from('club_post_comments')
          .select('id, post_id')
          .gte('created_at', since);

      final newCount =
          (postsData as List).length +
          reactionsData.length +
          commentsData.length;

      if (mounted) {
        setState(() {
          _postLastSeen = DateTime.now();
          if (_selectedIndex != 2 && newCount > 0) {
            _postActivityCount += newCount;
          } else if (_selectedIndex == 2) {
            _postActivityCount = 0;
          }
        });
      }
    } catch (e) {
      print('Poll post activity error: $e');
    }
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
                    Container(
                      decoration: _postActivityCount > 0
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.6),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: _glowAnimation.value * 0.6,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        Icons.article_outlined,
                        color: _postActivityCount > 0
                            ? Colors.amber
                            : const Color.fromARGB(240, 236, 240, 236),
                      ),
                    ),
                    if (_postActivityCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _postActivityCount.toString(),
                            style: const TextStyle(
                              color: Colors.black87,
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
                      decoration: _postActivityCount > 0
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.6),
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: _glowAnimation.value * 0.6,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        Icons.article,
                        color: _postActivityCount > 0
                            ? Colors.amber
                            : const Color.fromARGB(255, 234, 234, 239),
                      ),
                    ),
                    if (_postActivityCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _postActivityCount.toString(),
                            style: const TextStyle(
                              color: Colors.black87,
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
            label: 'Posts',
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
              Icons.menu,
              color: Color.fromARGB(255, 239, 236, 236),
            ),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
