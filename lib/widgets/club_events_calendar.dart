import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/event_details_page.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';

/// =============================================================
/// CLUB EVENTS CALENDAR — unified for all event types
/// =============================================================
class ClubEventsCalendar extends StatefulWidget {
  const ClubEventsCalendar({super.key});

  @override
  State<ClubEventsCalendar> createState() => _ClubEventsCalendarState();
}

class _ClubEventsCalendarState extends State<ClubEventsCalendar> {
  final supabase = Supabase.instance.client;

  List<ClubEvent> _events = [];
  bool _loading = true;
  String userRole = "reader"; // reader or admin
  String _currentMonthLabel = "";

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadEvents();
  }

  Future<void> _loadRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final row = await supabase
        .from("user_profiles")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();

    setState(() {
      userRole = row?["role"] ?? "reader";
    });
  }

  /// Load all future events + today
  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    try {
      final rows = await supabase
          .from("club_events")
          .select("*")
          .order("date")
          .order("time");

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final parsed = (rows as List).map((e) => ClubEvent.fromSupabase(e)).where(
        (e) {
          final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
          return d.isAtSameMomentAs(today) || d.isAfter(today);
        },
      ).toList();

      parsed.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      setState(() {
        _events = parsed;
        _loading = false;
        // Initialize current month label with the first month
        if (parsed.isNotEmpty) {
          final firstEvent = parsed.first;
          _currentMonthLabel =
              "${_monthName(firstEvent.dateTime.month)} ${firstEvent.dateTime.year}";
        }
      });
    } catch (e) {
      print("ERROR loading events: $e");
      setState(() => _loading = false);
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

  void _updateCurrentMonthLabel(double scrollOffset) {
    // The header should change when the last event of the current month
    // is about to scroll off the screen (accounting for header height)
    const headerHeight = 48.0;
    const eventHeight = 120.0; // Approximate event card height

    double currentOffset = 0.0; // Start from top

    for (final group in monthGroups) {
      final groupHeight = group.events.length * eventHeight;

      // Show this group's month until the last event of this group
      // is about to scroll off (headerHeight from the top)
      if (scrollOffset < currentOffset + groupHeight - headerHeight) {
        if (_currentMonthLabel != group.monthLabel) {
          setState(() {
            _currentMonthLabel = group.monthLabel;
          });
        }
        return;
      }

      currentOffset += groupHeight;
    }

    // If we've scrolled past all content, keep the last month
    if (monthGroups.isNotEmpty &&
        _currentMonthLabel != monthGroups.last.monthLabel) {
      setState(() {
        _currentMonthLabel = monthGroups.last.monthLabel;
      });
    }
  }

  void _openEvent(ClubEvent e) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailsPage(event: e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Club Activity Hub",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollNotification) {
                if (scrollNotification is ScrollUpdateNotification) {
                  _updateCurrentMonthLabel(scrollNotification.metrics.pixels);
                }
                return true;
              },
              child: CustomScrollView(
                slivers: [
                  // Single sticky header that changes content
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    backgroundColor: Colors.black.withOpacity(0.75),
                    title: Text(
                      _currentMonthLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    toolbarHeight: 48,
                  ),

                  // Event sections without individual headers
                  for (final group in monthGroups) ...[
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final e = group.events[index];
                        return GestureDetector(
                          onTap: () => _openEvent(e),
                          child: _EventCard(
                            weekday: _weekday(e.dateTime),
                            day: e.dateTime.day,
                            timeLabel: _fmtTime(e.dateTime),
                            title: e.title ?? "",
                            subtitle: e.venue,
                            activityType: e.eventType,
                            isCancelled: e.isCancelled,
                          ),
                        );
                      }, childCount: group.events.length),
                    ),
                  ],
                ],
              ),
            ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          // ADMIN → full event creation
          // READER → social events only
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminCreateEventPage(userRole: userRole),
            ),
          );

          _loadEvents();
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
  final String title;
  final String subtitle;
  final String activityType;
  final bool isCancelled;

  const _EventCard({
    required this.weekday,
    required this.day,
    required this.timeLabel,
    required this.title,
    required this.subtitle,
    required this.activityType,
    required this.isCancelled,
  });

  Color _background(String t) {
    String normalized = t.toLowerCase().replaceAll(" ", "_");
    switch (normalized) {
      case 'training_1':
      case 'training_2':
        return const Color(0x33FFF59D);
      case 'race':
        return const Color(0x3390CAF9);
      case 'handicap_series':
        return const Color(0x33A5D6A7);
      case 'relay':
        return const Color(0x33FFCC80);
      case 'special_event':
        return const Color(0x33F8BBD0);
      case 'social_run':
      case 'meet_&_drink':
      case 'swim_or_cycle':
      case 'others':
        return const Color(0x33CE93D8);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  String _icon(String t) {
    String normalized = t.toLowerCase().replaceAll(" ", "_");
    switch (normalized) {
      case 'training_1':
      case 'training_2':
        return '🏃';
      case 'race':
        return '🏁';
      case 'handicap_series':
        return '🎯';
      case 'relay':
        return '🔗';
      case 'special_event':
        return '🎉';
      case 'social_run':
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _background(activityType),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Opacity(
                      opacity: 0.18,
                      child: Text(
                        _icon(activityType),
                        style: const TextStyle(fontSize: 42),
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
                            color: Colors.red.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),

                  Row(
                    children: [
                      Column(
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
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
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
}
