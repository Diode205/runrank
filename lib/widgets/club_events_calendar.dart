import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/event_details_page.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
import 'package:runrank/widgets/admin_edit_event_page.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/weather_service.dart';
import 'package:runrank/services/user_service.dart';

/// =============================================================
/// CLUB EVENTS CALENDAR — unified for all event types
/// =============================================================
class ClubEventsCalendar extends StatefulWidget {
  const ClubEventsCalendar({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  State<ClubEventsCalendar> createState() => _ClubEventsCalendarState();
}

class _ClubEventsCalendarState extends State<ClubEventsCalendar> {
  final supabase = Supabase.instance.client;

  List<ClubEvent> _events = [];
  bool _loading = true;
  String userRole = "social"; // social or admin

  // Per-event weather cache for upcoming events so we can show
  // a small forecast next to the time on each calendar card.
  final Map<String, WeatherAtTime?> _eventWeather = {};
  final Set<String> _weatherRequested = {};

  String? _clubName = UserService.cachedClubName;
  Set<String> _clubUserIds = {};

  // Track which event cards have been opened/seen locally
  Set<String> _seenEventIds = {};

  RealtimeChannel? _eventsChannel;
  Timer? _eventsPollTimer;
  DateTime? _lastCleanupAt;

  Future<void> _loadSeenEvents() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'events_seen_ids_${user.id}';
      final list = prefs.getStringList(key) ?? <String>[];
      if (mounted) {
        setState(() {
          _seenEventIds = list.toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading seen events: $e');
    }
  }

  Future<void> _markEventSeen(String eventId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      if (_seenEventIds.contains(eventId)) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'events_seen_ids_${user.id}';
      final updated = {..._seenEventIds, eventId};
      await prefs.setStringList(key, updated.toList());
      if (mounted) {
        setState(() {
          _seenEventIds = updated;
        });
      }
      // Update the global Club Hub badge count
      await NotificationService.signalLocalEventActivityChanged();
    } catch (e) {
      debugPrint('Error marking event seen: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadEvents();
    _loadSeenEvents();

    // Listen for club_events changes so multiple devices stay in sync
    final user = supabase.auth.currentUser;
    if (user != null) {
      _eventsChannel = supabase
          .channel('club_events_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'club_events',
            callback: (_) async {
              debugPrint(
                'ClubEventsCalendar: realtime club_events payload received, reloading events',
              );
              if (!mounted) return;
              // Reload events with club-based filtering
              await _loadEvents(showLoading: false);
              // Refresh unseen-event count so Club Hub badge updates
              await NotificationService.refreshEventActivityCount();
            },
          )
          .subscribe();
    }

    // Periodic fallback in case realtime updates are missed. This ensures
    // new events created on another device appear here even if the
    // realtime channel does not fire for some reason.
    _eventsPollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted) return;
      debugPrint('ClubEventsCalendar: periodic poll -> reloading events');
      await _loadEvents(showLoading: false);
      await NotificationService.refreshEventActivityCount();
    });
  }

  @override
  void didUpdateWidget(covariant ClubEventsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadSeenEvents();
      _loadEvents(showLoading: false);
      NotificationService.refreshEventActivityCount();
    }
  }

  @override
  void dispose() {
    _eventsPollTimer?.cancel();
    if (_eventsChannel != null) {
      Supabase.instance.client.removeChannel(_eventsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadRole() async {
    try {
      final isAdmin = await UserService.isAdmin();

      if (mounted) {
        setState(() {
          userRole = isAdmin ? 'admin' : 'social';
        });
      }
    } catch (e) {
      debugPrint('Error loading role: $e');
    }
  }

  /// Load all future events + today
  Future<void> _loadEvents({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() => _loading = true);
    }

    try {
      await _cleanupExpiredEventsIfNeeded();

      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _events = [];
            _loading = false;
          });
        }
        return;
      }

