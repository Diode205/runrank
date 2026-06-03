import 'package:flutter/material.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _canView = false;
  List<Map<String, dynamic>> _attendees = [];

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() => _loading = true);
    final canView = await _canCurrentUserViewList();
    if (!canView) {
      if (!mounted) return;
      setState(() {
        _canView = false;
        _attendees = [];
        _loading = false;
      });
      return;
    }

    final attendees = await getRespondersWithNames(
      eventId: widget.eventId,
      responseType: widget.responseType,
    );
    if (!mounted) return;
    setState(() {
      _canView = true;
      _attendees = attendees;
      _loading = false;
    });
  }

  Future<bool> _canCurrentUserViewList() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final event = await supabase
          .from('club_events')
          .select('created_by, host_user_id')
          .eq('id', widget.eventId)
          .maybeSingle();
      if (event?['created_by'] == userId || event?['host_user_id'] == userId) {
        return true;
      }
      return await UserService.isAdmin();
    } catch (e) {
      debugPrint('Error checking attendee list permissions: $e');
      return false;
    }
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
          : !_canView
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Response lists are visible only to admins and this event host.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ),
            )
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

Future<List<Map<String, dynamic>>> getRespondersWithNames({
  required String eventId,
  required String responseType,
}) async {
  final supabase = Supabase.instance.client;
  try {
    final responseRows = await supabase
        .from('club_event_responses')
        .select('user_id, expected_time_seconds')
        .eq('event_id', eventId)
        .eq('response_type', responseType);

    if (responseRows.isEmpty) return [];

    final userIds = <String>{
      for (final row in responseRows) row['user_id'] as String,
    }.toList();
    final orFilter = userIds.map((id) => 'id.eq.$id').join(',');
    final profileRows = await supabase
        .from('user_profiles')
        .select('id, full_name')
        .or(orFilter);

    final Map<String, String> idToName = {
      for (final p in profileRows)
        p['id'] as String: (p['full_name'] as String?) ?? 'Unknown runner',
    };

    return [
      for (final row in responseRows)
        {
          'userId': row['user_id'] as String,
          'fullName': idToName[row['user_id'] as String] ?? 'Unknown runner',
          'expectedTimeSeconds': row['expected_time_seconds'] as int?,
        },
    ];
  } catch (e) {
    debugPrint('Error fetching responders with names: $e');
    return [];
  }
}
