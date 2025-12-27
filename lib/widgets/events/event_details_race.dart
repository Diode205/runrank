import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/events/event_details_base.dart';
import 'package:runrank/widgets/events/event_details_dialogs.dart';
// import removed: notification_service (not used here)
import 'package:runrank/services/weather_service.dart';
// import removed: admin_edit_event_page.dart (controls moved to calendar)

/// Event details page for race events (Race, Handicap_Series)
/// Group 2: Race and Handicap_Series with marshal call dates and predicted finish times
class RaceEventDetailsPage extends StatefulWidget {
  final ClubEvent event;

  const RaceEventDetailsPage({super.key, required this.event});

  @override
  State<RaceEventDetailsPage> createState() => _RaceEventDetailsPageState();
}

class _RaceEventDetailsPageState extends State<RaceEventDetailsPage>
    with EventDetailsBaseMixin<RaceEventDetailsPage> {
  WeatherAtTime? _weather;
  bool _weatherLoading = false;
  String? _weatherError;

  @override
  ClubEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;
    // current user not used directly in this page

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          e.title ?? "Event Details",
          style: const TextStyle(fontWeight: FontWeight.bold),
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
              children: [
                // Cancelled event banner
                ...(e.isCancelled
                    ? [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0x4DFF0000),
                                const Color(0x1AFF0000),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x80FF0000),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "CANCELLED — ${e.cancelReason ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]
                    : []),

                // Event header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade800.withValues(
                          alpha: Colors.grey.shade800.opacity * 0.5,
                        ),
                        Colors.grey.shade900.withValues(
                          alpha: Colors.grey.shade900.opacity * 0.5,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x33FFD300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month,
                              color: Color(0xFFFFD300),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${weekday(dt)}, ${dt.day} ${month(dt.month)} ${dt.year}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Time row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x330057B7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.access_time,
                              color: Color(0xFF0057B7),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: Colors.white12),

                      // Hosted By
                      Text(
                        "Hosted By",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.hostOrDirector.isNotEmpty
                            ? e.hostOrDirector
                            : "Not specified",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Divider(height: 32, color: Colors.white12),

                      // Venue
                      Text(
                        "Venue",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.venue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      ...(e.venueAddress.isNotEmpty
                          ? [
                              const SizedBox(height: 4),
                              Text(
                                e.venueAddress,
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ]
                          : []),
                      ...(e.latitude != null && e.longitude != null
                          ? [
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: openMaps,
                                icon: const Icon(Icons.map),
                                label: const Text("Open in Maps"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFD300),
                                  side: const BorderSide(
                                    color: Color(0xFFFFD300),
                                  ),
                                ),
                              ),
                            ]
                          : []),
                      const Divider(height: 32, color: Colors.white12),

                      // Details
                      Text(
                        "Details",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.description.isEmpty
                            ? "No description provided."
                            : e.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.latitude != null && e.longitude != null) ...[
                  const SizedBox(height: 20),
                  _buildMapAndWeatherCard(e),
                ],
                const SizedBox(height: 24),

                // Responses section
                Text(
                  "Responses",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFD300),
                  ),
                ),
                const SizedBox(height: 8),
                _buildParticipationSection(),
                const SizedBox(height: 20),

                // Admin controls moved to swipe on calendar
                // Edit (left-to-right) and Cancel (right-to-left)

                // Participant counts
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withValues(
                      alpha: Colors.grey.shade900.opacity * 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Builder(
                    builder: (_) {
                      final items = _getParticipantLines();
                      final children = <Widget>[];
                      for (var i = 0; i < items.length; i++) {
                        children.add(items[i]);
                        if (i < items.length - 1) {
                          children.add(
                            const Divider(height: 1, color: Colors.white12),
                          );
                        }
                      }
                      return Column(children: children);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Message host button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0057B7), Color(0xFF003F8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x4D0057B7),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _contactHost(),
                    icon: const Icon(Icons.message),
                    label: const Text("Message Host/Coach"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Comments section
                Text("Comments", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openCommentsSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x40000000),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x40000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white12,
                          child: Icon(
                            Icons.add,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Add a comment...",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_up, color: Colors.white38),
                      ],
                    ),
                  ),
                ),

                // Admin controls moved to swipe on calendar
                // Edit (left-to-right) and Cancel (right-to-left)
              ],
            ),
    );
  }

  Widget _buildParticipationSection() {
    final hasResponse = myResponse != null;
    if (widget.event.isCancelled) return const SizedBox.shrink();

    if (hasResponse) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your choice",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                "• Type: ${myResponse!["response_type"]}",
                style: const TextStyle(fontSize: 16),
              ),
              if (myPredictedFinishHHMMSS != null) ...[
                const SizedBox(height: 6),
                Text("• Predicted finish: $myPredictedFinishHHMMSS"),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => myResponse = null),
                    child: const Text("Edit"),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: cancelMyPlan,
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Show race/handicap buttons for new response
    final marshalDate = widget.event.marshalCallDate;
    final canMarshal =
        marshalDate == null || DateTime.now().isAfter(marshalDate);
    final isHandicap =
        widget.event.eventType.toLowerCase() == "handicap_series";

    return Column(
      children: [
        if (marshalDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Marshal Call Date On: ${weekday(marshalDate)}, ${marshalDate.day} ${month(marshalDate.month)} ${marshalDate.year}",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Run button (with time input for handicap)
            FilledButton(
              onPressed: isHandicap
                  ? () => _showHandicapFinishTimeDialog()
                  : () => submitResponse(type: "run"),
              child: Text(
                isHandicap ? "🏃🏽" : "🏃‍♀️",
                style: const TextStyle(fontSize: 24),
              ),
            ),
            // Marshal button
            FilledButton(
              onPressed: canMarshal
                  ? () => submitResponse(type: "volunteer")
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "You will be notified when Marshall call is opened",
                        ),
                      ),
                    ),
              child: const Text("🦺", style: TextStyle(fontSize: 24)),
            ),
            // Unavailable button
            FilledButton(
              onPressed: () => submitResponse(type: "unavailable"),
              child: const Text("❌", style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadWeather() async {
    final lat = event.latitude;
    final lng = event.longitude;
    if (lat == null || lng == null) return;

    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      final result = await WeatherService.fetchWeather(
        latitude: lat,
        longitude: lng,
        when: event.dateTime,
      );

      if (!mounted) return;
      setState(() {
        _weather = result;
        _weatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = "Weather unavailable right now";
        _weatherLoading = false;
      });
    }
  }

  Widget _buildMapAndWeatherCard(ClubEvent e) {
    final lat = e.latitude!;
    final lng = e.longitude!;
    final mapUrl = _mapPreviewUrl(lat, lng);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withValues(
          alpha: Colors.grey.shade900.opacity * 0.6,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Venue Preview",
            style: TextStyle(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      mapUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.map_outlined,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: openMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text("Directions"),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0057B7),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildWeatherStrip(),
        ],
      ),
    );
  }

  Widget _buildWeatherStrip() {
    if (_weatherLoading) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text("Loading weather...", style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (_weather != null) {
      final w = _weather!;
      return Row(
        children: [
          Icon(_weatherIcon(w.code), color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            "${w.tempC.round()}°C • ${w.windMph.round()} mph",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              w.description,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    if (_weatherError != null) {
      return Text(
        _weatherError!,
        style: const TextStyle(color: Colors.white70),
      );
    }

    return const Text(
      "Weather not available",
      style: TextStyle(color: Colors.white70),
    );
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.wb_cloudy_rounded;
    if (code == 3 || code == 45 || code == 48) return Icons.cloud;
    if (code >= 51 && code <= 67) return Icons.grain_rounded;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }
    if ((code >= 80 && code <= 82) || (code >= 61 && code <= 65)) {
      return Icons.grain_rounded;
    }
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_queue;
  }

  String _mapPreviewUrl(double lat, double lng) {
    return "https://staticmap.openstreetmap.de/staticmap.php"
        "?center=$lat,$lng&zoom=14&size=600x300&markers=$lat,$lng,red-pushpin";
  }

  Widget _buildParticipantLine(
    String label,
    int count,
    List<Map<String, dynamic>> participants, {
    String? responseType,
    bool showExpectedTime = false,
  }) {
    return InkWell(
      onTap: count > 0
          ? () {
              if (responseType != null) {
                _showParticipantsByType(
                  label,
                  responseType,
                  showExpectedTime: showExpectedTime,
                );
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _getParticipantLines() {
    final isHandicap =
        widget.event.eventType.toLowerCase() == "handicap_series";

    return [
      _buildParticipantLine(
        "🏃‍♀️ Running",
        runners.length,
        runners,
        responseType: 'running',
        showExpectedTime: isHandicap,
      ),
      _buildParticipantLine(
        "🦺 Marshalling",
        volunteers.length,
        volunteers,
        responseType: 'marshalling',
      ),
      _buildParticipantLine(
        "❌ Unavailable",
        unavailable.length,
        unavailable,
        responseType: 'unavailable',
      ),
    ];
  }

  Future<void> _showHandicapFinishTimeDialog() async {
    final timeController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Predicted finish time"),
        content: TextField(
          controller: timeController,
          decoration: const InputDecoration(labelText: "HH:MM:SS"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (RegExp(r"^\d\d:\d\d:\d\d$").hasMatch(timeController.text)) {
        final secs = hhmmssToSeconds(timeController.text);
        submitResponse(type: "run", predictedTimeSeconds: secs);
      }
    }
  }

  Future<void> _contactHost() async {
    final hostUserId = widget.event.createdBy ?? supabase.auth.currentUser?.id;
    if (hostUserId == null || hostUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No creator id found for this event. Please re-save the event.",
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HostChatSheet(
        event: widget.event,
        hostUserId: hostUserId,
        hostDisplayName: widget.event.hostOrDirector.isNotEmpty
            ? widget.event.hostOrDirector
            : "Host / Coach",
        messageController: messageController,
        loadMessages: getHostMessagesWithNames,
        sendMessage: sendHostMessage,
      ),
    );
  }

  Future<void> _submitComment() async {
    final comment = commentController.text.trim();
    if (comment.isEmpty) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from("event_comments").insert({
      "event_id": widget.event.id,
      "user_id": user.id,
      "comment": comment,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }

  Future<void> _openCommentsSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        eventId: widget.event.id,
        commentController: commentController,
        onCommentSubmitted: _submitComment,
      ),
    );
  }

  // Legacy cancel/delete methods removed (controls are now via calendar swipes)

  Future<void> _showParticipantsByType(
    String title,
    String responseType, {
    bool showExpectedTime = false,
  }) async {
    final attendees = await getRespondersWithNames(
      eventId: widget.event.id,
      responseType: responseType,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: attendees.isEmpty
              ? const Center(
                  child: Text(
                    "No participants yet",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: attendees.length,
                  itemBuilder: (_, i) {
                    final a = attendees[i];
                    final name = a['fullName'] as String? ?? 'Unknown runner';
                    final expected = a['expectedTimeSeconds'] as int?;
                    return ListTile(
                      title: Text(name),
                      subtitle: showExpectedTime && expected != null
                          ? Text('Predicted time: ${secondsToHHMMSS(expected)}')
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
