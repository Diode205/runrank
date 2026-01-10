import 'package:supabase_flutter/supabase_flutter.dart';

class AwardNominee {
  final String id;
  final String name;
  final int votes;

  AwardNominee({required this.id, required this.name, required this.votes});
}

class AwardCommentItem {
  final String id;
  final String nomineeId;
  final String nomineeName;
  final String userId;
  final String content;
  final DateTime createdAt;

  AwardCommentItem({
    required this.id,
    required this.nomineeId,
    required this.nomineeName,
    required this.userId,
    required this.content,
    required this.createdAt,
  });
}

class AwardWinnerItem {
  final String id;
  final int year;
  final String name;
  final String? nomineeId;
  AwardWinnerItem({
    required this.id,
    required this.year,
    required this.name,
    this.nomineeId,
  });
}

class AwardChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String? membershipType;
  final String content;
  final DateTime createdAt;

  AwardChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.membershipType,
    required this.content,
    required this.createdAt,
  });
}

class MalcolmBallAwardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<List<AwardNominee>> fetchNominees() async {
    final rows = await _supabase
        .from('award_nominees')
        .select('id,name,created_at')
        .order('created_at', ascending: false);

    final List<AwardNominee> list = [];
    for (final row in rows as List) {
      final id = row['id'] as String;
      final name = row['name'] as String;
      final votesRows = await _supabase
          .from('award_votes')
          .select('id')
          .eq('nominee_id', id);
      list.add(
        AwardNominee(id: id, name: name, votes: (votesRows as List).length),
      );
    }
    return list;
  }

  Future<String> _ensureNominee(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to nominate');
    }
    final nameLc = name.trim().toLowerCase();
    final existing = await _supabase
        .from('award_nominees')
        .select('id')
        .eq('name_lc', nameLc)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final inserted = await _supabase
        .from('award_nominees')
        .insert({'name': name.trim(), 'created_by': user.id})
        .select()
        .single();
    return inserted['id'] as String;
  }

  Future<void> submitNomination({
    required String name,
    required String reason,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to nominate');
    }
    final nomineeId = await _ensureNominee(name);
    await _supabase.from('award_nominations').insert({
      'nominee_id': nomineeId,
      'user_id': user.id,
      'reason': reason.trim(),
    });
  }

  Future<void> voteNominee(String nomineeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to vote');
    }
    try {
      await _supabase.from('award_votes').insert({
        'nominee_id': nomineeId,
        'user_id': user.id,
      });
    } on PostgrestException catch (e) {
      // Unique violation means the user already voted
      if (e.code == '23505') {
        throw Exception('You have already voted for this nominee');
      }
      rethrow;
    }
  }

  Future<void> addEmoji(String nomineeId, String emoji) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to react');
    }
    await _supabase.from('award_emojis').insert({
      'nominee_id': nomineeId,
      'user_id': user.id,
      'emoji': emoji,
    });
  }

  Future<void> addComment({
    required String nomineeId,
    required String content,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to comment');
    }
    await _supabase.from('award_comments').insert({
      'nominee_id': nomineeId,
      'user_id': user.id,
      'content': content.trim(),
    });
  }

  Future<List<AwardCommentItem>> fetchRecentComments({int limit = 20}) async {
    final rows = await _supabase
        .from('award_comments')
        .select('id, nominee_id, user_id, content, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    // Map nominee ids to names
    final nominees = await _supabase.from('award_nominees').select('id,name');
    final Map<String, String> nameById = {
      for (final r in nominees as List) r['id'] as String: r['name'] as String,
    };

    return (rows as List)
        .map(
          (r) => AwardCommentItem(
            id: r['id'] as String,
            nomineeId: r['nominee_id'] as String,
            nomineeName: nameById[r['nominee_id'] as String] ?? 'Unknown',
            userId: r['user_id'] as String,
            content: r['content'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<AwardWinnerItem>> fetchWinners() async {
    try {
      final rows = await _supabase
          .from('award_winners')
          .select('id, year, name, nominee_id')
          .order('year', ascending: false);
      return (rows as List)
          .map(
            (r) => AwardWinnerItem(
              id: r['id'] as String,
              year: r['year'] as int,
              name: r['name'] as String,
              nomineeId: r['nominee_id'] as String?,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        // Table not found in API schema yet; return empty list gracefully
        return [];
      }
      rethrow;
    }
  }

  Future<void> addWinner({
    required int year,
    required String name,
    String? nomineeId,
  }) async {
    await _supabase.from('award_winners').insert({
      'year': year,
      'name': name.trim(),
      if (nomineeId != null) 'nominee_id': nomineeId,
    });
  }

  RealtimeChannel subscribeToChanges({required void Function() onAnyChange}) {
    // Unsubscribe any previous channel first
    _channel?.unsubscribe();
    final ch = _supabase.channel('malcolm-ball-award');
    for (final table in [
      'award_nominees',
      'award_votes',
      'award_emojis',
      'award_comments',
      'award_nominations',
      'award_winners',
      'award_chat_messages',
      'award_message_emojis',
      'award_settings',
    ]) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) {
          onAnyChange();
        },
      );
    }
    ch.subscribe();
    _channel = ch;
    return ch;
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<Map<String, Map<String, int>>> fetchEmojiCounts(
    Set<String> nomineeIds,
  ) async {
    if (nomineeIds.isEmpty) return {};
    final rows = await _supabase
        .from('award_emojis')
        .select('nominee_id, emoji');
    final Map<String, Map<String, int>> counts = {};
    for (final r in rows as List) {
      final nId = r['nominee_id'] as String;
      if (!nomineeIds.contains(nId)) continue;
      final emoji = r['emoji'] as String;
      counts.putIfAbsent(nId, () => {});
      counts[nId]![emoji] = (counts[nId]![emoji] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------- General chat (comments) ----------------
  Future<List<AwardChatMessage>> fetchChatMessages({int limit = 50}) async {
    final rows = await _supabase
        .from('award_chat_messages')
        .select('id, user_id, content, created_at')
        .order('created_at', ascending: false)
        .limit(limit);

    // Get user profiles for avatars/names
    final userIds = {
      for (final r in rows as List) r['user_id'] as String,
    }.toList();
    Map<String, Map<String, dynamic>> profileById = {};
    if (userIds.isNotEmpty) {
      final profiles = await _supabase
          .from('user_profiles')
          .select('id, full_name, avatar_url, membership_type');
      for (final p in profiles as List) {
        if (!userIds.contains(p['id'])) continue;
        profileById[p['id'] as String] = p as Map<String, dynamic>;
      }
    }

    return (rows as List).map((r) {
      final uid = r['user_id'] as String;
      final prof = profileById[uid] ?? {};
      return AwardChatMessage(
        id: r['id'] as String,
        userId: uid,
        userName: (prof['full_name'] as String?) ?? 'Unknown',
        avatarUrl: prof['avatar_url'] as String?,
        membershipType: prof['membership_type'] as String?,
        content: r['content'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  Future<void> addChatMessage({required String content}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to comment');
    }
    await _supabase.from('award_chat_messages').insert({
      'user_id': user.id,
      'content': content.trim(),
    });
  }

  Future<void> addMessageEmoji({
    required String messageId,
    required String emoji,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to react');
    }
    await _supabase.from('award_message_emojis').insert({
      'message_id': messageId,
      'user_id': user.id,
      'emoji': emoji,
    });
  }

  Future<Map<String, Map<String, int>>> fetchMessageEmojiCounts(
    Set<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    final rows = await _supabase
        .from('award_message_emojis')
        .select('message_id, emoji');
    final Map<String, Map<String, int>> counts = {};
    for (final r in rows as List) {
      final mId = r['message_id'] as String;
      if (!messageIds.contains(mId)) continue;
      final emoji = r['emoji'] as String;
      counts.putIfAbsent(mId, () => {});
      counts[mId]![emoji] = (counts[mId]![emoji] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------- Admin vote tally ----------------
  Future<List<Map<String, dynamic>>> fetchVotesTallyDetailed() async {
    // returns list of {nominee_id, nominee_name, count, voters: [full_name,...]}
    final nominees = await _supabase.from('award_nominees').select('id,name');
    final List<Map<String, dynamic>> results = [];
    for (final n in nominees as List) {
      final id = n['id'] as String;
      final name = n['name'] as String;
      final votes = await _supabase
          .from('award_votes')
          .select('user_id')
          .eq('nominee_id', id);
      final userIds = (votes as List)
          .map((v) => v['user_id'] as String)
          .toList();
      List<String> voterNames = [];
      if (userIds.isNotEmpty) {
        final profs = await _supabase
            .from('user_profiles')
            .select('id, full_name');
        voterNames = (profs as List)
            .where((p) => userIds.contains(p['id']))
            .map((p) => (p['full_name'] as String?) ?? 'Unknown')
            .toList();
      }
      results.add({
        'nominee_id': id,
        'nominee_name': name,
        'count': userIds.length,
        'voters': voterNames,
      });
    }
    // Sort by count desc
    results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return results;
  }

  // ---------------- Voting end date (settings) ----------------
  Future<DateTime?> fetchVotingEndsAt() async {
    try {
      final row = await _supabase
          .from('award_settings')
          .select('voting_ends_at')
          .maybeSingle();
      if (row == null) return null;
      final val = row['voting_ends_at'] as String?;
      return val != null ? DateTime.parse(val) : null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') return null;
      rethrow;
    }
  }

  Future<void> setVotingEndsAt(DateTime? dt) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in');
    }
    await _supabase.from('award_settings').upsert({
      'singleton': true,
      'voting_ends_at': dt?.toIso8601String(),
      'updated_by': user.id,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------- Voting end date (settings) ----------------
  Future<DateTime?> fetchVotingEndDate() async {
    try {
      final row = await _supabase
          .from('award_settings')
          .select('value')
          .eq('key', 'voting_end_date')
          .maybeSingle();
      if (row == null) return null;
      final val = row['value'] as String?;
      if (val == null || val.trim().isEmpty) return null;
      // Expecting ISO date (YYYY-MM-DD)
      return DateTime.tryParse(val);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') return null; // table not in schema yet
      rethrow;
    }
  }

  Future<void> setVotingEndDate(DateTime date) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in as admin');
    }
    final iso = date.toIso8601String().split('T').first; // YYYY-MM-DD
    await _supabase.from('award_settings').upsert({
      'key': 'voting_end_date',
      'value': iso,
      'updated_by': user.id,
    });
  }
}
