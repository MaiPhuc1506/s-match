import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/match/screens/live_open_match_screen.dart';

void main() {
  final oldUser = AuthService.instance.currentUser;
  late InterceptorsWrapper interceptor;

  Map<String, dynamic> match({required DateTime start}) => {
    'id': 999,
    'title': 'Hoa Khanh Badminton',
    'hostId': 3,
    'status': 'OPEN',
    'startTime': start.toUtc().toIso8601String(),
    'endTime': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    'participantCount': 1,
    'maxPlayers': 2,
    'minSkillLevel': 3,
    'maxSkillLevel': 5,
    'participants': [
      {
        'id': 55,
        'userId': 7,
        'status': 'REQUESTED',
        'user': {'fullName': 'Phát Tài'},
      },
    ],
  };

  setUp(() {
    AuthService.instance.currentUser = {
      'id': 3,
      'role': {'name': 'PLAYER'},
    };
  });

  tearDown(() {
    AuthService.instance.currentUser = oldUser;
    ApiClient.instance.dio.interceptors.remove(interceptor);
  });

  Future<void> mount(WidgetTester tester, DateTime start) async {
    interceptor = InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          data: match(start: start),
          statusCode: 200,
        ),
      ),
    );
    ApiClient.instance.dio.interceptors.add(interceptor);
    await tester.pumpWidget(
      const MaterialApp(home: LiveOpenMatchScreen(matchId: 999)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a started match hides pending-request actions and explains why',
    (tester) async {
      await mount(tester, DateTime.now().subtract(const Duration(minutes: 5)));
      expect(
        find.text(
          'This match has started. Pending requests can no longer be approved.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Accept'), findsNothing);
      expect(find.byTooltip('Reject'), findsNothing);
      expect(find.text('REQUESTED'), findsOneWidget);
    },
  );

  testWidgets('a future match keeps the request actions available', (
    tester,
  ) async {
    await mount(tester, DateTime.now().add(const Duration(hours: 1)));
    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(find.byTooltip('Reject'), findsOneWidget);
    expect(
      find.text(
        'This match has started. Pending requests can no longer be approved.',
      ),
      findsNothing,
    );
  });
}
