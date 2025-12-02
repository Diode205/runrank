// calculator_logic.dart
import 'dart:math';
import 'standards_data.dart';
import 'age_grade_lookup.dart';

class RunCalculator {
  // Convert HH:MM:SS or MM:SS or decimal minutes string to total seconds.
  // Accepts: "1:12:45", "45:20", "22.5" (decimal minutes)
  static int? parseTimeToSeconds(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    try {
      if (s.contains(':')) {
        final parts = s
            .split(':')
            .map((p) => int.tryParse(p.trim()) ?? 0)
            .toList();
        if (parts.length == 3) {
          // hh:mm:ss
          return parts[0] * 3600 + parts[1] * 60 + parts[2];
        } else if (parts.length == 2) {
          // mm:ss
          return parts[0] * 60 + parts[1];
        } else {
          return null;
        }
      } else {
        // treat as decimal minutes (e.g. "22.5" => 22.5 minutes => seconds)
        final minutes = double.tryParse(s);
        if (minutes == null) return null;
        return (minutes * 60).round();
      }
    } catch (e) {
      return null;
    }
  }

  // Determine age-group string key for clubStandardsSeconds map
  static String getAgeGroup(String gender, int age) {
    final g = gender.toUpperCase() == 'F' ? 'F' : 'M';
    if (age >= 18 && age <= 29) return '${g}18-29';
    if (age >= 30 && age <= 34) return '${g}30-34';
    if (age >= 35 && age <= 39) return '${g}35-39';
    if (age >= 40 && age <= 44) return '${g}40-44';
    if (age >= 45 && age <= 49) return '${g}45-49';
    if (age >= 50 && age <= 54) return '${g}50-54';
    if (age >= 55 && age <= 59) return '${g}55-59';
    if (age >= 60 && age <= 64) return '${g}60-64';
    if (age >= 65 && age <= 69) return '${g}65-69';
    if (age >= 70 && age <= 74) return '${g}70-74';
    if (age >= 75 && age <= 79) return '${g}75-79';
    if (age >= 80 && age <= 84) return '${g}80-84';
    return '${g}18-29'; // fallback
  }

  // Returns Map with keys: 'level', 'diffToNext', 'nextLevel', 'achievedThreshold', 'ageGrade', 'ageGradeMessage', 'finishSeconds'
  static Map<String, dynamic> evaluate({
    required String gender,
    required int age,
    required String distance, // '5K', '10K', 'Half M' etc
    required int finishSeconds,
  }) {
    final ageGroup = getAgeGroup(gender, age);
    final group = clubStandardsSeconds[ageGroup];
    final result = <String, dynamic>{'level': 'Unknown', 'ageGroup': ageGroup};

    if (group == null || !group.containsKey(distance)) {
      result['level'] = 'Unknown';
      result['ageGrade'] = 0.0;
      result['ageGradeMessage'] = 'No standard data for $distance / $ageGroup';
      return result;
    }

    final standardsForDistance =
        group[distance]!; // Map<String,int> level->seconds

    // Ordered levels
    final order = ['Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze', 'Copper'];
    String achieved = 'Unranked';
    String? nextLevel;
    int? nextThreshold;
    int? achievedThreshold;

    for (final level in order) {
      if (standardsForDistance.containsKey(level)) {
        final threshold = standardsForDistance[level]!;
        if (finishSeconds <= threshold) {
          achieved = level;
          achievedThreshold = threshold;
          break;
        }
      }
    }

    if (achieved == 'Unranked') {
      final sortedLevels = standardsForDistance.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      nextLevel = sortedLevels.isNotEmpty ? sortedLevels.last.key : null;
      nextThreshold = sortedLevels.isNotEmpty ? sortedLevels.last.value : null;
    } else {
      final keys = order
          .where((l) => standardsForDistance.containsKey(l))
          .toList();
      final idx = keys.indexOf(achieved);
      if (idx > 0) {
        nextLevel = keys[idx - 1];
        nextThreshold = standardsForDistance[nextLevel];
      }
    }

    int diffToNext = 0;
    if (nextThreshold != null) {
      diffToNext = finishSeconds - nextThreshold;
    }

    // Age grade using the new age-grade lookup
    double ageGrade = 0.0;
    String ageGradeMessage = '';
    final worldBest = AgeGradeLookup.getWorldBestSeconds(
      gender: gender,
      age: age,
      distance: distance,
    );

    if (worldBest <= 0.0) {
      ageGrade = 0.0;
      ageGradeMessage = 'No world record yet to establish as of this time';
    } else {
      ageGrade = (worldBest / finishSeconds) * 100.0;
      // optional small age factor to mildly adjust (kept similar to previous approach)
      final ageFactor = pow((age / 30).clamp(0.7, 1.5), 0.07);
      ageGrade = (ageGrade * ageFactor).clamp(0.0, 150.0);
      ageGradeMessage = 'Age-grade calculated vs world-best for age $age';
    }

    result['level'] = achieved;
    result['achievedThreshold'] = achievedThreshold;
    result['nextLevel'] = nextLevel;
    result['nextThreshold'] = nextThreshold;
    result['diffToNext'] = diffToNext;
    result['ageGrade'] = ageGrade;
    result['ageGradeMessage'] = ageGradeMessage;
    result['finishSeconds'] = finishSeconds;
    return result;
  }
}
