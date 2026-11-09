import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/feedback/data/feedback_repository.dart';
import 'package:mobile/features/feedback/screens/match_completed_screen.dart';
import 'package:mobile/features/feedback/screens/feedback_form_screen.dart';
import 'package:mobile/features/feedback/screens/rating_history_screen.dart';
import 'package:mobile/features/feedback/screens/community_rating_screen.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(393, 852),
    bool reduce = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: reduce),
            child: screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('preview submission validates, prevents duplicates and retains given ratings', () async {
    final repo = FeedbackRepository(delay: Duration.zero, withSamples: false);
    final entries = feedbackTeammates
        .map(
          (p) => TeammateFeedback(player: p, stars: 4, review: 'Chơi rất vui'),
        )
        .toList();
    await repo.submit('sample', entries);
    expect(repo.given.length, 3);
    expect(repo.received, isEmpty);
    expect(() => repo.submit('sample', entries), throwsStateError);
    expect(() => repo.submit('other', [entries.first]), throwsArgumentError);
  });

  test('demo comments have distinct content, dates and a consistent rating summary', () {
    final repo = FeedbackRepository();
    expect(repo.received.length, 3);
    expect(repo.given.length, 3);
    expect(repo.received.map((e) => e.review).toSet().length, 3);
    expect(repo.given.map((e) => e.review).toSet().length, 3);
    expect(repo.received.map((e) => e.stars).toSet(), {4, 5});
    expect(
      repo.received.every(
        (e) => e.createdAt != null && e.matchTitle != null && e.tags.isNotEmpty,
      ),
      true,
    );
    expect(repo.previewAverageLabel, '4.7');
    expect(repo.previewMatchCount, 2);
    expect(FeedbackRepository(withSamples: false).given, isEmpty);
    expect(FeedbackRepository(withSamples: false).received, isEmpty);
  });

  testWidgets('Received and Given show labelled sample feedback and metadata', (
    tester,
  ) async {
    final repo = FeedbackRepository();
    await mount(tester, RatingHistoryScreen(repository: repo));
    expect(find.text('Demo feedback · Not saved to server'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.text('3 ratings · 2 matches'), findsOneWidget);
    expect(find.text(repo.received.first.review), findsOneWidget);
    expect(find.text('Saturday Rally · 31/10'), findsOneWidget);
    await tester.tap(find.text('Given'));
    await tester.pumpAndSettle();
    expect(find.text('To Minh'), findsOneWidget);
    expect(find.text(repo.given.first.review), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Live Feedback opens demo explicitly and Back preserves the empty live history',
    (tester) async {
      final live = _EmptyLiveFeedback();
      await mount(tester, RatingHistoryScreen(repository: live));
      expect(find.text('Demo feedback · Not saved to server'), findsNothing);
      expect(live.received, isEmpty);
      await tester.tap(find.text('View demo feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Demo feedback · Not saved to server'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('View demo feedback'), findsOneWidget);
      expect(find.text('Demo feedback · Not saved to server'), findsNothing);
      expect(live.received, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completed -> form, requires all ratings, sends once and shows history',
    (tester) async {
      final repo = FeedbackRepository(delay: const Duration(milliseconds: 350));
      await mount(tester, MatchCompletedScreen(repository: repo));
      await tester.tap(find.text('Rate Your Teammates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();
      expect(
        find.text('Please rate all 3 teammates before submitting.'),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        final card = find.byKey(ValueKey('feedback-card-$i'));
        await tester.scrollUntilVisible(
          card,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        final star = find.descendant(
          of: card,
          matching: find.byTooltip('4 stars'),
        );
        await tester.ensureVisible(star);
        await tester.pumpAndSettle();
        await tester.tap(star);
        await tester.pump();
      }
      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();
      expect(repo.submitting, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Feedback sent'), findsOneWidget);
      expect(repo.given.length, 3);
      expect(repo.given.every((e) => e.stars == 4), isTrue);
      await tester.tap(find.text('View Rating History'));
      await tester.pumpAndSettle();
      expect(find.text('Feedback you’ve shared'), findsOneWidget);
      expect(find.text('To Minh'), findsOneWidget);
      await tester.tap(find.text('Received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minh'));
      await tester.pumpAndSettle();
      expect(find.text('Rating breakdown'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Feedback tab navigates to history', (tester) async {
    await mount(
      tester,
      const Scaffold(
        bottomNavigationBar: PlayerBottomNavigation(
          currentTab: PlayerNavTab.map,
        ),
      ),
    );
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingHistoryScreen), findsOneWidget);
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets(
      'feedback layouts scroll without overflow at $size with Reduce Motion',
      (tester) async {
        for (final screen in <Widget>[
          MatchCompletedScreen(repository: FeedbackRepository()),
          FeedbackFormScreen(repository: FeedbackRepository()),
          RatingHistoryScreen(repository: FeedbackRepository()),
          RatingHistoryScreen(
            repository: FeedbackRepository(withSamples: false),
          ),
          const FeedbackSubmittedScreen(),
          const CommunityRatingScreen(),
        ]) {
          await mount(tester, screen, size: size, reduce: true);
          expect(tester.takeException(), isNull, reason: '$screen at $size');
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$screen after scroll',
          );
        }
      },
    );
  }
}

class _EmptyLiveFeedback extends FeedbackRepository {
  _EmptyLiveFeedback() : super(withSamples: false);
  @override
  bool get live => true;
}
