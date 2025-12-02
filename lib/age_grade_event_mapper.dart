// age_grade_event_mapper.dart
// Tiny helper to wrap AgeGradeLookup in a more explicit interface (not strictly necessary).

import 'age_grade_lookup.dart';

class AgeGradeEventMapper {
  static double fetch({
    required String gender,
    required int age,
    required String distance,
  }) {
    return AgeGradeLookup.getWorldBestSeconds(
      gender: gender,
      age: age,
      distance: distance,
    );
  }
}
