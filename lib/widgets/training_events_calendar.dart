import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_details_page.dart';
import 'training_details_page.dart';
import 'handicap_details_page.dart';
import 'race_details_page.dart';
import 'relay_details_page.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';

/// =============================================================
///  MODEL
/// =============================================================
class TrainingEvent {
  final String id;
  final DateTime dateTime;
  final String eventType;
  final String title;
  final int? trainingNumber;
  final String leadName;
  final String venue;
  final String venueAddress;
  final String description;
  final String? raceName;
  final String? handicapDistance;
  final String? relayTeam;

  TrainingEvent({
    required this.id,
    required this.dateTime,
    required this.eventType,
    required this.title,
    this.trainingNumber,
    required this.leadName,
    required this.venue,
    required this.venueAddress,
    required this.description,
    this.raceName,
    this.handicapDistance,
    this.relayTeam,
  });

  factory TrainingEvent.fromRow(Map<String, dynamic> row) {
    final type = row['event_type'] as String? ?? 'event';
    final storedTitle = row['title'] as String?;

    final trainingNo = row['training_number'] as int?;
    final raceName = row['race_name'] as String?;
    final handicapDistance = row['handicap_distance'] as String?;
    final relayTeam = row['relay_team'] as String?;

    final host = row['host_or_director'] as String? ?? '';
    final venue = row['venue'] as String? ?? '';
    final venueAddress = row['venue_address'] as String? ?? '';
    final description = row['description'] as String? ?? '';

    final dateStr = row['date'] as String?;
    final timeStr = row['time'] as String?;

    DateTime dt;
    if (dateStr != null) {
      final clean = (timeStr ?? '').split('.').first;
      dt = DateTime.parse(clean.isNotEmpty ? "$dateStr $clean" : dateStr);
    } else {
      dt = DateTime.now();
    }

    String label = (storedTitle ?? "").trim();
    if (label.isEmpty) {
      switch (type) {
        case "training":
          label = "Training ${trainingNo ?? 1}";
          break;
        case "race":
          label = "Race: ${raceName ?? ''}";
          break;
        case "handicap":
          label = "Handicap (${handicapDistance ?? ''})";
          break;
        case "relay":
          label = "RNR Relay – Team ${relayTeam ?? ''}";
          break;
        default:
          label = "Club Activity";
      }
    }

    return TrainingEvent(
      id: row['id'].toString(),
      dateTime: dt,
      eventType: type,
      title: label,
      trainingNumber: trainingNo,
      leadName: host,
      venue: venue,
      venueAddress: venueAddress,
      description: description,
      raceName: raceName,
      handicapDistance: handicapDistance,
      relayTeam: relayTeam,
    );
  }
}

/// =============================================================
/// MONTH GROUP
/// =============================================================
class MonthGroup {
  final String monthLabel;
  final List<TrainingEvent> events;

  MonthGroup(this.monthLabel, this.events);
}

/// Sticky Month Header (single pinned header)
class StickyMonthHeader extends SliverPersistentHeaderDelegate {
  final String label;
  StickyMonthHeader(this.label);

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StickyMonthHeader old) => old.label != label;
}

/// =============================================================
/// MAIN SCREEN
/// =============================================================
class TrainingEventsCalendar extends StatefulWidget {
  const TrainingEventsCalendar({super.key});

  @override
  State<TrainingEventsCalendar> createState() => _TrainingEventsCalendarState();
}

class _TrainingEventsCalendarState extends State<TrainingEventsCalendar> {
  List<TrainingEvent> _events = [];
  bool _loading = true;

