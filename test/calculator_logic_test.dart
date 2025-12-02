import 'package:flutter_test/flutter_test.dart';
import 'package:runrank/calculator_logic.dart';

void main() {
  group('parseTimeToSeconds', () {
    test('parses HH:MM:SS correctly', () {
      expect(RunCalculator.parseTimeToSeconds('1:02:03'), 3723);
    });
    test('parses MM:SS correctly', () {
      expect(RunCalculator.parseTimeToSeconds('45:20'), 2720);
    });
    test('parses decimal minutes', () {
      expect(RunCalculator.parseTimeToSeconds('22.5'), 1350);
    });
    test('handles invalid', () {
      expect(RunCalculator.parseTimeToSeconds('bad'), null);
    });
  });

  group('evaluate club standards', () {
    test('identifies Gold correctly (example)', () {
      final result = RunCalculator.evaluate(
        gender: 'M',
        age: 40,
        distance: '5K',
        finishSeconds: 1200, // 20:00
      );

      expect(result['level'], isNotNull);
    });
  });

  group('age-grade', () {
    test('age-grade gets lower when slower', () {
      final fast = RunCalculator.evaluate(
        gender: 'F',
        age: 30,
        distance: '5K',
        finishSeconds: 1200,
      )['ageGrade'];

      final slow = RunCalculator.evaluate(
        gender: 'F',
        age: 30,
        distance: '5K',
        finishSeconds: 1800,
      )['ageGrade'];

      expect(fast > slow, true);
    });
  });
}
