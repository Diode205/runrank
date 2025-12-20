import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/models/club_event.dart';

// Prevent log spam when the backend table is missing.
bool _commentsTableMissing = false;

/// Reusable dialog widgets for event details pages

/// Dialog for selecting relay stages and predicted pace
class RelayRunningDialog extends StatefulWidget {
  final List<Map<String, dynamic>> relayStages;
  final List<int> initialSelectedStages;
  final String? initialPace;

  const RelayRunningDialog({
    required this.relayStages,
    required this.initialSelectedStages,
    required this.initialPace,
  });

  @override
  State<RelayRunningDialog> createState() => RelayRunningDialogState();
}

class RelayRunningDialogState extends State<RelayRunningDialog> {
  late int? selectedStage;
  late TextEditingController _paceController;

  @override
  void initState() {
    super.initState();
    selectedStage = widget.initialSelectedStages.isNotEmpty
        ? widget.initialSelectedStages.first
        : null;
    _paceController = TextEditingController(text: widget.initialPace ?? "");
  }

  @override
  void dispose() {
    _paceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Relay Stage & Pace"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: widget.relayStages.map((stage) {
                  final stageNum = stage['stage'] as int;
                  return RadioListTile<int>(
                    title: Text(
                      "Stage $stageNum: ${stage['distance']} - ${stage['details']}",
                    ),
                    value: stageNum,
                    groupValue: selectedStage,
                    onChanged: (v) {
                      if (!mounted) return;
                      setState(() {
                        selectedStage = v;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            TextField(
              controller: _paceController,
              decoration: const InputDecoration(
                labelText: "Predicted Pace",
                hintText: "Format: MM:SS (e.g., 07:30)",
                helperText: "Minutes and seconds per mile",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'stages': selectedStage != null ? [selectedStage!] : <int>[],
            'pace': _paceController.text.trim(),
          }),
          child: const Text("OK"),
        ),
      ],
    );
  }
}

/// Dialog for selecting support crew roles (timekeeping, cycling, driving, team lead)
class RelaySupportingDialog extends StatefulWidget {
  final List<String> initialSelectedRoles;

  const RelaySupportingDialog({required this.initialSelectedRoles});

  @override
  State<RelaySupportingDialog> createState() => RelaySupportingDialogState();
}

class RelaySupportingDialogState extends State<RelaySupportingDialog> {
  late List<String> selectedRoles;

  @override
  void initState() {
    super.initState();
    selectedRoles = List<String>.from(widget.initialSelectedRoles);
  }

  void _toggleRole(String role, bool? v) {
    if (!mounted) return;
    setState(() {
      if (v == true) {
        if (!selectedRoles.contains(role)) selectedRoles.add(role);
      } else {
        selectedRoles.remove(role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Support Roles"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: const Text("🧭 Timekeeping"),
            value: selectedRoles.contains("timekeeping"),
            onChanged: (v) => _toggleRole("timekeeping", v),
          ),
          CheckboxListTile(
            title: const Text("🚴 Cycling"),
            value: selectedRoles.contains("cycling"),
            onChanged: (v) => _toggleRole("cycling", v),
          ),
          CheckboxListTile(
            title: const Text("🚐 Driving"),
            value: selectedRoles.contains("driving"),
            onChanged: (v) => _toggleRole("driving", v),
          ),
          CheckboxListTile(
            title: const Text("📋 Team Lead"),
            value: selectedRoles.contains("team_lead"),
            onChanged: (v) => _toggleRole("team_lead", v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selectedRoles),
          child: const Text("OK"),
        ),
      ],
    );
  }
}

/// Host chat bottom sheet for messaging the event organizer
class HostChatSheet extends StatefulWidget {
  final ClubEvent event;
  final String hostUserId;
  final String hostDisplayName;
  final TextEditingController messageController;
  final Future<List<Map<String, dynamic>>> Function(String eventId)
  loadMessages;
  final Future<void> Function(String hostUserId, String message) sendMessage;

  const HostChatSheet({
    required this.event,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.messageController,
    required this.loadMessages,
    required this.sendMessage,
  });

