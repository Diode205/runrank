import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/event_response_service.dart';
import 'package:runrank/widgets/training_events_calendar.dart'
    show TrainingEvent;

import 'attendee_list_page.dart';

class HandicapDetailsPage extends StatefulWidget {
  final TrainingEvent event;

  const HandicapDetailsPage({super.key, required this.event});

  @override
  State<HandicapDetailsPage> createState() => _HandicapDetailsPageState();
}

class _HandicapDetailsPageState extends State<HandicapDetailsPage> {
  Map<String, int> _counts = {};
  bool _loadingCounts = true;

  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

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

  Future<void> _saveExpected() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    int h = int.tryParse(_hCtrl.text) ?? 0;
    int m = int.tryParse(_mCtrl.text) ?? 0;
    int s = int.tryParse(_sCtrl.text) ?? 0;

    final seconds = h * 3600 + m * 60 + s;

    if (seconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Enter valid time")));
      return;
    }

    await EventResponseService.submitExpectedTime(
      eventId: widget.event.id,
      userId: user.id,
      expectedTimeSeconds: seconds,
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
      body: SingleChildScrollView(
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

            // HOST
            const Text("Organiser"),
            const SizedBox(height: 4),
            Text(e.leadName),

            const SizedBox(height: 20),
            const Divider(),

            // VENUE
            const Text("Venue"),
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
            const Text("Details"),
            const SizedBox(height: 4),
            Text(
              e.description.isEmpty ? "No details provided." : e.description,
            ),

            const SizedBox(height: 30),

            // EXPECTED TIME
            const Text(
              "Expected Time (Optional)",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hCtrl,
                    decoration: const InputDecoration(labelText: "HH"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _mCtrl,
                    decoration: const InputDecoration(labelText: "MM"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _sCtrl,
                    decoration: const InputDecoration(labelText: "SS"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saveExpected,
              child: const Text("Save Expected Time"),
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
              _countTile("marshalling", Icons.flag),
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
                    onPressed: () => _respond("marshalling"),
                    child: const Text("Marshalling"),
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
