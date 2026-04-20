import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

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

  static String canonicalClubName(String? clubName) {
    final normalized = (clubName ?? '').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'nrr' || lower.contains('norwich road runners')) {
      return 'Norwich Road Runners';
    }
    if (lower == 'nnbr' || lower.contains('north norfolk beach runners')) {
      return 'NNBR (North Norfolk Beach Runners)';
    }
    return normalized;
  }

  Future<List<AwardWinnerRow>> fetchWinners(
    String awardKey, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return [];
    try {
      final rows = await _supabase
          .from('club_awards_winners')
          .select('award_key, year, female_name, male_name')
          .eq('award_key', awardKey)
          .eq('club_name', canonicalClub)
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
    required String clubName,
    required int year,
    String? femaleName,
    String? maleName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    await _supabase.from('club_awards_winners').insert({
      'award_key': awardKey,
      'club_name': canonicalClub,
      'year': year,
      'female_name': femaleName,
      'male_name': maleName,
    });

    // Notify all users when runners-of-the-year winners are updated
    try {
      final label = _labelForAward(awardKey);
      await NotificationService.notifyUsersInClub(
        clubName: canonicalClub,
        title: 'Runners of the Year updated',
        body: '$label winners updated for $year.',
      );
    } catch (_) {}
  }

  Future<void> updateWinner({
    required String awardKey,
    required String clubName,
    required int year,
    String? femaleName,
    String? maleName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    await _supabase
        .from('club_awards_winners')
        .update({'female_name': femaleName, 'male_name': maleName})
        .eq('award_key', awardKey)
        .eq('club_name', canonicalClub)
        .eq('year', year);

    try {
      final label = _labelForAward(awardKey);
      await NotificationService.notifyUsersInClub(
        clubName: canonicalClub,
        title: 'Runners of the Year updated',
        body: '$label winners updated for $year.',
      );
    } catch (_) {}
  }

  Future<void> deleteWinner({
    required String awardKey,
    required String clubName,
    required int year,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    await _supabase
        .from('club_awards_winners')
        .delete()
        .eq('award_key', awardKey)
        .eq('club_name', canonicalClub)
        .eq('year', year);

    try {
      final label = _labelForAward(awardKey);
      await NotificationService.notifyUsersInClub(
        clubName: canonicalClub,
        title: 'Runners of the Year updated',
        body: '$label winners removed for $year.',
      );
    } catch (_) {}
  }

  String _labelForAward(String awardKey) {
    switch (awardKey) {
      case 'runner_of_the_year':
        return 'Runner of the Year';
      case 'newcomer_of_the_year':
        return 'Newcomer of the Year';
      default:
        return 'Runners of the Year';
    }
  }
}
