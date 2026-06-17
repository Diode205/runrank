import 'dart:async';
import 'package:flutter/material.dart';
import 'package:runrank/widgets/club_standards_view.dart';
import 'package:runrank/widgets/club_events_calendar.dart';
import 'package:runrank/posts_feed_facebook.dart';
import 'package:runrank/notifications_screen.dart';
import 'package:runrank/menu_screen.dart';
import 'package:runrank/chat/chat_list_page.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:runrank/services/chat_service.dart';
import 'package:runrank/services/membership_renewal_reminder_service.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/user_service.dart';

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
  int _eventActivityCount = 0;
  int _chatUnreadCount = 0;
  int _clubHubRefreshToken = 0;
  Color _chatAccent = const Color(0xFF2E7D32);
  MembershipRenewalReminderStatus _renewalReminderStatus =
      MembershipRenewalReminderStatus.inactive();

  // Track which tabs have been visited to load them lazily
  final List<bool> _activatedTabs = [true, false, false, false, false];

  StreamSubscription<int>? _unreadSubscription;
  StreamSubscription<int>? _eventActivitySubscription;
  Timer? _unreadPollTimer;
  Timer? _eventPollTimer;
  Timer? _postPollTimer;
  Timer? _chatPollTimer;
  Timer? _renewalReminderPollTimer;

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
    _loadInitialEventActivityCount();
    _loadInitialPostActivityCount();
    _loadInitialChatUnreadCount();
    _loadChatAccent();
    _loadRenewalReminderStatus();

    _unreadSubscription = NotificationService.watchUnreadCountStream().listen((
      count,
    ) {
      if (!mounted) return;
      setState(() => _unread = count);
    });

    // Periodic fallback in case realtime updates are missed
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      final count = await NotificationService.unreadCount();
      if (mounted) {
        setState(() => _unread = count);
      }
    });

    // Periodic fallback for event activity badge so that Club Hub
    // counters stay in sync even if this client missed realtime
    // updates (or hasn't opened the Club Hub tab yet).
    _eventPollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      final count = await NotificationService.unseenEventCount();
      if (mounted) {
        debugPrint(
          'RootNavigation: event poll -> unseenEventCount=$count (was $_eventActivityCount)',
        );
        setState(() => _eventActivityCount = count);
      }
    });

    // Periodic poll for post activity so the Posts badge highlights
    // when there are newer posts for this club on any device.
    _postPollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      final count = await NotificationService.unseenPostActivityCount();
      if (mounted) {
        debugPrint(
          'RootNavigation: post poll -> unseenPostActivityCount=$count (was $_postActivityCount)',
        );
        setState(() => _postActivityCount = count);
      }
    });

    _chatPollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      final count = await ChatService.unreadCount();
      if (mounted) {
        setState(() => _chatUnreadCount = count);
      }
    });

    _renewalReminderPollTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _loadRenewalReminderStatus(),
    );

    // Watch for event activity (unseen events) to highlight Club Hub
    _eventActivitySubscription = NotificationService.watchEventActivityStream()
        .listen((count) {
          if (!mounted) return;
          setState(() {
            _eventActivityCount = count;
            debugPrint(
              'RootNavigation: event activity count updated -> $_eventActivityCount',
            );
          });
        });
  }

  Future<void> _loadChatAccent() async {
    final clubName = await UserService.currentClubName();
    if (!mounted) return;
    setState(() {
      _chatAccent = UserService.clubPrimaryColor(clubName);
    });
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _unreadPollTimer?.cancel();
    _glowController.dispose();
    _eventActivitySubscription?.cancel();
    _eventPollTimer?.cancel();
    _postPollTimer?.cancel();
    _chatPollTimer?.cancel();
    _renewalReminderPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialUnreadCount() async {
    final count = await NotificationService.unreadCount();
    if (mounted) setState(() => _unread = count);
  }

  Future<void> _loadInitialEventActivityCount() async {
    final count = await NotificationService.unseenEventCount();
    if (mounted) setState(() => _eventActivityCount = count);
  }

  Future<void> _loadInitialPostActivityCount() async {
    final count = await NotificationService.unseenPostActivityCount();
    if (mounted) {
      debugPrint('RootNavigation: initial unseenPostActivityCount=$count');
      setState(() => _postActivityCount = count);
    }
  }

  Future<void> _loadInitialChatUnreadCount() async {
    final count = await ChatService.unreadCount();
    if (mounted) setState(() => _chatUnreadCount = count);
  }

  Future<void> _loadRenewalReminderStatus() async {
    final status = await MembershipRenewalReminderService.status();
    if (!mounted) return;
    setState(() => _renewalReminderStatus = status);
  }

  Future<void> _openChat() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatListPage()));
    _loadInitialChatUnreadCount();
  }

  Future<void> _openRenewalReminder() async {
    final status = _renewalReminderStatus;
    final daysText = status.daysRemaining == 1
        ? '1 day'
        : '${status.daysRemaining} days';

    final openMembership = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Membership renewal'),
          content: Text(
            'Your club membership renewal is still outstanding. There are $daysText left before the England Athletics renewal window closes on 30 June.\n\nOnce the Membership Secretary marks you renewed, this reminder will disappear.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Membership'),
            ),
          ],
        );
      },
    );

    if (openMembership == true && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MembershipPage()));
      _loadRenewalReminderStatus();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _activatedTabs[index] =
          true; // Activate the tab the first time it's clicked
      if (index == 1) {
        _clubHubRefreshToken++;
      }
      if (index == 2) {
        _postActivityCount = 0;
        // Mark posts as seen so subsequent polls don't
        // immediately re-highlight the tab.
        NotificationService.markPostsSeen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _activatedTabs[0]
                  ? const ClubStandardsView()
                  : const SizedBox.shrink(),
              _activatedTabs[1]
                  ? ClubEventsCalendar(refreshToken: _clubHubRefreshToken)
                  : const SizedBox.shrink(),
              _activatedTabs[2]
                  ? const PostsFeedFacebookScreen()
                  : const SizedBox.shrink(),
              _activatedTabs[3]
                  ? const NotificationsScreen()
                  : const SizedBox.shrink(),
              _activatedTabs[4] ? const MenuScreen() : const SizedBox.shrink(),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 20,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 78),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_renewalReminderStatus.isActive) ...[
                    _buildRenewalCountdownButton(_renewalReminderStatus),
                    const SizedBox(height: 12),
                  ],
                  _buildFloatingChatButton(),
                ],
              ),
            ),
          ),
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
          NavigationDestination(
            icon: _buildBadgeIcon(
              Icons.groups_outlined,
              _eventActivityCount,
              const Color(0xFF0057B7), // club blue
            ),
            selectedIcon: _buildBadgeIcon(
              Icons.groups,
              _eventActivityCount,
              const Color(0xFF0057B7),
            ),
            label: 'ClubHub',
          ),
          NavigationDestination(
            icon: _buildBadgeIcon(
              Icons.article_outlined,
              _postActivityCount,
              Colors.amber,
            ),
            selectedIcon: _buildBadgeIcon(
              Icons.article,
              _postActivityCount,
              Colors.amber,
            ),
            label: 'Posts',
          ),
          NavigationDestination(
            icon: _buildBadgeIcon(
              Icons.notifications_outlined,
              _unread,
              Colors.redAccent,
            ),
            selectedIcon: _buildBadgeIcon(
              Icons.notifications,
              _unread,
              Colors.redAccent,
            ),
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

  Widget _buildFloatingChatButton() {
    final color = _chatAccent;
    final buttonColor = color.withValues(alpha: 0.78);
    final foreground = UserService.readableOn(color);
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: _chatUnreadCount > 0
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: _glowAnimation.value + 8,
                          spreadRadius: _glowAnimation.value * 0.35,
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: FloatingActionButton(
                heroTag: 'global_chat_button',
                mini: true,
                backgroundColor: buttonColor,
                foregroundColor: foreground,
                onPressed: _openChat,
                tooltip: 'Chat',
                child: const Icon(Icons.chat_bubble_rounded),
              ),
            ),
            if (_chatUnreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _chatUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRenewalCountdownButton(MembershipRenewalReminderStatus status) {
    const color = Color(0xFFFFC107);
    final digitColor = status.daysRemaining < 10
        ? Colors.redAccent.shade700
        : Colors.black;
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: _glowAnimation.value + 10,
                spreadRadius: _glowAnimation.value * 0.4,
              ),
            ],
          ),
          child: FloatingActionButton.small(
            heroTag: 'membership_renewal_countdown',
            backgroundColor: color.withValues(alpha: 0.92),
            foregroundColor: Colors.black,
            tooltip: 'Membership renewal reminder',
            onPressed: _openRenewalReminder,
            child: Text(
              status.daysRemaining.toString(),
              style: TextStyle(
                color: digitColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
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
                          color: color.withValues(alpha: 0.4),
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
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
