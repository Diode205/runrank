import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_response_service.dart';
import 'attendee_list_page.dart';
import 'package:runrank/widgets/training_events_calendar.dart'
    show TrainingEvent;

class RelayDetailsPage extends StatefulWidget {
  final TrainingEvent event;

  const RelayDetailsPage({super.key, required this.event});

  @override
  State<RelayDetailsPage> createState() => _RelayDetailsPageState();
}

class _RelayDetailsPageState extends State<RelayDetailsPage> {
  Map<String, int> _counts = {};
  bool _loadingCounts = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final counts = await EventResponseService.getResponseCounts(
      widget.event.id,
    );
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _loadingCounts = false;
    });
  }

  Future<void> _respond(String type) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await EventResponseService.submitResponse(
      eventId: widget.event.id,
      userId: user.id,
      responseType: type,
    );

    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;

    final dateString =
        "${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)} ${dt.year}";
    final timeString =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DATE
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(dateString),
              ],
            ),
            const SizedBox(height: 8),

            // TIME
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 8),
                Text(timeString),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),

            // COORDINATOR
            const Text("Relay Coordinator"),
            const SizedBox(height: 4),
            Text(e.leadName),

            const SizedBox(height: 20),
            const Divider(),

            // VENUE
            const Text("Venue / Start Point"),
            const SizedBox(height: 4),
            Text(e.venue),
            if (e.venueAddress.isNotEmpty)
              Text(
                e.venueAddress,
                style: const TextStyle(color: Colors.black54),
              ),

            const SizedBox(height: 20),
            const Divider(),

            // DESCRIPTION
            const Text("Relay Details"),
            const SizedBox(height: 4),
            Text(
              e.description.isEmpty ? "No details provided." : e.description,
            ),

            const SizedBox(height: 30),

            // PARTICIPATION
            const Text("Participation", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            if (_loadingCounts)
              const Center(child: CircularProgressIndicator())
            else ...[
              _countTile("running", Icons.directions_run),
              const SizedBox(height: 6),
              _countTile("supporting", Icons.group),
              const SizedBox(height: 6),
              _countTile("unavailable", Icons.cancel),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond("running"),
                    child: const Text("Running"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond("supporting"),
                    child: const Text("Supporting"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond("unavailable"),
                    child: const Text("Unavailable"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countTile(String type, IconData icon) {
    final count = _counts[type] ?? 0;

    return InkWell(
      onTap: count == 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendeeListPage(
                    eventId: widget.event.id,
                    responseType: type,
                    title: type,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(type),
            const Spacer(),
            Text(count.toString()),
          ],
        ),
      ),
    );
  }

  String _weekday(int w) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[w - 1];
  }

  String _month(int m) {
    const names = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return names[m - 1];
  }
}
