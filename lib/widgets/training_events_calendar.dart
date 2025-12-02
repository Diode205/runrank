import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_details_page.dart';
import 'training_details_page.dart';
import 'handicap_details_page.dart';
import 'race_details_page.dart';
import 'relay_details_page.dart';

/// Model for any club event / training / race / relay.
class TrainingEvent {
  final String id;
  final DateTime dateTime; // combined from date + time
  final String eventType; // training, event, race, handicap, relay
  final String title;
  final int? trainingNumber;
  final String leadName; // host_or_director
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
    final eventType = row['event_type'] as String? ?? 'event';
    final storedTitle = row['title'] as String?;

    final trainingNumber = row['training_number'] as int?;
    final raceName = row['race_name'] as String?;
    final handicapDistance = row['handicap_distance'] as String?;
    final relayTeam = row['relay_team'] as String?;

    final host = row['host_or_director'] as String? ?? '';
    final venue = row['venue'] as String? ?? '';
    final venueAddress = row['venue_address'] as String? ?? '';
    final description = row['description'] as String? ?? '';

    // --- combine date + time into DateTime ---
    final dateStr = row['date'] as String?;
    final timeStr = row['time'] as String?;

    DateTime dateTime;

    if (dateStr != null) {
      // Supabase usually returns e.g. "2025-01-18" and "18:30:00"
      final cleanedTime = (timeStr ?? '')
          .split('.')
          .first; // just in case of microseconds
      final combined = cleanedTime.isNotEmpty
          ? '$dateStr $cleanedTime'
          : dateStr; // will parse as midnight if only date
      dateTime = DateTime.parse(combined);
    } else {
      dateTime = DateTime.now();
    }

    // --- build a nice title if none stored ---
    String label = (storedTitle ?? '').trim();

    if (label.isEmpty) {
      switch (eventType) {
        case 'training':
          final tn = trainingNumber ?? 1;
          label = 'Training $tn';
          break;
        case 'race':
          label = 'Race: ${raceName ?? ''}';
          break;
        case 'handicap':
          label = 'Handicap (${handicapDistance ?? ''})';
          break;
        case 'relay':
          label = 'RNR Relay – Team ${relayTeam ?? ''}';
          break;
        default:
          label = 'Club Activity';
      }
    }

    return TrainingEvent(
      id: row['id'] as String,
      dateTime: dateTime,
      eventType: eventType,
      title: label,
      trainingNumber: trainingNumber,
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

class TrainingEventsCalendar extends StatefulWidget {
  const TrainingEventsCalendar({super.key});

  @override
  State<TrainingEventsCalendar> createState() => _TrainingEventsCalendarState();
}

class _TrainingEventsCalendarState extends State<TrainingEventsCalendar> {
  List<TrainingEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
    });

    final client = Supabase.instance.client;

    try {
      final rows = await client
          .from('club_events')
          .select('''
            id,
            event_type,
            training_number,
            race_name,
            handicap_distance,
            title,
            date,
            time,
            host_or_director,
            venue,
            venue_address,
            description,
            relay_team
          ''')
          .order('date', ascending: true)
          .order('time', ascending: true);

      setState(() {
        _events = (rows as List<dynamic>)
            .map((e) => TrainingEvent.fromRow(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error loading club_events: $e');
      if (!mounted) return;
      setState(() {
        _events = [];
        _loading = false;
      });
    }
  }

  void _openEvent(TrainingEvent event) {
    Widget page;

    switch (event.eventType) {
      case 'training':
        page = TrainingDetailsPage(event: event);
        break;
      case 'handicap':
        page = HandicapDetailsPage(event: event);
        break;
      case 'race':
        page = RaceDetailsPage(event: event);
        break;
      case 'relay':
        page = RelayDetailsPage(event: event);
        break;
      default:
        page = EventDetailsPage(event: event);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Club Activity Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(
              child: Text(
                'No upcoming activities',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEvents,
              child: ListView.builder(
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return _eventCard(event);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/admin-create-event',
          ).then((_) => _loadEvents());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _eventCard(TrainingEvent event) {
    return GestureDetector(
      onTap: () => _openEvent(event),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // date block
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _month(event.dateTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                Text(
                  event.dateTime.day.toString(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // title + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(event.dateTime),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  if (event.leadName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.leadName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _month(DateTime dt) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[dt.month - 1];
  }
}
