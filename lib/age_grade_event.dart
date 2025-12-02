// age_grade_event.dart
// Small helper type used by calculator if you want a typed return for age-grade calls.

class AgeGradeEvent {
  final double worldBestSeconds;
  final bool exists;
  AgeGradeEvent(this.worldBestSeconds) : exists = worldBestSeconds > 0.0;
}
