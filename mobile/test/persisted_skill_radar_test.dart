import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/widgets/profile_skill_radar.dart';

void main() {
  const sample = {
    'smash': 4.5,
    'defense': 3.5,
    'netPlay': 4,
    'stamina': 3,
    'footwork': 3.5,
    'serve': 4,
  };

  test(
    'assessment axes follow radar order; missing and zero values stay unknown',
    () {
      expect(ProfileSkillRadar.assessedValues(sample), [
        4.5,
        3.5,
        4,
        3,
        3.5,
        4,
      ]);
      expect(ProfileSkillRadar.assessedValues(null), isNull);
      expect(ProfileSkillRadar.assessedValues({...sample, 'serve': 0}), isNull);
    },
  );

  testWidgets('live radar paints the persisted polygon with six labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSkillRadar(
            refined: true,
            values: ProfileSkillRadar.assessedValues(sample),
          ),
        ),
      ),
    );
    final radar = find.byType(ProfileSkillRadar);
    expect(
      find.descendant(of: radar, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    for (final label in [
      'Smash',
      'Defense',
      'Net Play',
      'Stamina',
      'Footwork',
      'Serve',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
