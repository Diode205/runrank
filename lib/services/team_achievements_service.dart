import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Fetch all team achievements ordered by date (newest first)
  Future<List<TeamAchievement>> getAllAchievements() async {
    try {
      final response = await _supabase
          .from('team_achievements')
          .select()
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
  Future<bool> addAchievement(TeamAchievement achievement) async {
    try {
      await _supabase.from('team_achievements').insert(achievement.toJson());
      return true;
    } catch (e) {
      print('Error adding team achievement: $e');
      return false;
    }
  }

  /// Update an existing achievement (admin only)
  Future<bool> updateAchievement(String id, TeamAchievement achievement) async {
    try {
      await _supabase
          .from('team_achievements')
          .update(achievement.toJson())
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating team achievement: $e');
      return false;
    }
  }

  /// Delete an achievement (admin only)
  Future<bool> deleteAchievement(String id) async {
    try {
      await _supabase.from('team_achievements').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting team achievement: $e');
      return false;
    }
  }
}
