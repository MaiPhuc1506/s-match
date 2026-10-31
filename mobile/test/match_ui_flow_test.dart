import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/match/models/match_model.dart';
import 'package:mobile/features/match/state/match_ui_store.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/match/screens/create_match_screen.dart';
import 'package:mobile/features/match/screens/match_detail_open_screen.dart';
import 'package:mobile/features/match/screens/match_invitations_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Bundled Jakarta fonts must settle before intrinsic text layout assertions.
    for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });
  Future<void> start(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  test('filters use dates and levels; join is pending, full/private/host cannot join', () {
    final now = DateTime(2026, 10, 12);
    final store = MatchUiStore(now: now);
    expect(store.visible(mine: false, todayOnly: true, now: now).length, 3);
    expect(store.visible(mine: false, todayOnly: false, now: now).length, 4);
    expect(
      store
          .visible(mine: false, todayOnly: true, level: 'Advanced', now: now)
          .single
          .title,
      'Men’s Doubles',
    );
    expect(store.requestJoin(store.find('match_1')!), isTrue);
    expect(store.requestJoin(store.find('match_1')!), isFalse);
    expect(store.participantsFor(store.find('match_1')!).length, 3);
    expect(store.requestJoin(store.find('match_3')!), isFalse);
    expect(store.requestJoin(store.find('request_demo')!), isFalse);
    final private = store.create(
      const MatchDraft(
        title: 'Private',
        description: '',
        isPrivate: true,
        gameType: 'Doubles',
        requiredPlayers: 4,
        skillLevel: 'Intermediate',
      ),
    );
    expect(store.requestJoin(private), isFalse);
  });

  testWidgets('Join from real list returns to list and retains pending state', (
    tester,
  ) async {
    await start(tester, const MatchListScreen());
    await tester.tap(find.text('Friendly Doubles'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Join Match'));
    await tester.tap(find.text('Join Match'));
    await tester.pumpAndSettle();
    expect(find.byType(MatchDetailOpenScreen), findsNothing);
    expect(find.text('Request pending'), findsOneWidget);
    await tester.tap(find.text('My Matches'));
    await tester.pumpAndSettle();
    expect(find.text('Friendly Doubles'), findsOneWidget);
    await tester.tap(find.text('Friendly Doubles'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Create replaces form; Back reaches list and My Matches contains draft',
    (tester) async {
      await start(tester, const MatchListScreen());
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'UI flow practice');
      final submit = find.widgetWithText(ElevatedButton, 'Create Match');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Manage Participants'), findsOneWidget);
      expect(find.text('Join Match'), findsNothing);
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchListScreen), findsOneWidget);
      await tester.tap(find.text('My Matches'));
      await tester.pumpAndSettle();
      expect(find.text('UI flow practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Inbox has default Accept/Decline and request tabs without injected callbacks',
    (tester) async {
      await start(tester, const MatchListScreen());
      await tester.tap(find.byTooltip('Match Requests'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchInvitationsScreen), findsOneWidget);
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(find.text('Invitations (1)'), findsOneWidget);
      expect(find.text('Team Practice'), findsNothing);
      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();
      expect(find.text('Invitations (0)'), findsOneWidget);
      await tester.tap(find.text('Join Requests 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();
      expect(find.text('Join Requests (1)'), findsOneWidget);
      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();
      expect(find.text('Join Requests (0)'), findsOneWidget);
      final store = MatchUiStore.instance;
      expect(
        store.participantsFor(store.find('request_demo')!).map((p) => p.name),
        contains('Trần Minh'),
      );
      expect(
        store.participantsFor(store.find('request_demo')!).map((p) => p.name),
        isNot(contains('Nguyễn Thảo')),
      );
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Matches'));
      await tester.pumpAndSettle();
      expect(find.text('Team Practice'), findsOneWidget);
      expect(find.text('Evening Doubles'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Private host can invite once and participant back works', (
    tester,
  ) async {
    final store = MatchUiStore.instance;
    final item = store.create(
      const MatchDraft(
        title: 'Private test',
        description: '',
        isPrivate: true,
        gameType: 'Doubles',
        requiredPlayers: 4,
        skillLevel: 'Intermediate',
      ),
    );
    await start(tester, MatchDetailOpenScreen(match: item, draft: item.draft));
    await tester.ensureVisible(find.text('Invite Players'));
    await tester.tap(find.text('Invite Players'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mời ngay').first);
    await tester.pumpAndSettle();
    expect(find.text('Đã mời'), findsOneWidget);
    expect(
      store.sentInvitations.where((key) => key.startsWith(item.id)).length,
      1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Vietnamese composing input survives editing and match creation',
    (tester) async {
      await start(tester, const CreateMatchScreen());
      final fields = find.byType(TextField);
      const title = 'Giao lưu cầu lông Đà Nẵng';
      const description = 'Đánh đôi buổi tối, chào đón mọi người!';
      await tester.showKeyboard(fields.first);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: title,
          selection: TextSelection.collapsed(offset: title.length),
          composing: TextRange(start: 0, end: title.length),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(fields.first).controller!.value.composing,
        const TextRange(start: 0, end: title.length),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: title,
          selection: TextSelection.collapsed(offset: title.length),
        ),
      );
      await tester.enterText(fields.last, description);
      final submit = find.widgetWithText(ElevatedButton, 'Create Match');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(description), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
