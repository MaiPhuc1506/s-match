import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/player_experience/platform_view/bot_avatar_view.dart';
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

  testWidgets('Live chat reads the facilities provider', (tester) async {
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
}
