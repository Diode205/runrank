import 'package:supabase_flutter/supabase_flutter.dart';

class AwardWinnerRow {
  final String awardKey;
  final int year;
  final String? femaleName;
  final String? maleName;
  AwardWinnerRow({
    required this.awardKey,
    required this.year,
    this.femaleName,
    this.maleName,
  });
}

class RunnersAwardsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<AwardWinnerRow>> fetchWinners(String awardKey) async {
    try {
      final rows = await _supabase
          .from('club_awards_winners')
          .select('award_key, year, female_name, male_name')
          .eq('award_key', awardKey)
          .order('year', ascending: false);
      return (rows as List)
          .map(
            (r) => AwardWinnerRow(
              awardKey: r['award_key'] as String,
              year: r['year'] as int,
              femaleName: r['female_name'] as String?,
              maleName: r['male_name'] as String?,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        // Table not in API yet; return empty
        return [];
      }
      rethrow;
    }
  }

  Future<void> addWinner({
    required String awardKey,
    required int year,
    String? femaleName,
    String? maleName,
  }) async {
    await _supabase.from('club_awards_winners').insert({
      'award_key': awardKey,
      'year': year,
      'female_name': femaleName,
      'male_name': maleName,
    });
  }
}
