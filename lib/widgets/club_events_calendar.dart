import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/event_details_page.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';
import 'package:runrank/widgets/admin_edit_event_page.dart';
import 'package:runrank/services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadEvents();
  }

  Future<void> _loadRole() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final row = await supabase
          .from("user_profiles")
          .select("role")
          .eq("id", user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          userRole = row?["role"] ?? "reader";
        });
      }
    } catch (e) {
      debugPrint('Error loading role: $e');
    }
  }

  /// Load all future events + today
  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final rows = await supabase
          .from("club_events")
          .select("*")
          .order("date")
          .order("time");

      debugPrint('ClubEventsCalendar: Fetched ${rows.length} total events');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final parsed = (rows as List).map((e) => ClubEvent.fromSupabase(e)).where(
        (e) {
          final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
          return d.isAtSameMomentAs(today) || d.isAfter(today);
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
      print("ERROR loading events: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
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
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0x4DFFD300), const Color(0x4D0057B7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
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
                      String subtitleText = e.venue;
                      if (e.eventType.toLowerCase() == 'relay') {
                        final rawTeam = e.relayTeam?.trim() ?? '';
                        final teamLower = rawTeam.toLowerCase();
                        final isEkiden = teamLower.startsWith('ekiden');
                        final relayPrefix = isEkiden
                            ? 'Ekiden Relay'
                            : 'RNR Relay';

                        if (displayTitle.isEmpty || displayTitle == 'Relay') {
                          displayTitle = relayPrefix;
                        } else if (!displayTitle.toLowerCase().startsWith(
                              'rnr relay',
                            ) &&
                            !displayTitle.toLowerCase().startsWith(
                              'ekiden relay',
                            )) {
                          displayTitle = '$relayPrefix – ${displayTitle}';
                        }

                        // Show team name on card if provided
                        if (rawTeam.isNotEmpty) {
                          String teamLabel = rawTeam;
                          if (isEkiden) {
                            final parts = rawTeam.split(':');
                            if (parts.length > 1 &&
                                parts[1].trim().isNotEmpty) {
                              teamLabel = parts[1].trim();
                            } else {
                              teamLabel = 'Ekiden';
                            }
                          }

                          if (teamLabel.isNotEmpty) {
                            subtitleText = subtitleText.trim().isEmpty
                                ? 'Team: $teamLabel'
                                : '${e.venue} • Team: $teamLabel';
                          }
                        }
                      } else {
                        subtitleText = e.venue;
                      }

                      Widget card = GestureDetector(
                        onTap: () => _openEvent(e),
                        child: _EventCard(
                          weekday: _weekday(e.dateTime),
                          day: e.dateTime.day,
                          timeLabel: _fmtTime(e.dateTime),
                          title: displayTitle,
                          subtitle: subtitleText,
                          activityType: e.eventType,
                          isCancelled: e.isCancelled,
                        ),
                      );

                      if (isCreator) {
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
                                  await supabase
                                      .from('club_events')
                                      .update({
                                        'is_cancelled': true,
                                        'cancel_reason': reasonController.text
                                            .trim(),
                                      })
                                      .eq('id', e.id);

                                  // Notify all members about cancellation
                                  try {
                                    await NotificationService.notifyAllUsers(
                                      title: '${e.title} Cancelled',
                                      body: reasonController.text.isNotEmpty
                                          ? 'Event cancelled. Reason: ${reasonController.text.trim()}'
                                          : 'Event has been cancelled.',
                                      eventId: e.id,
                                    );
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
      case 'cross_country':
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
      case 'cross_country':
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
