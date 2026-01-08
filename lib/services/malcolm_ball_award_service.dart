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
    final rows = await _supabase
        .from('award_winners')
        .select('id, year, name, nominee_id')
        .order('year', ascending: false);
    return (rows as List)
        .map((r) => AwardWinnerItem(
              id: r['id'] as String,
              year: r['year'] as int,
              name: r['name'] as String,
              nomineeId: r['nominee_id'] as String?,
            ))
        .toList();
  }

  Future<void> addWinner({required int year, required String name, String? nomineeId}) async {
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
}