      // Determine the current user's club (cached for this widget).
      if (_clubName == null) {
        try {
          final profile = await supabase
              .from('user_profiles')
              .select('club')
              .eq('id', user.id)
              .maybeSingle();

          final name = (profile?['club'] as String?)?.trim();
          _clubName = (name != null && name.isNotEmpty) ? name : null;
        } catch (e) {
          debugPrint('Error loading user club for events: $e');
        }
      }

      // Resolve all user IDs that belong to this club so we can
      // restrict events to those created by members of the same club.
      final clubName = _clubName;
      if (_clubUserIds.isEmpty && clubName != null && clubName.isNotEmpty) {
        try {
          _clubUserIds = await NotificationService.userIdsForClub(clubName);
        } catch (e) {
          debugPrint('Error loading club user ids for events: $e');
        }
      }

      final rows = await supabase
          .from("club_events")
          .select("*")
          .order("date")
          .order("time");

      debugPrint(
        'ClubEventsCalendar: Fetched ${rows.length} total events for club=$_clubName, clubUserIds=${_clubUserIds.length}',
      );

      final now = DateTime.now();

      final parsed = (rows as List).map((e) => ClubEvent.fromSupabase(e)).where(
        (e) {
          // If we have a set of user IDs for this club, only keep events
          // created by those users. Otherwise (legacy/NNBR), keep all.
          final inClub = _clubUserIds.isEmpty
              ? true
              : (e.createdBy != null && _clubUserIds.contains(e.createdBy));

          return inClub && e.isVisibleInCalendarAt(now);
        },
      ).toList();

      debugPrint(
        'ClubEventsCalendar: After date filter, have ${parsed.length} events',
      );
      for (var e in parsed) {
        debugPrint('  - ${e.title} (cancelled: ${e.isCancelled})');
      }

      parsed.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      if (mounted) {
        setState(() {
          _events = parsed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR loading events: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _cleanupExpiredEventsIfNeeded() async {
    final lastCleanupAt = _lastCleanupAt;
    final now = DateTime.now();
    if (lastCleanupAt != null &&
        now.difference(lastCleanupAt) < const Duration(hours: 6)) {
      return;
    }

    _lastCleanupAt = now;

    try {
      final deleted = await supabase.rpc('run_expired_club_events_cleanup');
      debugPrint('ClubEventsCalendar: cleaned up $deleted expired events');
    } catch (e) {
      debugPrint('ClubEventsCalendar: expired event cleanup skipped: $e');
    }
  }

  /// Group events by month
  List<MonthGroup> get monthGroups {
    final map = <String, List<ClubEvent>>{};

    for (final e in _events) {
      final key = "${e.dateTime.year}-${e.dateTime.month}";
      map.putIfAbsent(key, () => []).add(e);
    }

    return map.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final label = "${_monthName(month)} $year";

      return MonthGroup(label, entry.value);
    }).toList()..sort(
      (a, b) => a.events.first.dateTime.compareTo(b.events.first.dateTime),
    );
  }

  String _monthName(int m) {
    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return names[m - 1];
  }

  String _weekday(DateTime dt) {
    const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return days[dt.weekday - 1];
  }

  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  Future<void> _openEvent(ClubEvent e) async {
    await _markEventSeen(e.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailsPage(event: e)),
    );
  }

  void _ensureWeatherLoaded(ClubEvent e) {
    // Only show weather within 7 days of the event, matching
    // the behaviour used on the event details venue preview.
    final now = DateTime.now();
    final diff = e.dateTime.difference(now);
    if (diff.inDays < 0 || diff.inDays > 7) return;

    if (_eventWeather.containsKey(e.id) || _weatherRequested.contains(e.id)) {
      return;
    }

    final lat = e.latitude;
    final lng = e.longitude;
    if (lat == null || lng == null) return;

    _weatherRequested.add(e.id);
    WeatherService.fetchWeather(latitude: lat, longitude: lng, when: e.dateTime)
        .then((result) {
          if (!mounted) return;
          setState(() {
            _eventWeather[e.id] = result;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _eventWeather[e.id] = null;
          });
        });
  }

