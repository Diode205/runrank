import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';
import 'package:runrank/services/user_service.dart';

class ChatMember {
  final String id;
  final String name;
  final String? avatarUrl;

  const ChatMember({required this.id, required this.name, this.avatarUrl});
}

class ChatMessage {
  final String id;
  final String threadId;
  final String? senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });
}

class ChatThread {
  final String id;
  final String title;
  final String? subtitle;
  final String? contextTitle;
  final DateTime? contextDate;
  final bool isGroup;
  final String? createdBy;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<ChatMember> participants;

  const ChatThread({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.contextTitle,
    required this.contextDate,
    required this.isGroup,
    required this.createdBy,
    required this.updatedAt,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.participants,
  });

  bool get hasUnread => unreadCount > 0;
}

class ChatService {
  ChatService._();

  static final _supabase = Supabase.instance.client;
  static bool _cleanupAttempted = false;

  static Future<String?> _currentClubKey() async {
    final club = await UserService.currentClubName();
    return NotificationService.canonicalClubName(club).trim();
  }

  static Future<Map<String, String>> _namesForUserIds(
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) return const {};
    final rows = await _supabase
        .from('user_profiles')
        .select('id, full_name')
        .inFilter('id', uniqueIds.toList());
    return {
      for (final row in rows as List)
        (row as Map)['id'] as String:
            ((row['full_name'] as String?)?.trim().isNotEmpty ?? false)
            ? row['full_name'] as String
            : 'Member',
    };
  }

  static Future<Map<String, String?>> _avatarsForUserIds(
    Iterable<String> ids,
  ) async {
    final uniqueIds = ids.where((id) => id.trim().isNotEmpty).toSet();
    if (uniqueIds.isEmpty) return const {};
    final rows = await _supabase
        .from('user_profiles')
        .select('id, avatar_url')
        .inFilter('id', uniqueIds.toList());
    return {
      for (final row in rows as List)
        (row as Map)['id'] as String: row['avatar_url'] as String?,
    };
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static Future<List<ChatMember>> searchMembers(String query) async {
    final user = _supabase.auth.currentUser;
    final club = await _currentClubKey();
    if (user == null || club == null || club.isEmpty) return const [];

    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final rows = await _supabase
        .from('user_profiles')
        .select('id, full_name, avatar_url')
        .eq('club', club)
        .neq('id', user.id)
        .ilike('full_name', '%$trimmed%')
        .order('full_name')
        .limit(40);
    return [
      for (final row in rows as List)
        ChatMember(
          id: (row as Map)['id'] as String,
          name: ((row['full_name'] as String?)?.trim().isNotEmpty ?? false)
              ? row['full_name'] as String
              : 'Member',
          avatarUrl: row['avatar_url'] as String?,
        ),
    ];
  }

  static Future<List<ChatThread>> listThreads({bool archived = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];
    await cleanupOldChats();

    var participantQuery = _supabase
        .from('chat_participants')
        .select('thread_id, last_read_at')
        .eq('user_id', user.id)
        .filter('left_at', 'is', null);
    participantQuery = archived
        ? participantQuery.not('archived_at', 'is', null)
        : participantQuery.filter('archived_at', 'is', null);
    final participantRows = await participantQuery;

    final threadIds = [
      for (final row in participantRows as List)
        (row as Map)['thread_id'] as String,
    ];
    if (threadIds.isEmpty) return const [];

    final lastReadByThread = {
      for (final row in participantRows)
        (row as Map)['thread_id'] as String: _date(row['last_read_at']),
    };

    final threadRows = await _supabase
        .from('chat_threads')
        .select(
          'id, title, context_title, context_date, is_group, created_by, updated_at',
        )
        .inFilter('id', threadIds)
        .order('updated_at', ascending: false);

    final allParticipantRows = await _supabase
        .from('chat_participants')
        .select('thread_id, user_id, left_at')
        .inFilter('thread_id', threadIds)
        .filter('left_at', 'is', null);

    final participantIdsByThread = <String, List<String>>{};
    final allUserIds = <String>{};
    for (final row in allParticipantRows as List) {
      final map = row as Map;
      final threadId = map['thread_id'] as String;
      final userId = map['user_id'] as String;
      participantIdsByThread.putIfAbsent(threadId, () => []).add(userId);
      allUserIds.add(userId);
    }
    final names = await _namesForUserIds(allUserIds);
    final avatars = await _avatarsForUserIds(allUserIds);

    final latestRows = await _supabase
        .from('chat_messages')
        .select('thread_id, body, created_at, sender_id')
        .inFilter('thread_id', threadIds)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    final latestByThread = <String, Map<String, dynamic>>{};
    final unreadByThread = <String, int>{};
    for (final row in latestRows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final threadId = map['thread_id'] as String;
      latestByThread.putIfAbsent(threadId, () => map);
      final createdAt = _date(map['created_at']);
      final lastReadAt = lastReadByThread[threadId];
      final senderId = map['sender_id'] as String?;
      if (createdAt != null &&
          senderId != user.id &&
          (lastReadAt == null || createdAt.isAfter(lastReadAt))) {
        unreadByThread[threadId] = (unreadByThread[threadId] ?? 0) + 1;
      }
    }

    return [
      for (final row in threadRows as List)
        _threadFromRow(
          Map<String, dynamic>.from(row as Map),
          participantIdsByThread[row['id']] ?? const [],
          names,
          avatars,
          latestByThread[row['id']],
          unreadByThread[row['id']] ?? 0,
          user.id,
        ),
    ];
  }

  static ChatThread _threadFromRow(
    Map<String, dynamic> row,
    List<String> participantIds,
    Map<String, String> names,
    Map<String, String?> avatars,
    Map<String, dynamic>? latest,
    int unreadCount,
    String currentUserId,
  ) {
    final isGroup = row['is_group'] as bool? ?? false;
    final participants = [
      for (final id in participantIds)
        ChatMember(id: id, name: names[id] ?? 'Member', avatarUrl: avatars[id]),
    ];
    final explicitTitle = (row['title'] as String?)?.trim();
    final contextTitle = (row['context_title'] as String?)?.trim();
    final contextDate = _date(row['context_date']);
    final title = isGroup
        ? (explicitTitle?.isNotEmpty == true ? explicitTitle! : 'Group chat')
        : participants
              .where((p) => p.id != currentUserId)
              .map((p) => p.name)
              .join(', ');
    final contextSubtitle = _contextSubtitle(contextTitle, contextDate);

    return ChatThread(
      id: row['id'] as String,
      title: title.isEmpty ? 'Chat' : title,
      subtitle: contextSubtitle,
      contextTitle: contextTitle?.isNotEmpty == true ? contextTitle : null,
      contextDate: contextDate,
      isGroup: isGroup,
      createdBy: row['created_by'] as String?,
      updatedAt: _date(row['updated_at']) ?? DateTime.now(),
      lastMessage: latest?['body'] as String?,
      lastMessageAt: _date(latest?['created_at']),
      unreadCount: unreadCount,
      participants: participants,
    );
  }

  static String? _contextSubtitle(String? title, DateTime? date) {
    final cleanTitle = title?.trim();
    final hasTitle = cleanTitle != null && cleanTitle.isNotEmpty;
    if (!hasTitle && date == null) return null;
    if (date == null) return cleanTitle;
    final dateText = '${date.day} ${_monthName(date.month)} ${date.year}';
    return hasTitle ? '$cleanTitle • $dateText' : dateText;
  }

  static String? formatThreadContext(String? title, DateTime? date) {
    return _contextSubtitle(title, date);
  }

  static String _monthName(int month) {
    const names = [
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
    return names[(month - 1).clamp(0, 11)];
  }

  static Future<String> createDirectChat(
    ChatMember member, {
    String? contextTitle,
    DateTime? contextDate,
  }) async {
    final user = _supabase.auth.currentUser;
    final club = await _currentClubKey();
    if (user == null || club == null || club.isEmpty) {
      throw StateError('You must be signed in to start a chat.');
    }

    final threads = [
      ...await listThreads(),
      ...await listThreads(archived: true),
    ];
    final cleanContextTitle = contextTitle?.trim();
    final contextDateOnly = contextDate == null
        ? null
        : DateTime(contextDate.year, contextDate.month, contextDate.day);
    for (final thread in threads) {
      final sameContextTitle =
          (thread.contextTitle ?? '') == (cleanContextTitle ?? '');
      final sameContextDate =
          thread.contextDate?.year == contextDateOnly?.year &&
          thread.contextDate?.month == contextDateOnly?.month &&
          thread.contextDate?.day == contextDateOnly?.day;
      if (!thread.isGroup &&
          thread.participants.any((p) => p.id == member.id) &&
          thread.participants.any((p) => p.id == user.id) &&
          sameContextTitle &&
          sameContextDate) {
        await unarchiveThread(thread.id);
        return thread.id;
      }
    }

    final thread = await _supabase
        .from('chat_threads')
        .insert({
          'club': club,
          'is_group': false,
          'created_by': user.id,
          if (cleanContextTitle != null && cleanContextTitle.isNotEmpty)
            'context_title': cleanContextTitle,
          if (contextDateOnly != null)
            'context_date': contextDateOnly.toIso8601String().split('T').first,
        })
        .select('id')
        .single();
    final threadId = thread['id'] as String;
    await _supabase.from('chat_participants').insert([
      {
        'thread_id': threadId,
        'user_id': user.id,
        'last_read_at': DateTime.now().toIso8601String(),
      },
      {'thread_id': threadId, 'user_id': member.id},
    ]);
    return threadId;
  }

  static Future<List<ChatMember>> threadParticipants(String threadId) async {
    final rows = await _supabase
        .from('chat_participants')
        .select('user_id')
        .eq('thread_id', threadId)
        .filter('left_at', 'is', null);
    final ids = [
      for (final row in rows as List) (row as Map)['user_id'] as String,
    ];
    final names = await _namesForUserIds(ids);
    final avatars = await _avatarsForUserIds(ids);
    return [
      for (final id in ids)
        ChatMember(id: id, name: names[id] ?? 'Member', avatarUrl: avatars[id]),
    ];
  }

  static Future<void> addParticipants(
    String threadId,
    List<ChatMember> members,
  ) async {
    if (members.isEmpty) return;
    final existing = await threadParticipants(threadId);
    final existingIds = existing.map((member) => member.id).toSet();
    final rows = [
      for (final member in members)
        if (!existingIds.contains(member.id))
          {'thread_id': threadId, 'user_id': member.id},
    ];
    if (rows.isEmpty) return;
    await _supabase.from('chat_participants').insert(rows);
  }

  static Future<String> createGroupChat({
    required String title,
    required List<ChatMember> members,
  }) async {
    final user = _supabase.auth.currentUser;
    final club = await _currentClubKey();
    if (user == null || club == null || club.isEmpty) {
      throw StateError('You must be signed in to create a group.');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw StateError('Add a group title.');
    }

    final thread = await _supabase
        .from('chat_threads')
        .insert({
          'club': club,
          'title': cleanTitle,
          'is_group': true,
          'created_by': user.id,
        })
        .select('id')
        .single();
    final threadId = thread['id'] as String;
    final participantIds = {user.id, ...members.map((m) => m.id)};
    await _supabase.from('chat_participants').insert([
      for (final id in participantIds)
        {
          'thread_id': threadId,
          'user_id': id,
          if (id == user.id) 'last_read_at': DateTime.now().toIso8601String(),
        },
    ]);
    return threadId;
  }

  static Future<List<ChatMessage>> listMessages(String threadId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    final rows = await _supabase
        .from('chat_messages')
        .select('id, thread_id, sender_id, body, created_at')
        .eq('thread_id', threadId)
        .filter('deleted_at', 'is', null)
        .order('created_at');

    final senderIds = {
      for (final row in rows as List)
        if ((row as Map)['sender_id'] != null) row['sender_id'] as String,
    };
    final names = await _namesForUserIds(senderIds);
    final avatars = await _avatarsForUserIds(senderIds);
    return [
      for (final row in rows)
        ChatMessage(
          id: (row as Map)['id'] as String,
          threadId: row['thread_id'] as String,
          senderId: row['sender_id'] as String?,
          senderName: names[row['sender_id']] ?? 'Member',
          senderAvatarUrl: avatars[row['sender_id']],
          body: row['body'] as String,
          createdAt: _date(row['created_at']) ?? DateTime.now(),
          isMine: row['sender_id'] == user.id,
        ),
    ];
  }

  static Future<void> sendMessage(String threadId, String body) async {
    final user = _supabase.auth.currentUser;
    final text = body.trim();
    if (user == null || text.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _supabase.from('chat_messages').insert({
      'thread_id': threadId,
      'sender_id': user.id,
      'body': text,
      'created_at': now,
    });
    await _supabase
        .from('chat_threads')
        .update({'updated_at': now})
        .eq('id', threadId);
    await _supabase
        .from('chat_participants')
        .update({'archived_at': null})
        .eq('thread_id', threadId)
        .filter('left_at', 'is', null);
    await markRead(threadId);
  }

  static Future<void> markRead(String threadId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('thread_id', threadId)
        .eq('user_id', user.id);
  }

  static Future<int> unreadCount() async {
    try {
      final threads = await listThreads();
      return threads.fold<int>(0, (sum, thread) => sum + thread.unreadCount);
    } catch (e) {
      debugPrint('ChatService.unreadCount error: $e');
      return 0;
    }
  }

  static Future<void> cleanupOldChats() async {
    if (_cleanupAttempted) return;
    _cleanupAttempted = true;
    try {
      await _supabase.rpc('cleanup_old_chat_threads');
    } catch (e) {
      debugPrint('ChatService.cleanupOldChats error: $e');
    }
  }

  static Future<void> archiveThread(String threadId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('chat_participants')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('thread_id', threadId)
        .eq('user_id', user.id);
  }

  static Future<void> unarchiveThread(String threadId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('chat_participants')
        .update({'archived_at': null})
        .eq('thread_id', threadId)
        .eq('user_id', user.id);
  }

  static Future<void> leaveThread(String threadId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now().toIso8601String();
    await _supabase
        .from('chat_participants')
        .update({'left_at': now, 'archived_at': now})
        .eq('thread_id', threadId)
        .eq('user_id', user.id);
  }

  static Future<void> deleteOwnThread(String threadId) async {
    await _supabase.rpc(
      'delete_chat_thread',
      params: {'target_thread_id': threadId},
    );
  }
}