  String userRole = "reader";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadEvents();
  }

  Future<void> _loadUserRole() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final row = await client
        .from("user_profiles")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();

    setState(() {
      userRole = row?["role"] ?? "reader";
    });
  }

  /// Removes all events before TODAY
  Future<void> _loadEvents() async {
    setState(() => _loading = true);

    final client = Supabase.instance.client;

    try {
      final rows = await client
          .from("club_events")
          .select("""
            id, event_type, training_number, race_name, handicap_distance,
            title, date, time, host_or_director, venue, venue_address,
            description, relay_team
          """)
          .order("date")
          .order("time");

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final list = (rows as List).map((e) => TrainingEvent.fromRow(e)).where((
        e,
      ) {
        final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
        return d.isAtSameMomentAs(today) || d.isAfter(today);
      }).toList();

      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      setState(() {
        _events = list;
        _loading = false;
      });
    } catch (e) {
      print("ERROR loading events: $e");
      setState(() => _loading = false);
    }
  }

  /// Open event details page
  void _openEvent(TrainingEvent e) {
    Widget page;

    switch (e.eventType.toLowerCase()) {
      case "training":
        page = TrainingDetailsPage(event: e);
        break;
      case "handicap":
        page = HandicapDetailsPage(event: e);
        break;
      case "race":
        page = RaceDetailsPage(event: e);
        break;
      case "relay":
        page = RelayDetailsPage(event: e);
        break;
      default:
        page = EventDetailsPage(event: e);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// Build month groups
  List<MonthGroup> get monthGroups {
    final map = <String, List<TrainingEvent>>{};

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

  String _weekdayAbbrev(DateTime dt) {
    const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return days[dt.weekday - 1];
  }

  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Club Activity Hub")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Club Activity Hub")),
      body: CustomScrollView(
        slivers: [
          for (final group in monthGroups) ...[
            SliverPersistentHeader(
              pinned: false,
              floating: false,
              delegate: StickyMonthHeader(group.monthLabel),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final e = group.events[index];
                return GestureDetector(
                  onTap: () => _openEvent(e),
                  child: _EventCard(
                    weekday: _weekdayAbbrev(e.dateTime),
                    day: e.dateTime.day,
                    timeLabel: _fmtTime(e.dateTime),
                    title: e.title,
                    subtitle: e.venue,
                    activityType: e.eventType,
                  ),
                );
              }, childCount: group.events.length),
            ),
          ],
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminCreateEventPage(userRole: userRole),
            ),
          ).then((_) => _loadEvents());
        },
      ),
    );
  }
}

/// =============================================================
/// EVENT CARD (kept exactly as your latest version)
/// =============================================================
class _EventCard extends StatelessWidget {
  final String weekday;
  final int day;
  final String timeLabel;
  final String title;
  final String subtitle;
  final String activityType;

  const _EventCard({
    required this.weekday,
    required this.day,
    required this.timeLabel,
    required this.title,
    required this.subtitle,
    required this.activityType,
  });

  Color _background(String t) {
    switch (t.toLowerCase()) {
      case 'training':
      case 'training 1':
      case 'training 2':
        return const Color(0x33FFF59D);
      case 'race':
        return const Color(0x3390CAF9);
      case 'event':
        return const Color(0x33FF8A80);
      case 'handicap':
        return const Color(0x33A5D6A7);
      case 'relay':
        return const Color(0x33FFCC80);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  Color _border(String t) {
    switch (t.toLowerCase()) {
      case 'training':
      case 'training 1':
      case 'training 2':
        return const Color(0xFFFFF59D);
      case 'race':
        return const Color(0xFF90CAF9);
      case 'event':
        return const Color(0xFFFF8A80);
      case 'handicap':
        return const Color(0xFFA5D6A7);
      case 'relay':
        return const Color(0xFFFFCC80);
      default:
        return Colors.white24;
    }
  }

  String _icon(String t) {
    switch (t.toLowerCase()) {
      case 'training':
        return '🏃';
      case 'race':
        return '🏁';
      case 'handicap':
        return '🎯';
      case 'relay':
        return '🔗';
      case 'event':
        return '🎉';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              border: Border.all(color: _border(activityType), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: Opacity(
                    opacity: 0.22,
                    child: Text(
                      _icon(activityType),
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
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
    );
  }
}
