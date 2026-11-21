import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/player_experience/platform_view/bot_avatar_view.dart';
import 'package:mobile/features/player_experience/services/smash_scot_chat_service.dart';
import 'package:mobile/features/player_experience/widgets/smash_scot.dart';

void main() {
  testWidgets('Reduced motion chat settles and returns the demo catalogue', (
    tester,
  ) async {
    final state = ValueNotifier(BotAvatarState.defaultState);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: SmashScotChat(avatarState: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Court Information'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10 illustrative facilities'), findsOneWidget);
    expect(state.value, BotAvatarState.defaultState);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Live chat reads the facilities provider when unauthenticated', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWith(
            (ref) async => const [
              CourtLocation(
                id: 1,
                name: 'Live Da Nang Court',
                latitude: 16,
                longitude: 108,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SmashScotChat(live: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Court Information'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Live Da Nang Court'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Authenticated Player chat connects to POST /ai/chat with multi-turn context and RBAC denial for Owner revenue',
    (tester) async {
      final dio = Dio();
      final sentPayloads = <Map<String, dynamic>>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/ai/chat');
            final payload = Map<String, dynamic>.from(options.data as Map);
            sentPayloads.add(payload);

            final msg = (payload['message'] as String).toLowerCase();
            String reply;
            List<String> toolsUsed;

            if (msg.contains('revenue')) {
              reply =
                  'I could not complete that request: Access denied: Court Owner analytics and revenue data are restricted strictly to COURT_OWNER accounts.';
              toolsUsed = ['get_owner_analytics'];
            } else if (msg.contains('bookings')) {
              reply =
                  'You have 1 booking(s):\n• Booking #501 [CONFIRMED]: Hai Chau Badminton Center - Court 1 on 2026-10-05 (18:00–19:00), Total: 100000 VND';
              toolsUsed = ['get_my_bookings'];
            } else {
              reply =
                  'Found 1 matching facility(s):\n• Hai Chau Badminton Center (123 Bach Dang, Hai Chau, Da Nang): Court 1 (INDOOR): 18:00-18:30 (100000 VND/h)';
              toolsUsed = ['search_available_courts'];
            }

            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'reply': reply,
                  'toolsUsed': toolsUsed,
                  'provider': 'local-tool-planner',
                },
              ),
            );
          },
        ),
      );

      final service = SmashScotChatService(
        dio: dio,
        tokenProvider: () => 'verified-player-jwt',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smashScotChatServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const Scaffold(body: SmashScotChat()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge switches to LIVE automatically when authenticated
      expect(find.text('LIVE'), findsOneWidget);

      // Turn 1: Search courts via Quick Action pill
      await tester.tap(find.text('Court Information'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hai Chau Badminton Center'),
        findsOneWidget,
      );
      expect(sentPayloads, hasLength(1));
      expect(sentPayloads.first['history'], isNull);

      // Turn 2: Attempt to access Owner revenue as Player (multi-turn context included)
      await tester.enterText(
        find.byType(EditableText),
        'What is my facility revenue today?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(sentPayloads, hasLength(2));
      expect(sentPayloads[1]['history'], isA<List>());
      expect((sentPayloads[1]['history'] as List).length, 2);
      expect(
        find.textContaining('restricted strictly to COURT_OWNER'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chat collapses quick actions after first message and avoids keyboard overlap without header overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final viewInsets = ValueNotifier<EdgeInsets>(EdgeInsets.zero);
      addTearDown(viewInsets.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: ValueListenableBuilder<EdgeInsets>(
            valueListenable: viewInsets,
            builder: (context, insets, _) => MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  viewInsets: insets,
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: const Scaffold(body: SmashScotChat()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quick actions remain available before conversation starts
      expect(find.text('Court Information'), findsOneWidget);

      // Simulate iOS keyboard appearing (336pt bottom inset)
      viewInsets.value = const EdgeInsets.only(bottom: 336);
      await tester.pumpAndSettle();

      // Send a message while keyboard is open
      await tester.tap(find.text('Court Information'));
      await tester.pumpAndSettle();

      // Latest message is visible and quick actions remain accessible in compact strip
      expect(find.textContaining('10 illustrative facilities'), findsOneWidget);
      expect(find.text('Player Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
