import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/event_response_service.dart';
import 'package:runrank/widgets/training_events_calendar.dart'
    show TrainingEvent;
import 'package:runrank/widgets/attendee_list_page.dart';

class TrainingDetailsPage extends StatefulWidget {
  final TrainingEvent event;

  const TrainingDetailsPage({super.key, required this.event});

  @override
  State<TrainingDetailsPage> createState() => _TrainingDetailsPageState();
}

class _TrainingDetailsPageState extends State<TrainingDetailsPage> {
  bool _loadingCounts = true;
  Map<String, int> _counts = {};

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

  Future<void> _handleResponse(String responseType) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to respond.')),
      );
      return;
    }

    final ok = await EventResponseService.submitResponse(
      eventId: widget.event.id,
      userId: user.id,
      responseType: responseType,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save response.')));
      return;
    }

    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final date = event.dateTime;
    final dateText =
        '${_weekday(date.weekday)}, ${date.day} ${_month(date.month)} ${date.year}';
    final timeText =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final attendingCount = _counts['attending'] ?? 0;
    final unavailableCount = _counts['unavailable'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DATE + TIME
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                Text(timeText, style: const TextStyle(fontSize: 16)),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),

            // TRAINING LEAD
            const Text(
              'Training Lead',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.leadName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 20),
            const Divider(),

            // VENUE
            const Text(
              'Venue',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.venue,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            if (event.venueAddress != null &&
                event.venueAddress.trim().isNotEmpty)
              Text(
                event.venueAddress,
                style: const TextStyle(color: Colors.black54),
              ),

            const SizedBox(height: 20),
            const Divider(),

            // DESCRIPTION
            const Text(
              'Session Details',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.description.isEmpty
                  ? 'No additional details provided.'
                  : event.description,
              style: const TextStyle(fontSize: 15),
            ),

            const SizedBox(height: 30),

            // ATTENDANCE SECTION
            const Text(
              'Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            if (_loadingCounts)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              _responseTile(
                icon: Icons.check_circle,
                color: Colors.green,
                label: 'Attending',
                count: attendingCount,
                responseType: 'attending',
              ),
              const SizedBox(height: 8),
              _responseTile(
                icon: Icons.cancel,
                color: Colors.red,
                label: 'Unavailable',
                count: unavailableCount,
                responseType: 'unavailable',
              ),
            ],

            const SizedBox(height: 30),

            // RESPONSE BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleResponse('attending'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'Attending',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleResponse('unavailable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Unavailable',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseTile({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
    required String responseType,
  }) {
    return InkWell(
      onTap: count == 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendeeListPage(
                    eventId: widget.event.id,
                    responseType: responseType,
                    title: label,
                  ),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            Text(count.toString(), style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  String _weekday(int n) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[n - 1];
  }

  String _month(int n) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[n - 1];
  }
}
