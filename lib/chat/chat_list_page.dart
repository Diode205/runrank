import 'dart:async';

import 'package:flutter/material.dart';
import 'package:runrank/chat/chat_room_page.dart';
import 'package:runrank/services/chat_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  List<ChatThread> _threads = const [];
  Timer? _refreshTimer;
  Color _accent = UserService.clubPrimaryColor(UserService.cachedClubName);
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadAccent();
    _loadThreads();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadThreads(silent: true),
    );
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
    super.dispose();
  }

  Future<void> _loadThreads({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final threads = await ChatService.listThreads(archived: _showArchived);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load chats: $e')));
    }
  }

  Future<void> _openThread(ChatThread thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          threadId: thread.id,
          title: thread.title,
          subtitle: thread.subtitle,
        ),
      ),
    );
    _loadThreads();
  }

  Future<void> _showNewChatSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _NewChatSheet(accent: _accent),
    );
    _loadThreads();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Active chats' : 'Archived chats',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadThreads();
            },
            icon: Icon(
              _showArchived ? Icons.chat_bubble_rounded : Icons.archive_rounded,
              color: _showArchived ? _accent : Colors.white,
            ),
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              backgroundColor: _accent.withValues(alpha: 0.78),
              foregroundColor: UserService.readableOn(_accent),
              onPressed: _showNewChatSheet,
              child: const Icon(Icons.add_comment_rounded),
            ),
      body: RefreshIndicator(
        onRefresh: _loadThreads,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _threads.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: _accent,
                    size: 54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showArchived ? 'No archived chats' : 'No chats yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showArchived
                        ? 'Archived conversations will appear here. New replies will bring them back to your active chats.'
                        : 'Start a one-to-one chat or create a group chat with club members.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _threads.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final thread = _threads[index];
                  return Dismissible(
                    key: ValueKey('${_showArchived}_${thread.id}'),
                    background: _SwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      color: _showArchived
                          ? _accent.withValues(alpha: 0.9)
                          : Colors.blueGrey,
                      icon: _showArchived
                          ? Icons.unarchive_rounded
                          : Icons.archive_rounded,
                      label: _showArchived ? 'Restore' : 'Archive',
                    ),
                    secondaryBackground: const _SwipeActionBackground(
                      alignment: Alignment.centerRight,
                      color: Colors.redAccent,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                    ),
                    confirmDismiss: (direction) async {
                      if (_showArchived ||
                          direction == DismissDirection.startToEnd) {
                        if (_showArchived) {
                          await ChatService.unarchiveThread(thread.id);
                        } else {
                          await ChatService.archiveThread(thread.id);
                        }
                      } else {
                        await ChatService.deleteOwnThread(thread.id);
                      }
                      await _loadThreads(silent: true);
                      return false;
                    },
                    child: _ChatThreadTile(
                      thread: thread,
                      accent: _accent,
                      currentUserId: currentUserId,
                      onTap: () => _openThread(thread),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ChatThreadTile extends StatelessWidget {
  final ChatThread thread;
  final Color accent;
  final String? currentUserId;
  final VoidCallback onTap;

  const _ChatThreadTile({
    required this.thread,
    required this.accent,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF11161D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: thread.hasUnread
                ? accent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ChatAvatarStack(
                  members: !thread.isGroup && currentUserId != null
                      ? thread.participants
                            .where((member) => member.id != currentUserId)
                            .toList()
                      : thread.participants,
                  accent: accent,
                  isGroup: thread.isGroup,
                ),
                if (thread.hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (thread.subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      thread.subtitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: thread.hasUnread ? accent : Colors.white60,
                          ),
                        ),
                      ),
                      if (thread.lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatChatTime(thread.lastMessageAt!),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (thread.isGroup) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${thread.participants.length} members',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (thread.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  thread.unreadCount.toString(),
                  style: TextStyle(
                    color: UserService.readableOn(accent),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final left = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!left) Text(label, style: const TextStyle(color: Colors.white)),
          if (!left) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (left) const SizedBox(width: 8),
          if (left) Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ChatAvatarStack extends StatelessWidget {
  final List<ChatMember> members;
  final Color accent;
  final bool isGroup;

  const _ChatAvatarStack({
    required this.members,
    required this.accent,
    required this.isGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGroup || members.length <= 1) {
      final member = members.isEmpty ? null : members.first;
      return _ChatAvatar(member: member, accent: accent);
    }

    final shown = members.take(2).toList();
    return SizedBox(
      width: 46,
      height: 42,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: _ChatAvatar(member: shown.first, accent: accent, size: 34),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _ChatAvatar(member: shown.last, accent: accent, size: 34),
          ),
        ],
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
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final url = member?.avatarUrl?.trim();
    final initials = _initials(member?.name ?? 'Member');
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: accent.withValues(alpha: 0.18),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: size < 40 ? 12 : 14,
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
  final now = DateTime.now();
  final local = dateTime.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (now.year == local.year &&
      now.month == local.month &&
      now.day == local.day) {
    return time;
  }
  return '${local.day}/${local.month} $time';
}

class _NewChatSheet extends StatefulWidget {
  final Color accent;

  const _NewChatSheet({required this.accent});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final _searchCtrl = TextEditingController();
  final _groupTitleCtrl = TextEditingController();
  List<ChatMember> _members = const [];
  final Set<String> _selectedIds = {};
  final Map<String, ChatMember> _selectedMembers = {};
  bool _groupMode = false;
  bool _loading = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupTitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final members = await ChatService.searchMembers(_searchCtrl.text);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _startDirect(ChatMember member) async {
    setState(() => _saving = true);
    try {
      final threadId = await ChatService.createDirectChat(member);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(threadId: threadId, title: member.name),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createGroup() async {
    if (_selectedMembers.isEmpty) return;
    setState(() => _saving = true);
    try {
      final threadId = await ChatService.createGroupChat(
        title: _groupTitleCtrl.text,
        members: _selectedMembers.values.toList(),
      );
      if (!mounted) return;
      final title = _groupTitleCtrl.text.trim();
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(threadId: threadId, title: title),
        ),
      );
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'New Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _groupMode,
                  activeThumbColor: widget.accent,
                  onChanged: (value) => setState(() => _groupMode = value),
                ),
                const Text('Group', style: TextStyle(color: Colors.white70)),
              ],
            ),
            if (_groupMode) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _groupTitleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Group title',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _loadMembers(),
              decoration: const InputDecoration(
                labelText: 'Search members',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _members.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.trim().isEmpty
                            ? 'Type a name to search members'
                            : 'No members found',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final selected = _selectedIds.contains(member.id);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            child: Text(
                              member.name.trim().isEmpty
                                  ? '?'
                                  : member.name.trim()[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: _groupMode
                              ? Checkbox(
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
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                ),
                          onTap: _saving
                              ? null
                              : _groupMode
                              ? () {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(member.id);
                                      _selectedMembers.remove(member.id);
                                    } else {
                                      _selectedIds.add(member.id);
                                      _selectedMembers[member.id] = member;
                                    }
                                  });
                                }
                              : () => _startDirect(member),
                        );
                      },
                    ),
            ),
            if (_groupMode)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accent.withValues(alpha: 0.78),
                  foregroundColor: UserService.readableOn(widget.accent),
                ),
                onPressed: _saving ? null : _createGroup,
                icon: const Icon(Icons.groups_rounded),
                label: Text(
                  _selectedMembers.isEmpty
                      ? 'Select members'
                      : 'Create group (${_selectedMembers.length})',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
