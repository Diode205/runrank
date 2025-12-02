import 'package:flutter/material.dart';
import 'package:runrank/widgets/training_events_calendar.dart'
    show TrainingEvent;

class EventDetailsPage extends StatelessWidget {
  final TrainingEvent event;

  const EventDetailsPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dt = event.dateTime;

    final dateString =
        "${_weekday(dt.weekday)}, ${dt.day} ${_month(dt.month)} ${dt.year}";
    final timeString =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
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
                Text(
                  dateString,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // TIME
            Row(
              children: [
                const Icon(Icons.access_time),
                const SizedBox(width: 8),
                Text(timeString, style: const TextStyle(fontSize: 16)),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),

            // HOST
            const Text(
              "Event Host",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              event.leadName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 20),
            const Divider(),

            // VENUE
            const Text(
              "Venue",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(event.venue, style: const TextStyle(fontSize: 17)),
            if (event.venueAddress.isNotEmpty)
              Text(
                event.venueAddress,
                style: const TextStyle(color: Colors.black54),
              ),

            const SizedBox(height: 20),
            const Divider(),

            // DESCRIPTION
            const Text(
              "Details",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              event.description.isEmpty
                  ? "No description provided."
                  : event.description,
              style: const TextStyle(fontSize: 15),
            ),
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