  Future<String?> _getClubForUser(String userId) async {
    try {
      final row = await supabase
          .from('user_profiles')
          .select('club')
          .eq('id', userId)
          .maybeSingle();

      final name = (row?['club'] as String?)?.trim();
      return (name != null && name.isNotEmpty) ? name : null;
    } catch (e) {
      debugPrint(
        'ClubEventsCalendar: Error resolving club for user $userId: $e',
      );
      return null;
    }
  }

  /// Resolve the club for notifications based on the club of the
  /// currently logged-in user (the admin using this calendar).
  /// This ensures cancellations are always scoped to the caller's
  /// club, matching how the calendar itself is filtered.
  Future<String?> _resolveClubForEvent(ClubEvent e) async {
    if (_clubName != null && _clubName!.isNotEmpty) {
      return _clubName;
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      return await _getClubForUser(currentUser.id);
    }

    return null;
  }

  String _cancelledResponderBody({
    required String responseType,
    required String reason,
  }) {
    final involvement = switch (responseType) {
      'running' => 'running',
      'marshalling' => 'marshalling',
      'supporting' => 'supporting',
      'unavailable' => 'following',
      _ => 'attending',
    };
    final reasonText = reason.isNotEmpty ? ' Reason: $reason' : '';
    return 'The event you are $involvement has been cancelled.$reasonText';
  }

  Future<Set<String>> _notifyCancelledEventResponders({
    required ClubEvent event,
    required String reason,
  }) async {
    final responderIds = <String>{};

    try {
      final rows = await supabase
          .from('club_event_responses')
          .select('user_id, response_type')
          .eq('event_id', event.id);

      for (final row in rows as List) {
        final userId = row['user_id'] as String?;
        if (userId == null || userId.isEmpty) continue;

        responderIds.add(userId);
        await NotificationService.notifyUser(
          userId: userId,
          title: '${event.title} Cancelled',
          body: _cancelledResponderBody(
            responseType: (row['response_type'] as String?) ?? '',
            reason: reason,
          ),
          eventId: event.id,
        );
      }
    } catch (e) {
      debugPrint('Error notifying cancelled event responders: $e');
    }

    return responderIds;
  }

