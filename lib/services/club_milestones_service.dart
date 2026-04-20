import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:runrank/services/notification_service.dart';

class ClubMilestone {
  final String id;
  final String milestoneDate;
  final String title;
  final String description;
  final String icon;
  final int displayOrder;

  ClubMilestone({
    required this.id,
    required this.milestoneDate,
    required this.title,
    required this.description,
    required this.icon,
    required this.displayOrder,
  });

  factory ClubMilestone.fromJson(Map<String, dynamic> json) {
    return ClubMilestone(
      id: json['id'] as String,
      milestoneDate: json['milestone_date'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String? ?? 'emoji_events',
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'milestone_date': milestoneDate,
      'title': title,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
    };
  }
}

class ClubMilestonesService {
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

  Future<List<ClubMilestone>> getAllMilestones({
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return [];
    try {
      final response = await _supabase
          .from('club_milestones')
          .select()
          .eq('club_name', canonicalClub)
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => ClubMilestone.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching milestones: $e');
      return [];
    }
  }

  Future<bool> addMilestone(
    ClubMilestone milestone, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      print('Attempting to add milestone: ${milestone.toJson()}');
      final response = await _supabase.from('club_milestones').insert({
        ...milestone.toJson(),
        'club_name': canonicalClub,
      });
      print('Milestone added successfully: $response');

      // Notify all users about the new milestone so it appears in Alerts
      // and can deep-link back to the Club Milestones page.
      try {
        await NotificationService.notifyUsersInClub(
          clubName: canonicalClub,
          title: 'New club milestone added',
          body: '${milestone.milestoneDate}: ${milestone.title}',
          route: 'club_milestones',
        );
      } catch (e) {
        print('Error sending club milestone notification: $e');
      }
      return true;
    } catch (e) {
      print('Error adding milestone: $e');
      print('Error type: ${e.runtimeType}');
      return false;
    }
  }

  Future<bool> updateMilestone(
    String id,
    ClubMilestone milestone, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      await _supabase
          .from('club_milestones')
          .update(milestone.toJson())
          .eq('id', id)
          .eq('club_name', canonicalClub);
      return true;
    } catch (e) {
      print('Error updating milestone: $e');
      return false;
    }
  }

  Future<bool> deleteMilestone(String id, {required String clubName}) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      await _supabase
          .from('club_milestones')
          .delete()
          .eq('id', id)
          .eq('club_name', canonicalClub);
      return true;
    } catch (e) {
      print('Error deleting milestone: $e');
      return false;
    }
  }

  Future<bool> reorderMilestones(
    List<ClubMilestone> milestones, {
    required String clubName,
  }) async {
    final canonicalClub = canonicalClubName(clubName);
    if (canonicalClub.isEmpty) return false;
    try {
      for (int i = 0; i < milestones.length; i++) {
        await _supabase
            .from('club_milestones')
            .update({'display_order': i + 1})
            .eq('id', milestones[i].id)
            .eq('club_name', canonicalClub);
      }
      return true;
    } catch (e) {
      print('Error reordering milestones: $e');
      return false;
    }
  }
}
