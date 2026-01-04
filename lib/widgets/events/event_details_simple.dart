import 'package:flutter/material.dart';
import 'package:runrank/models/club_event.dart';
import 'package:runrank/widgets/events/event_details_base.dart';
import 'package:runrank/widgets/events/event_details_dialogs.dart';
import 'package:runrank/widgets/events/event_venue_preview.dart';

/// Event details page for simple events (Training, Special Event, Social Run, etc.)
/// Group 1: Training_1/2, Special_Event, Social_Run, Meet_&_Drink, Swim_or_Cycle, Others
class SimpleEventDetailsPage extends StatefulWidget {
  final ClubEvent event;

  const SimpleEventDetailsPage({super.key, required this.event});

  @override
  State<SimpleEventDetailsPage> createState() => _SimpleEventDetailsPageState();
}

class _SimpleEventDetailsPageState extends State<SimpleEventDetailsPage>
    with EventDetailsBaseMixin<SimpleEventDetailsPage> {
  @override
  ClubEvent get event => widget.event;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final dt = e.dateTime;

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
                        Colors.grey.shade800.withValues(alpha: 0.5),
                        Colors.grey.shade900.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                            ? "No extra details yet. Check the map & weather above or contact the host if you have questions."
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
                  EventVenuePreview(event: e, onOpenMaps: openMaps),
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

                // Participant counts
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withValues(alpha: 0.5),
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
                buildInlineCommentsPreview(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
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
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white12,
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          minLines: 1,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            isCollapsed: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) async {
                            await _submitComment();
                            commentController.clear();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white70),
                        onPressed: () async {
                          if (commentController.text.trim().isEmpty) return;
                          await _submitComment();
                          commentController.clear();
                        },
                      ),
                    ],
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => myResponse = null),
                child: const Text("Edit Participation"),
              ),
            ],
          ),
        ),
      );
    }

    // Show simple buttons for new response
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FilledButton(
          onPressed: () => submitResponse(type: "run"),
          child: const Text("✅ Attending"),
        ),
        FilledButton(
          onPressed: () => submitResponse(type: "unavailable"),
          child: const Text("❌ Decline"),
        ),
      ],
    );
  }

  Widget _buildParticipantLine(
    String label,
    int count,
    List<Map<String, dynamic>> participants, {
    String? responseType,
  }) {
    return InkWell(
      onTap: count > 0
          ? () {
              if (responseType != null) {
                _showParticipantsByType(label, responseType);
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
    final answeredCount = runners.length + unavailable.length;
    final unansweredCount = ((totalUsers - answeredCount) < 0)
        ? 0
        : (totalUsers - answeredCount);

    return [
      _buildParticipantLine(
        "✅ Attending",
        runners.length,
        runners,
        responseType: 'running',
      ),
      _buildParticipantLine(
        "❌ Declined",
        unavailable.length,
        unavailable,
        responseType: 'unavailable',
      ),
      _buildParticipantLine("❓ Unanswered", unansweredCount, []),
    ];
  }

  Future<void> _contactHost() async {
    final hostUserId =
        widget.event.hostUserId ??
        widget.event.createdBy ??
        supabase.auth.currentUser?.id;
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

    await addComment(comment);
  }

  Future<void> _showParticipantsByType(
    String title,
    String responseType,
  ) async {
    final attendees = await getRespondersWithNames(
      eventId: widget.event.id,
      responseType: responseType,
    );

    if (!mounted) return;
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
                    return ListTile(title: Text(name));
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