  @override
  Widget build(BuildContext context) {
    final brandColors = UserService.clubBrandGradient(_clubName);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Club Activity Hub",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              key: const PageStorageKey<String>('club_events_calendar_scroll'),
              slivers: [
                for (final group in monthGroups) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        group.monthLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final e = group.events[index];
                      _ensureWeatherLoaded(e);
                      final weather = _eventWeather[e.id];
                      final currentUserId = supabase.auth.currentUser?.id;
                      final isCreator =
                          currentUserId != null && e.createdBy == currentUserId;

                      if (isCreator) {
                        debugPrint(
                          'ClubEventsCalendar: Event ${e.id} is creator-owned. currentUserId=$currentUserId, createdBy=${e.createdBy}',
                        );
                      } else {
                        debugPrint(
                          'ClubEventsCalendar: Event ${e.id} NOT creator. currentUserId=$currentUserId, createdBy=${e.createdBy}',
                        );
                      }

                      // Derive a relay label for RNR vs Ekiden
                      String displayTitle = e.title ?? "";
                      final savedTitle = displayTitle.trim();
                      String subtitleText = e.venue;
                      final normalizedType = e.eventType
                          .toLowerCase()
                          .replaceAll(" ", "_");
                      String subtitleWithCreator(
                        String venue,
                        String creatorName,
                      ) {
                        final parts = <String>[];
                        if (creatorName.trim().isNotEmpty) {
                          parts.add('with ${creatorName.trim()}');
                        }
                        if (venue.trim().isNotEmpty) {
                          parts.add(venue.trim());
                        }
                        return parts.join('\n');
                      }

                      final trainingTitleByType = <String, String>{
                        'training': 'Training',
                        'training_1': 'Training 1',
                        'training_2': 'Training 2',
                        'recovery_monday': 'Recovery Monday',
                        'mousehold_monday': 'Mousehold Monday',
                        'tuesday_efforts_1': 'Tuesday Efforts 1',
                        'tuesday_efforts_2': 'Tuesday Efforts 2',
                        'tuesday_efforts': 'Tuesday Efforts',
                        'efforts_tuesday': 'Tuesday Efforts',
                        'road_run_thursday': 'Road Run Thursday',
                        'track_session': 'Track Session',
                        'coached_tuesday': 'Coached Tuesday',
                        'road_route_thursday': 'Road Route Thursday',
                        'paul_evans_session': 'Paul Evans Session',
                        'paul_evan_session': 'Paul Evan Session',
                      };
                      String titleWithSavedOverride(String fallbackTitle) {
                        if (savedTitle.isEmpty) return fallbackTitle;
                        return savedTitle;
                      }

                      if (normalizedType == 'relay') {
                        final rawTeam = e.relayTeam?.trim() ?? '';
                        final parts = rawTeam.split(':');
                        final relayName = parts.first.trim();
                        final teamName = parts.length > 1
                            ? parts.sublist(1).join(':').trim()
                            : '';
                        final relayPrefix = relayName.isEmpty
                            ? 'Relay'
                            : relayName.toLowerCase().endsWith('relay')
                            ? relayName
                            : '$relayName Relay';

                        displayTitle = relayPrefix;

                        if (teamName.isNotEmpty) {
                          displayTitle = '$displayTitle - Team: $teamName';
                        }
                      } else if (trainingTitleByType.containsKey(
                        normalizedType,
                      )) {
                        // For Training events, show "{Session} with {Host}" so
                        // members can immediately see who is leading the
                        // session on the calendar card.
                        final host = e.hostOrDirector.trim();
                        final baseTitle =
                            trainingTitleByType[normalizedType] ?? 'Training';
                        displayTitle = titleWithSavedOverride(baseTitle);
                        subtitleText = subtitleWithCreator(e.venue, host);
                      } else if (normalizedType == 'one_mile_handicap') {
                        final host = e.hostOrDirector.trim();
                        displayTitle = titleWithSavedOverride(
                          'One Mile Handicap',
                        );
                        subtitleText = subtitleWithCreator(e.venue, host);
                      } else if (normalizedType == 'social_run' ||
                          normalizedType == 'parkrun_tourism') {
                        final host = e.hostOrDirector.trim();
                        final baseTitle = normalizedType == 'parkrun_tourism'
                            ? 'Parkrun Tourism'
                            : 'Social Run';
                        displayTitle = titleWithSavedOverride(baseTitle);
                        subtitleText = subtitleWithCreator(e.venue, host);
                      } else {
                        subtitleText = e.venue;
                      }

                      final eventCreatorName = e.hostOrDirector.trim();
                      if (eventCreatorName.isNotEmpty &&
                          !displayTitle.contains(eventCreatorName) &&
                          !subtitleText.contains(eventCreatorName)) {
                        subtitleText = subtitleText.trim().isEmpty
                            ? 'with $eventCreatorName'
                            : 'with $eventCreatorName\n$subtitleText';
                      }

                      final isNew =
                          !e.isCancelled && !_seenEventIds.contains(e.id);

                      Widget card = GestureDetector(
                        onTap: () => _openEvent(e),
                        child: _EventCard(
                          weekday: _weekday(e.dateTime),
                          day: e.dateTime.day,
                          timeLabel: _fmtTime(e.dateTime),
                          weather: weather,
                          title: displayTitle,
                          subtitle: subtitleText,
                          activityType: e.eventType,
                          isCancelled: e.isCancelled,
                          isNew: isNew,
                        ),
                      );

                      if (isCreator && !e.isCancelled) {
                        // Single Dismissible handles both edit (L→R) and cancel (R→L)
                        card = Dismissible(
                          key: ValueKey('event-swipe-${e.id}'),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(
                              Icons.cancel,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (e.isCancelled) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cancelled events can no longer be edited or cancelled again',
                                    ),
                                  ),
                                );
                              }
                              return false;
                            }

