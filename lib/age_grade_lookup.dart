// age_grade_lookup.dart
// Central lookup helper that exposes a single API to fetch the world-best seconds for gender+age+distance.

import 'age_grade_men.dart';
import 'age_grade_women.dart';

class AgeGradeLookup {
  /// Return the world-best seconds for the provided gender ('M' or 'F'), exact age (int)
  /// and distance label ('5K','5M','10K','10M','Half M','Marathon').
  /// If no record exists (0 or missing), returns 0.0.
  static double getWorldBestSeconds({
    required String gender,
    required int age,
    required String distance,
  }) {
    final g = gender.toUpperCase() == 'F' ? 'F' : 'M';
    final intAge = age;
    Map<int, Map<String, double>> table = (g == 'F')
        ? ageGradeWomen
        : ageGradeMen;

    // If exact age not present, clamp into available range:
    if (!table.containsKey(intAge)) {
      // try to find nearest existing age key
      if (table.isEmpty) return 0.0;
      final keys = table.keys.toList()..sort();
      // clamp to min/max
      if (intAge < keys.first) {
        return table[keys.first]?[distance] ?? 0.0;
      }
      if (intAge > keys.last) {
        return table[keys.last]?[distance] ?? 0.0;
      }
      // otherwise try to find exact or fallback
      // for safety return 0.0 if not found
      return 0.0;
    }

    final row = table[intAge];
    if (row == null) return 0.0;
    return row[distance] ?? 0.0;
  }
}
