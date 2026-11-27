import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/player_experience/screens/player_home_screen.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final (title, file) in [
    ('Improve Your Smash', 'smash.mp4'),
    ('Footwork Basics', 'footwork.mp4'),
    ('Net Play Essentials', 'netplay.mp4'),
  ]) {
    testWidgets('Offline playback: $title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PlayerHomeScreen())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Tips'));
      await tester.pump(const Duration(milliseconds: 600));

      Future<void> reveal(Finder target) async {
        final list = find.byType(ListView).last;
        for (
          var i = 0;
          i < 12 && target.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(list, const Offset(0, -170));
          await tester.pump(const Duration(milliseconds: 180));
        }
        expect(target.hitTestable(), findsOneWidget);
      }

      await reveal(find.text(title));
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 600));
      await reveal(find.byTooltip('Play'));
      final player = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      expect(player.dataSource, endsWith(file));
      expect(player.value.isPlaying, isFalse);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump(const Duration(seconds: 2));
      expect(player.value.position, greaterThan(Duration.zero));
      final hideVideo = find.byTooltip('Hide video');
      await tester.ensureVisible(hideVideo);
      await tester.tap(hideVideo);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayer), findsNothing);
      expect(player.value.isPlaying, isFalse);
      final pausedAt = player.value.position;
      expect(pausedAt, greaterThan(Duration.zero));

      final firstStep = find.text('Step 1');
      await reveal(firstStep);
      await tester.tap(firstStep);
      await tester.pump(const Duration(milliseconds: 400));
      final instruction = tester
          .widget<ExpansionTile>(find.widgetWithText(ExpansionTile, 'Step 1'))
          .children.first;
      await tester.ensureVisible(find.byWidget(instruction));
      expect(find.byWidget(instruction).hitTestable(), findsOneWidget);

      final showVideo = find.byTooltip('Show video');
      await tester.ensureVisible(showVideo);
      await tester.tap(showVideo);
      await tester.pump(const Duration(milliseconds: 500));
      final reopened = tester.widget<VideoPlayer>(find.byType(VideoPlayer));
      expect(reopened.controller.value.position, pausedAt);
      expect(reopened.controller.value.isPlaying, isFalse);
      await reveal(find.byTooltip('Play'));
      await tester.tap(find.byTooltip('Play'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(player.value.isPlaying, isFalse);
      final slider = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(slider.right - 30, slider.center.dy));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        player.value.position.inSeconds,
        greaterThan(player.value.duration.inSeconds ~/ 2),
      );
      await tester.tap(find.byTooltip('Play'));
      for (var i = 0; i < 12 && !player.value.isCompleted; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(player.value.isCompleted, isTrue);
      await tester.tap(find.byTooltip('Replay'));
      await tester.pump(const Duration(seconds: 1));
      expect(player.value.isPlaying, isTrue);
      expect(player.value.position.inSeconds, lessThan(4));
      await reveal(find.text('Step 1'));
      await tester.tap(find.text('Step 1'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('Tips & Tricks'), findsOneWidget);
    });
  }
}