  @override
  State<HostChatSheet> createState() => HostChatSheetState();
}

class HostChatSheetState extends State<HostChatSheet> {
  final _headerShadow = BoxShadow(
    color: const Color(0x59000000),
    blurRadius: 16,
    offset: const Offset(0, 10),
  );

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _messages = [];
  ScrollController? _listController;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _listController = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await widget.loadMessages(widget.event.id);
      if (!mounted) return;
      _messages = data;
      _loading = false;
      if (mounted) setState(() {});
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _loading = false;
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load messages: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _listController;
      if (controller == null || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return "";
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _handleSend() async {
    final text = widget.messageController.text.trim();
    if (text.isEmpty || _sending) return;

    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await widget.sendMessage(widget.hostUserId, text);
      if (!mounted) return;
      widget.messageController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        _listController = scrollController;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x38FFD300), Color(0x2E0057B7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.2),
                    boxShadow: [_headerShadow],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFD300),
                                    Color(0xFF0057B7),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.forum,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.event.title ?? 'Event',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Chat with ${widget.hostDisplayName}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(32),
                          children: const [
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start a conversation with the host',
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final msg = _messages[i];
                            final isMine = msg['sender_id'] == currentUserId;
                            final sender =
                                (msg['senderName'] as String?) ??
                                (isMine ? 'You' : widget.hostDisplayName);
                            final ts = _formatTime(
                              msg['created_at'] as String?,
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.75,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? const Color(0xD90057B7)
                                          : Colors.grey.shade800,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white12,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: isMine
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (!isMine)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                sender,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            (msg['message'] as String?) ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (ts.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                ts,
                                                style: const TextStyle(
                                                  color: Color(0x8CFFFFFF),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    border: const Border(
                      top: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: 56,
                            maxHeight: 140,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x59000000),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Photo attachment coming soon',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.photo_library),
                                color: const Color(0xFF0057B7),
                                tooltip: 'Attach photo',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Camera feature coming soon',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.camera_alt),
                                color: const Color(0xFF0057B7),
                                tooltip: 'Take photo',
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: widget.messageController,
                                  maxLines: null,
                                  textInputAction: TextInputAction.newline,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(color: Colors.white38),
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _sending ? null : _handleSend,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                          tooltip: 'Send message',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Comments bottom sheet for event discussion
class CommentsSheet extends StatefulWidget {
  final String eventId;
  final TextEditingController commentController;
  final Future<void> Function() onCommentSubmitted;

  const CommentsSheet({
    required this.eventId,
    required this.commentController,
    required this.onCommentSubmitted,
  });

  @override
  State<CommentsSheet> createState() => CommentsSheetState();
}

class CommentsSheetState extends State<CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await getCommentsWithNames(eventId: widget.eventId);
      if (!mounted) return;
      setState(() {
        _comments = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: const [
                      Icon(Icons.chat_bubble_outline, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Comments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          children: const [
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 64,
                                      color: Colors.white24,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Start the conversation',
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            final name = c['fullName'] as String? ?? 'User';
                            final text = c['comment'] as String? ?? '';
                            final ts = c['timestamp'] as String?;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white10,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    text,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (ts != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        ts,
                                        style: const TextStyle(
                                          color: Colors.white30,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white10),
                          itemCount: _comments.length,
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    border: const Border(
                      top: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0x59000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Add coming soon'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, color: Colors.white70),
                          tooltip: 'Add',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: widget.commentController,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.grey.shade800,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD300), Color(0xFF0057B7)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () async {
                            if (widget.commentController.text.trim().isEmpty) {
                              return;
                            }
                            if (!mounted) return;
                            await widget.onCommentSubmitted();
                            widget.commentController.clear();
                            if (!mounted) return;
                            await _loadComments();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comment posted'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                          ),
                          tooltip: 'Post comment',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper to fetch comments with user names
Future<List<Map<String, dynamic>>> getCommentsWithNames({
  required String eventId,
}) async {
  if (_commentsTableMissing) return [];

  final supabase = Supabase.instance.client;
  try {
    final commentRows = await supabase
        .from('event_comments')
        .select('user_id, comment, timestamp')
        .eq('event_id', eventId)
        .order('timestamp');

    if (commentRows.isEmpty) return [];

    final userIds = <String>{
      for (final row in commentRows) row['user_id'] as String,
    }.toList();
    final orFilter = userIds.map((id) => 'id.eq.$id').join(',');
    final profileRows = await supabase
        .from('user_profiles')
        .select('id, full_name')
        .or(orFilter);

    final Map<String, String> idToName = {
      for (final p in profileRows)
        p['id'] as String: (p['full_name'] as String?) ?? 'Unknown user',
    };

    return [
      for (final c in commentRows)
        {
          'userId': c['user_id'] as String?,
          'fullName': idToName[(c['user_id'] as String?) ?? ''] ?? 'Unknown',
          'comment': c['comment'] as String?,
          'timestamp': c['timestamp'] as String?,
        },
    ];
  } on PostgrestException catch (e) {
    if (e.code == 'PGRST205') {
      // Table likely missing; flip flag to silence future attempts until app restart.
      _commentsTableMissing = true;
      debugPrint('event_comments table missing; skipping comment fetches');
      return [];
    }
    debugPrint('❌ Error fetching comments with names: $e');
    return [];
  } catch (e) {
    debugPrint('❌ Error fetching comments with names: $e');
    return [];
  }
}
