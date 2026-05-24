import 'dart:async';

import 'package:flutter/material.dart';
import 'package:runrank/services/chat_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomPage extends StatefulWidget {
  final String threadId;
  final String title;

  const ChatRoomPage({super.key, required this.threadId, required this.title});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<ChatMessage> _messages = const [];
  List<ChatMember> _participants = const [];
  bool _loading = true;
  bool _sending = false;
  Timer? _refreshTimer;
  Color _accent = UserService.clubPrimaryColor(UserService.cachedClubName);

  @override
  void initState() {
    super.initState();
    _loadAccent();
    _loadParticipants();
    _loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  Future<void> _loadParticipants() async {
    final participants = await ChatService.threadParticipants(widget.threadId);
    if (!mounted) return;
    setState(() => _participants = participants);
  }

  Future<void> _loadAccent() async {
    final clubName = await UserService.currentClubName();
    if (!mounted) return;
    setState(() {
      _accent = UserService.clubPrimaryColor(clubName);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final wasNearBottom =
          _scrollCtrl.hasClients &&
          (_scrollCtrl.position.maxScrollExtent - _scrollCtrl.offset) < 80;
      final messages = [...await ChatService.listMessages(widget.threadId)]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await ChatService.markRead(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      if (!silent || wasNearBottom) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load chat: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.sendMessage(widget.threadId, text);
      _messageCtrl.clear();
      await _loadMessages();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leave() async {
    await ChatService.leaveThread(widget.threadId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showMembersSheet() async {
    final participants = await showModalBottomSheet<List<ChatMember>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _ChatMembersSheet(
        threadId: widget.threadId,
        accent: _accent,
        participants: _participants,
      ),
    );
    if (!mounted) return;
    if (participants != null) {
      setState(() => _participants = participants);
    } else {
      await _loadParticipants();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final headerMembers = _participants
        .where((member) => member.id != currentUserId)
        .toList();
    final headerMember = headerMembers.isNotEmpty
        ? headerMembers.first
        : (_participants.isNotEmpty ? _participants.first : null);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatAvatar(member: headerMember, accent: _accent, size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Members and add member',
            onPressed: _showMembersSheet,
            icon: const Icon(Icons.group_add_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Leave chat',
            onPressed: _leave,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final sender =
                          _participants
                              .where((member) => member.id == message.senderId)
                              .cast<ChatMember?>()
                              .firstOrNull ??
                          ChatMember(
                            id: message.senderId ?? '',
                            name: message.senderName,
                            avatarUrl: message.senderAvatarUrl,
                          );
                      return _MessageBubble(
                        message: message,
                        accent: _accent,
                        sender: sender,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF101214),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'send_chat_message',
                    backgroundColor: _accent.withValues(alpha: 0.78),
                    foregroundColor: UserService.readableOn(_accent),
                    onPressed: _sending ? null : _send,
                    child: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Color accent;
  final ChatMember? sender;

  const _MessageBubble({
    required this.message,
    required this.accent,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!mine) ...[
                  _ChatAvatar(member: sender, accent: accent, size: 30),
                  const SizedBox(width: 8),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? accent.withValues(alpha: 0.88)
                        : const Color(0xFF1A2028),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.body,
                    style: TextStyle(
                      color: mine
                          ? UserService.readableOn(accent)
                          : Colors.white,
                    ),
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 8),
                  _ChatAvatar(member: sender, accent: accent, size: 30),
                ],
              ],
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 3,
                left: mine ? 0 : 38,
                right: mine ? 38 : 0,
              ),
              child: Text(
                _formatChatTime(message.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMembersSheet extends StatefulWidget {
  final String threadId;
  final Color accent;
  final List<ChatMember> participants;

  const _ChatMembersSheet({
    required this.threadId,
    required this.accent,
    required this.participants,
  });

  @override
  State<_ChatMembersSheet> createState() => _ChatMembersSheetState();
}

class _ChatMembersSheetState extends State<_ChatMembersSheet> {
  final _searchCtrl = TextEditingController();
  List<ChatMember> _participants = const [];
  List<ChatMember> _members = const [];
  final Set<String> _selectedIds = {};
  final Map<String, ChatMember> _selectedMembers = {};
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _participants = widget.participants;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchMembers() async {
    setState(() => _loading = true);
    final existingIds = _participants.map((member) => member.id).toSet();
    final members = await ChatService.searchMembers(_searchCtrl.text);
    if (!mounted) return;
    setState(() {
      _members = members
          .where((member) => !existingIds.contains(member.id))
          .toList();
      _loading = false;
    });
  }

  Future<void> _addSelected() async {
    if (_selectedMembers.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ChatService.addParticipants(
        widget.threadId,
        _selectedMembers.values.toList(),
      );
      final participants = await ChatService.threadParticipants(
        widget.threadId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(participants);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottom + 18),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chat Members',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final member in _participants)
                  Chip(
                    avatar: _ChatAvatar(
                      member: member,
                      accent: widget.accent,
                      size: 26,
                    ),
                    label: Text(member.name),
                    backgroundColor: const Color(0xFF1A2028),
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide(
                      color: widget.accent.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchMembers(),
                    decoration: const InputDecoration(
                      labelText: 'Add member',
                      prefixIcon: Icon(Icons.person_add_alt_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Search',
                  style: IconButton.styleFrom(
                    backgroundColor: widget.accent.withValues(alpha: 0.78),
                    foregroundColor: UserService.readableOn(widget.accent),
                  ),
                  onPressed: _loading ? null : _searchMembers,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final selected = _selectedIds.contains(member.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _ChatAvatar(
                            member: member,
                            accent: widget.accent,
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Checkbox(
                            value: selected,
                            activeColor: widget.accent,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(member.id);
                                  _selectedMembers.remove(member.id);
                                } else {
                                  _selectedIds.add(member.id);
                                  _selectedMembers[member.id] = member;
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: widget.accent.withValues(alpha: 0.65),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(_participants),
                    child: const Text('OK'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent.withValues(alpha: 0.78),
                      foregroundColor: UserService.readableOn(widget.accent),
                    ),
                    onPressed: _saving || _selectedMembers.isEmpty
                        ? null
                        : _addSelected,
                    icon: const Icon(Icons.group_add_rounded),
                    label: Text(
                      _selectedMembers.isEmpty
                          ? 'Add'
                          : 'Add ${_selectedMembers.length}',
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
}

class _ChatAvatar extends StatelessWidget {
  final ChatMember? member;
  final Color accent;
  final double size;

  const _ChatAvatar({
    required this.member,
    required this.accent,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final url = member?.avatarUrl?.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: accent.withValues(alpha: 0.18),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              _initials(member?.name ?? 'Member'),
              style: TextStyle(
                color: accent,
                fontSize: size < 34 ? 11 : 13,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _formatChatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day}/${local.month} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