                            if (direction == DismissDirection.startToEnd) {
                              // Edit
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminEditEventPage(event: e),
                                ),
                              );
                              if (result == true) {
                                await _loadEvents();
                              }
                              return false; // keep card
                            } else {
                              // Cancel
                              final reasonController = TextEditingController();
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Cancel Event?'),
                                  content: TextField(
                                    controller: reasonController,
                                    decoration: const InputDecoration(
                                      labelText: 'Reason (optional)',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Cancel Event'),
                                    ),
                                  ],
                                ),
                              );

                              if (ok == true) {
                                try {
                                  final cancelReason = reasonController.text
                                      .trim();
                                  await supabase
                                      .from('club_events')
                                      .update({
                                        'is_cancelled': true,
                                        'cancel_reason': cancelReason,
                                        'cancelled_at': DateTime.now()
                                            .toUtc()
                                            .toIso8601String(),
                                      })
                                      .eq('id', e.id);

                                  // Notify members of the relevant club about cancellation
                                  try {
                                    final responderIds =
                                        await _notifyCancelledEventResponders(
                                          event: e,
                                          reason: cancelReason,
                                        );
                                    final clubName = await _resolveClubForEvent(
                                      e,
                                    );
                                    if (clubName != null &&
                                        clubName.isNotEmpty) {
                                      await NotificationService.notifyUsersInClub(
                                        clubName: clubName,
                                        title: '${e.title} Cancelled',
                                        body: cancelReason.isNotEmpty
                                            ? 'Event cancelled. Reason: $cancelReason'
                                            : 'Event has been cancelled.',
                                        eventId: e.id,
                                        excludeUserIds: responderIds,
                                      );
                                    } else {
                                      debugPrint(
                                        'ClubEventsCalendar: Skipping cancellation notification because club could not be resolved for event ${e.id}',
                                      );
                                    }
                                  } catch (notifErr) {
                                    debugPrint(
                                      'Error notifying users: $notifErr',
                                    );
                                  }

                                  await _loadEvents();
                                  // Refresh unread badge for current user (creator)
                                  try {
                                    await NotificationService.refreshUnreadCount();
                                  } catch (e) {
                                    debugPrint(
                                      'Error refreshing unread count: $e',
                                    );
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Event cancelled & members notified',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $err')),
                                    );
                                  }
                                }
                              }
                              return false; // keep card
                            }
                          },
                          child: card,
                        );
                      }

                      return card;
                    }, childCount: group.events.length),
                  ),
                ],
              ],
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () async {
          // ADMIN → full event creation
          // SOCIAL → social events only
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminCreateEventPage(userRole: userRole),
            ),
          );

          await _loadEvents();
          await NotificationService.refreshEventActivityCount();

          if (result == true) {
            // Supabase realtime can arrive a moment after the insert on some
            // devices. A short second refresh makes newly created events appear
            // promptly without waiting for the periodic poll or an app restart.
            await Future<void>.delayed(const Duration(milliseconds: 700));
            if (!mounted) return;
            await _loadEvents();
            await NotificationService.refreshEventActivityCount();
          }
        },
      ),
    );
  }
}

/// =============================================================
/// MONTH GROUP CLASS
/// =============================================================
class MonthGroup {
  final String monthLabel;
  final List<ClubEvent> events;

  MonthGroup(this.monthLabel, this.events);
}

