import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class TeamAchievement {
  final String id;
  final DateTime achievementDate;
  final String eventName;
  final String award; // Gold, Silver, Bronze, Champion
  final String teams;

  TeamAchievement({
    required this.id,
    required this.achievementDate,
    required this.eventName,
    required this.award,
    required this.teams,
  });

  factory TeamAchievement.fromJson(Map<String, dynamic> json) {
    return TeamAchievement(
      id: json['id'] as String,
      achievementDate: DateTime.parse(json['achievement_date'] as String),
      eventName: json['event_name'] as String,
      award: json['award'] as String,
      teams: json['teams'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_date': achievementDate.toIso8601String().split('T')[0],
      'event_name': eventName,
      'award': award,
      'teams': teams,
    };
  }
}

class TeamAchievementsService {
  final _supabase = Supabase.instance.client;

  static String canonicalClubName(String? clubName) {
    final normalized = (clubName ?? '').trim();
    final lower = normalized.toLowerCase();
    if (lower == 'nrr' ||
        lower == 'norwich-road-runners' ||
        lower.contains('norwich road runners')) {
      return 'Norwich Road Runners';
    }
    if (lower == 'nnbr' ||
        lower == 'north-norfolk-beach-runners' ||
        lower.contains('north norfolk beach runners')) {
      return 'NNBR (North Norfolk Beach Runners)';
    }
    return normalized;
  }

  /// Fetch all team achievements ordered by date (newest first)
  Future<List<TeamAchievement>> getAllAchievements({
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return [];
    try {
      final response = await _supabase
          .from('team_achievements')
          .select()
          .eq('club_name', canonicalClub)
          .order('achievement_date', ascending: false);

      return (response as List)
          .map((json) => TeamAchievement.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching team achievements: $e');
      return [];
    }
  }

  /// Add a new team achievement (admin only)
  Future<bool> addAchievement(
    TeamAchievement achievement, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      await _supabase.from('team_achievements').insert({
        ...achievement.toJson(),
        'club_name': canonicalClub,
      });

      // Notify all users about the new team achievement so it appears
      // in the Alerts bar and can deep-link back to this page.
      try {
        final dateLabel = achievement.achievementDate.toIso8601String().split(
          'T',
        )[0];
        await NotificationService.notifyUsersInClub(
          clubName: canonicalClub,
          title: 'New team achievement added',
          body:
              '${achievement.teams} achieved ${achievement.award} at ${achievement.eventName} on $dateLabel.',
          route: 'team_achievements',
        );
      } catch (e) {
        print('Error sending team achievement notification: $e');
      }
      return true;
    } catch (e) {
      print('Error adding team achievement: $e');
      return false;
    }
  }

  /// Update an existing achievement (admin only)
  Future<bool> updateAchievement(
    String id,
    TeamAchievement achievement, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      await _supabase
          .from('team_achievements')
          .update(achievement.toJson())
          .eq('id', id)
          .eq('club_name', canonicalClub);
      return true;
    } catch (e) {
      print('Error updating team achievement: $e');
      return false;
    }
  }

  /// Delete an achievement (admin only)
  Future<bool> deleteAchievement(String id, {required String clubName}) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      await _supabase
          .from('team_achievements')
          .delete()
          .eq('id', id)
          .eq('club_name', canonicalClub);
      return true;
    } catch (e) {
      print('Error deleting team achievement: $e');
      return false;
    }
  }
}
