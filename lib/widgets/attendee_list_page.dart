import 'package:flutter/material.dart';
import 'package:runrank/services/event_response_service.dart';

class AttendeeListPage extends StatefulWidget {
  final String eventId;
  final String
  responseType; // attending, running, marshalling, supporting, unavailable
  final String title;
  final bool showExpectedTime; // true only for handicap "running" list

  const AttendeeListPage({
    super.key,
    required this.eventId,
    required this.responseType,
    required this.title,
    this.showExpectedTime = false,
  });

  @override
  State<AttendeeListPage> createState() => _AttendeeListPageState();
}

class _AttendeeListPageState extends State<AttendeeListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _attendees = [];

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _loading = true);
    final attendees = await EventResponseService.getRespondersWithNames(
      eventId: widget.eventId,
      responseType: widget.responseType,
    );
    if (!mounted) return;
    setState(() {
      _attendees = attendees;
      _loading = false;
    });
  }

  String _formatExpectedTimeSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');

    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _attendees.isEmpty
          ? const Center(
              child: Text(
                'No responses yet.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (_, index) {
                final a = _attendees[index];
                final name = a['fullName'] as String? ?? 'Unknown runner';
                final expected = a['expectedTimeSeconds'] as int?;

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.grey.shade100,
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: widget.showExpectedTime && expected != null
                      ? Text(
                          'Expected time: ${_formatExpectedTimeSeconds(expected)}',
                        )
                      : null,
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _attendees.length,
            ),
    );
  }
}