/// =============================================================
/// EVENT CARD (Glass effect + cancellation overlay)
/// =============================================================
class _EventCard extends StatelessWidget {
  final String weekday;
  final int day;
  final String timeLabel;
  final WeatherAtTime? weather;
  final String title;
  final String subtitle;
  final String activityType;
  final bool isCancelled;
  final bool isNew;

  const _EventCard({
    required this.weekday,
    required this.day,
    required this.timeLabel,
    required this.weather,
    required this.title,
    required this.subtitle,
    required this.activityType,
    required this.isCancelled,
    required this.isNew,
  });

  Color _background(String t) {
    String normalized = t.toLowerCase().replaceAll(" ", "_");
    switch (normalized) {
      case 'training':
      case 'training_1':
      case 'training_2':
        return const Color(0x44FFF59D);
      case 'recovery_monday':
        return const Color(0x44DCE775);
      case 'mousehold_monday':
        return const Color(0x444DB6AC);
      case 'tuesday_efforts_1':
        return const Color(0x44B39DDB);
      case 'tuesday_efforts_2':
        return const Color(0x44CE93D8);
      case 'tuesday_efforts':
      case 'efforts_tuesday':
      case 'coached_tuesday':
        return const Color(0x44BA68C8);
      case 'road_run_thursday':
      case 'road_route_thursday':
        return const Color(0x444FC3F7);
      case 'track_session':
      case 'paul_evans_session':
      case 'paul_evan_session':
        return const Color(0x44FFB74D);
      case 'race':
        return const Color(0x4442A5F5);
      case 'cross_country':
        return const Color(0x4466BB6A);
      case 'handicap_series':
        return const Color(0x449CCC65);
      case 'one_mile_handicap':
        return const Color(0x4426A69A);
      case 'relay':
        return const Color(0x44FFCC80);
      case 'special_event':
        return const Color(0x44F48FB1);
      case 'social_run':
        return const Color(0x447E57C2);
      case 'parkrun_tourism':
        return const Color(0x445C6BC0);
      case 'meet_&_drink':
        return const Color(0x448D6E63);
      case 'swim_or_cycle':
        return const Color(0x444DD0E1);
      case 'others':
        return const Color(0x4490A4AE);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  String _icon(String t) {
    String normalized = t.toLowerCase().replaceAll(" ", "_");
    switch (normalized) {
      case 'training':
      case 'training_1':
      case 'training_2':
      case 'recovery_monday':
      case 'mousehold_monday':
      case 'tuesday_efforts_1':
      case 'tuesday_efforts_2':
      case 'tuesday_efforts':
      case 'efforts_tuesday':
      case 'road_run_thursday':
      case 'track_session':
      case 'coached_tuesday':
      case 'road_route_thursday':
      case 'paul_evans_session':
      case 'paul_evan_session':
        return '🏃';
      case 'race':
      case 'cross_country':
        return '🏁';
      case 'handicap_series':
      case 'one_mile_handicap':
        return '🎯';
      case 'relay':
        return '🔗';
      case 'special_event':
        return '🎉';
      case 'social_run':
      case 'parkrun_tourism':
      case 'meet_&_drink':
      case 'swim_or_cycle':
      case 'others':
        return '🍻';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isCancelled ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                color: _background(activityType),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (isNew && !isCancelled)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD300), // yellow dot
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Opacity(
                      opacity: 0.18,
                      child: Text(
                        _icon(activityType),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),

                  if (isCancelled)
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          "CANCELLED",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              weekday,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "$day",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (weather != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    _weatherIcon(weather!.code),
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "${weather!.tempC.round()}°C • ${weather!.windMph.round()} mph • ${weather!.description}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3 || code == 45 || code == 48) return Icons.cloud;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }
    if ((code >= 80 && code <= 82) || (code >= 61 && code <= 65)) {
      return Icons.grain_rounded;
    }
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue;
  }
}
