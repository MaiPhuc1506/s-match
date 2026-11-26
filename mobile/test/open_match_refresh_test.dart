import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/match/screens/live_open_match_list_screen.dart';
import 'package:mobile/features/match/screens/live_open_match_screen.dart';

void main() {
  testWidgets('section changes rebuild and show pending requests', (
    tester,
  ) async {
    final client = ApiClient.instance;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: [
              {
                'id': 7,
                'status': 'OPEN',
                'myStatus': 'PENDING',
                'currentPlayers': 1,
                'maxPlayers': 4,
                'startTime': '2026-12-06T08:00:00Z',
                'booking': {
                  'court': {
                    'name': 'Court 1',
                    'facility': {'name': 'Pending test facility'},
                  },
                },
              },
            ],
          ),
        );
      },
    );
    client.dio.interceptors.add(interceptor);
    addTearDown(() => client.dio.interceptors.remove(interceptor));
    await tester.pumpWidget(const MaterialApp(home: LiveOpenMatchListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Matches'));
    await tester.pumpAndSettle();
    expect(find.text('No matches yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pending test facility'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pending test facility'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('started match cannot submit a new join request', (tester) async {
    final client = ApiClient.instance;
    var mutations = 0;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method != 'GET') mutations++;
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'id': 7,
              'hostId': 3,
              'status': 'OPEN',
              'startTime': '2020-01-01T08:00:00Z',
              'endTime': '2020-01-01T09:00:00Z',
              'participantCount': 2,
              'maxPlayers': 4,
            },
          ),
        );
      },
    );
    client.dio.interceptors.add(interceptor);
    addTearDown(() => client.dio.interceptors.remove(interceptor));
    await tester.pumpWidget(
      const MaterialApp(home: LiveOpenMatchScreen(matchId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('This match has started'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Request to Join'),
    );
    expect(button.onPressed, isNull);
    expect(mutations, 0);
  });
  testWidgets('organizer confirms early finish through the real API contract', (
    tester,
  ) async {
    final client = ApiClient.instance;
    final previous = AuthService.instance.currentUser;
    AuthService.instance.currentUser = {'id': 3};
    addTearDown(() => AuthService.instance.currentUser = previous);
    var completed = false;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'PATCH') {
          expect(options.path, '/matches/7/complete');
          completed = true;
        }
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'id': 7,
              'hostId': 3,
              'status': completed ? 'COMPLETED' : 'OPEN',
              'myStatus': 'ACCEPTED',
              'startTime': DateTime.now()
                  .subtract(const Duration(minutes: 1))
                  .toUtc()
                  .toIso8601String(),
              'endTime': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'participantCount': 2,
              'maxPlayers': 4,
            },
          ),
        );
      },
    );
    client.dio.interceptors.add(interceptor);
    addTearDown(() => client.dio.interceptors.remove(interceptor));
    await tester.pumpWidget(
      const MaterialApp(home: LiveOpenMatchScreen(matchId: 7)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish Match'));
    await tester.pumpAndSettle();
    expect(completed, false);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(completed, false);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish Match'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, 'Finish Match'),
    );
    await tester.pumpAndSettle();
    expect(completed, true);
    expect(find.widgetWithText(FilledButton, 'Finish Match'), findsNothing);
    expect(find.text('Give feedback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scenario in [
    (
      name: 'non-organizer',
      hostId: 8,
      status: 'IN_PROGRESS',
      future: false,
      accepted: true,
      feedback: false,
    ),
    (
      name: 'upcoming',
      hostId: 3,
      status: 'OPEN',
      future: true,
      accepted: true,
      feedback: false,
    ),
    (
      name: 'cancelled',
      hostId: 3,
      status: 'CANCELLED',
      future: false,
      accepted: true,
      feedback: false,
    ),
    (
      name: 'completed accepted',
      hostId: 3,
      status: 'COMPLETED',
      future: false,
      accepted: true,
      feedback: true,
    ),
    (
      name: 'completed unaccepted',
      hostId: 3,
      status: 'COMPLETED',
      future: false,
      accepted: false,
      feedback: false,
    ),
  ]) {
    testWidgets('${scenario.name} has correct Finish/Feedback eligibility', (
      tester,
    ) async {
      final previous = AuthService.instance.currentUser;
      AuthService.instance.currentUser = {'id': 3};
      addTearDown(() => AuthService.instance.currentUser = previous);
      var writes = 0;
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method != 'GET') writes++;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 7,
                'hostId': scenario.hostId,
                'status': scenario.status,
                'myStatus': scenario.accepted ? 'ACCEPTED' : 'REJECTED',
                'startTime': DateTime.now()
                    .add(Duration(hours: scenario.future ? 1 : -2))
                    .toUtc()
                    .toIso8601String(),
                'endTime': DateTime.now()
                    .add(Duration(hours: scenario.future ? 2 : -1))
                    .toUtc()
                    .toIso8601String(),
                'participantCount': 2,
                'maxPlayers': 4,
              },
            ),
          );
        },
      );
      ApiClient.instance.dio.interceptors.add(interceptor);
      addTearDown(
        () => ApiClient.instance.dio.interceptors.remove(interceptor),
      );
      await tester.pumpWidget(
        const MaterialApp(home: LiveOpenMatchScreen(matchId: 7)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Finish Match'), findsNothing);
      expect(
        find.text('Give feedback'),
        scenario.feedback ? findsOneWidget : findsNothing,
      );
      expect(writes, 0);
    });
  }
}
