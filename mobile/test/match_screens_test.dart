import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/match/screens/create_match_screen.dart';
import 'package:mobile/features/match/screens/match_detail_open_screen.dart';
import 'package:mobile/features/match/screens/match_invitations_screen.dart';
import 'package:mobile/features/match/screens/match_join_requests_screen.dart';

void main() {
  Future<void> usePhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  for (final isPrivate in [false, true]) {
    testWidgets('create match previews entered values (private: $isPrivate)', (
      tester,
    ) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(home: CreateMatchScreen(initiallyPrivate: isPrivate)),
      );
      await tester.enterText(find.byType(TextField).first, 'Friday Practice');
      await tester.enterText(find.byType(TextField).last, 'Practice net play');
      await tester.ensureVisible(find.text('Singles'));
      await tester.tap(find.text('Singles'));
      await tester.ensureVisible(find.text('Advanced'));
      await tester.tap(find.text('Advanced'));
      final submit = find.widgetWithText(ElevatedButton, 'Create Match');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(MatchDetailOpenScreen), findsOneWidget);
      expect(find.text('Friday Practice'), findsOneWidget);
      expect(find.text('Practice net play'), findsOneWidget);
      expect(find.text('Singles (4 players)'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(
        find.text(isPrivate ? 'Private Match' : 'Open Match'),
        findsOneWidget,
      );
      if (isPrivate) expect(find.text('Join Match'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'MatchListScreen renders verified cards and can navigate to CreateMatchScreen',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(const MaterialApp(home: MatchListScreen()));

      // Verify Title & Header
      expect(find.text('Matches'), findsAtLeastNWidgets(1));
      expect(find.text('+'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Open Matches'), findsOneWidget);
      expect(find.text('My Matches'), findsOneWidget);

      // Verify Verified Match Cards from Figma
      expect(find.text('Friendly Doubles'), findsOneWidget);
      expect(find.text('Men’s Doubles'), findsOneWidget);
      expect(find.text('Casual Singles'), findsOneWidget);
      expect(find.text('Weekend Fun Match'), findsNothing);
      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();
      expect(find.text('Weekend Fun Match'), findsOneWidget);

      // Tap "+" to navigate to CreateMatchScreen
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      // Verify CreateMatchScreen rendered
      expect(find.text('Create Match'), findsAtLeastNWidgets(1));
      expect(find.text('Weekend Doubles Fun'), findsOneWidget);
      expect(find.text('Sunrise Badminton Club'), findsOneWidget);
    },
  );

  testWidgets('MatchListScreen card tap navigates to MatchDetailOpenScreen', (
    tester,
  ) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: MatchListScreen()));

    // Tap first match card
    await tester.tap(find.text('Friendly Doubles'));
    await tester.pumpAndSettle();

    // Verify MatchDetailOpenScreen rendered
    expect(find.text('Open Match'), findsOneWidget);
    expect(find.text('Host'), findsAtLeastNWidgets(1));
    expect(find.text('Join Match'), findsOneWidget);
  });

  testWidgets('CreateMatchScreen renders all input sections correctly', (
    tester,
  ) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: CreateMatchScreen()));

    expect(find.text('Create Match'), findsAtLeastNWidgets(1));
    expect(find.text('Open Match'), findsOneWidget);
    expect(find.text('Private Match'), findsOneWidget);
    expect(find.text('Singles'), findsOneWidget);
    expect(find.text('Doubles'), findsOneWidget);
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
  });

  testWidgets(
    'MatchDetailOpenScreen renders verified details and participant section',
    (tester) async {
      await usePhoneViewport(tester);
      bool joined = false;
      bool seeAllTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MatchDetailOpenScreen(
            onJoinMatch: () => joined = true,
            onSeeAllParticipants: () => seeAllTapped = true,
          ),
        ),
      );

      // Title & Badge & Description
      expect(find.text('Weekend Doubles Fun'), findsOneWidget);
      expect(find.text('Open Match'), findsOneWidget);
      expect(find.text('Casual match, all are welcome! 🏸'), findsOneWidget);

      // Info rows
      expect(find.text('Sun, 20 Sep 2026 · 19:00 – 21:00'), findsOneWidget);
      expect(find.text('Sunrise Badminton Club · Da Nang'), findsOneWidget);
      expect(find.text('Doubles (4 players)'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);

      // Host & Participants
      expect(find.text('Host'), findsAtLeastNWidgets(1));
      expect(find.text('Nguyễn Văn A'), findsAtLeastNWidgets(1));
      expect(find.text('Participants (3/4)'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      // Tap "See all"
      await tester.tap(find.text('See all'));
      expect(seeAllTapped, isTrue);

      // Tap "Join Match"
      await tester.tap(find.text('Join Match'));
      expect(joined, isTrue);
    },
  );

  testWidgets(
    'private create state preserves entered title when switching tabs',
    (tester) async {
      await usePhoneViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(home: CreateMatchScreen(initiallyPrivate: true)),
      );

      expect(find.text('Private Match'), findsOneWidget);
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Friday Practice');
      await tester.tap(find.text('Open Match'));
      await tester.pump();
      await tester.tap(find.text('Private Match'));
      await tester.pump();

      expect(
        tester.widget<TextField>(titleField).controller!.text,
        'Friday Practice',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('match detail opens participant list from See all', (
    tester,
  ) async {
    await usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: MatchDetailOpenScreen()));

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('Participants (4/4)'), findsOneWidget);
    expect(find.text('Phạm Hoàng'), findsOneWidget);
    expect(find.text('3.9'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final backButton = find.byTooltip('Back');
    expect(
      tester.getRect(backButton).right,
      lessThan(tester.getRect(find.text('Participants (4/4)')).left),
    );
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.text('Participants (4/4)'), findsNothing);
    expect(find.text('See all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('request tabs and card actions use their configured callbacks', (
    tester,
  ) async {
    await usePhoneViewport(tester);
    int? accepted;
    int? declined;
    bool joinRequestsTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MatchInvitationsScreen(
          onJoinRequests: () => joinRequestsTapped = true,
          onAccept: (index) => accepted = index,
          onDecline: (index) => declined = index,
        ),
      ),
    );

    expect(find.text('Team Practice'), findsOneWidget);
    expect(find.text('Evening Doubles'), findsOneWidget);
    await tester.tap(find.text('Join Requests 2'));
    await tester.tap(find.text('Accept').first);
    await tester.tap(find.text('Decline').last);
    expect(joinRequestsTapped, isTrue);
    expect(accepted, 0);
    expect(declined, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: MatchJoinRequestsScreen()));
    expect(find.text('Trần Minh · requested to join'), findsOneWidget);
    await tester.tap(find.text('Invitations'));
    await tester.pumpAndSettle();
    expect(find.text('Invitations (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
