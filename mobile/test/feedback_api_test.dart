import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/feedback/data/feedback_repository.dart';
import 'package:mobile/features/feedback/data/rating_api.dart';
import 'package:mobile/features/feedback/screens/rating_history_screen.dart';
import 'package:mobile/features/feedback/screens/feedback_form_screen.dart';
import 'package:mobile/features/feedback/screens/community_rating_screen.dart';

void main() {
  final client = ApiClient.instance;
  late InterceptorsWrapper interceptor;
  late ApiFeedbackRepository repo;
  final requests = <RequestOptions>[];
  final saved = <Map<String, dynamic>>[];
  String status = 'COMPLETED';
  bool participant = true, failSecond = false;
  int? failStatus;
  Map<String, dynamic> summary() => {
    'ratingCount': saved.length,
    'communityRating': saved.isEmpty ? null : 4.0,
    'reliabilityScore': 4.5,
    'distribution': {'4': saved.length},
  };
  final players = [
    const FeedbackPlayer('2', 'Player Two', ''),
    const FeedbackPlayer('3', 'Player Three', ''),
  ];
  List<TeammateFeedback> entries() => players
      .map(
        (p) => TeammateFeedback(
          player: p,
          stars: 4,
          tags: {'Fair play'},
          review: 'Chơi rất vui',
        ),
      )
      .toList();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    requests.clear();
    saved.clear();
    status = 'COMPLETED';
    participant = true;
    failSecond = false;
    failStatus = null;
    client.setToken('rating-test');
    AuthService.instance.currentUser = {'id': 1, 'fullName': 'Player One'};
    repo = ApiFeedbackRepository(RatingApi(userId: 1, token: 'rating-test'));
    interceptor = InterceptorsWrapper(
      onRequest: (o, h) {
        requests.add(o);
        final path = o.uri.path;
        if (failStatus != null ||
            (path == '/ratings' && failSecond && saved.length == 1)) {
          h.reject(
            DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: o,
                statusCode: failStatus ?? 503,
              ),
            ),
          );
          return;
        }
        dynamic data;
        if (path == '/matches/10/complete' && o.method == 'PATCH') {
          status = 'COMPLETED';
          data = {};
        } else if (path.endsWith('/summary')) {
          data = summary();
        } else if (path == '/matches/10') {
          data = {
            'id': 10,
            'title': 'Real Match',
            'status': status,
            'hostId': 1,
            'mode': 'DOUBLES',
            'startTime': '2026-01-01T10:00:00Z',
            'endTime': '2026-01-01T11:00:00Z',
            'location': 'Real Court',
            'participants': [
              if (participant)
                {
                  'userId': 1,
                  'status': 'ACCEPTED',
                  'user': {'id': 1, 'fullName': 'Player One'},
                },
              for (final p in players)
                {
                  'userId': int.parse(p.id),
                  'status': 'ACCEPTED',
                  'user': {'id': int.parse(p.id), 'fullName': p.name},
                },
            ],
          };
        } else if (path == '/ratings' && o.method == 'POST') {
          final body = Map<String, dynamic>.from(o.data as Map);
          data = {
            ...body,
            'id': saved.length + 1,
            'rater': {'id': 1, 'fullName': 'Player One'},
            'ratedUser': {
              'id': body['ratedUserId'],
              'fullName': players
                  .firstWhere((p) => p.id == '${body['ratedUserId']}')
                  .name,
            },
            'match': {'id': 10, 'title': 'Real Match'},
            'createdAt': '2026-01-01T12:00:00Z',
          };
          saved.add(Map<String, dynamic>.from(data as Map));
        } else if (path == '/ratings/pending') {
          data = [
            {
              'matchId': 10,
              'title': 'Real Match',
              'players': [
                for (final p in players)
                  {'id': int.parse(p.id), 'fullName': p.name},
              ],
            },
          ];
        } else if (path == '/players/profile/me') {
          data = {
            'fullName': 'Player One',
            'playerProfile': {'bio': ''},
          };
        } else {
          data = {
            'items': path == '/ratings/given' ? saved.toList() : [],
            'page': 1,
            'totalPages': 1,
            'total': saved.length,
          };
        }
        h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
      },
    );
    client.dio.interceptors.add(interceptor);
  });
  tearDown(() {
    client.dio.interceptors.remove(interceptor);
    client.clearToken();
    AuthService.instance.currentUser = null;
    repo.dispose();
  });
  test('uses authenticated SMM36 contract; tags and sender are never invented in payload', () async {
    await repo.submit('10', entries());
    expect(saved.length, 2);
    expect(repo.summary?.count, 2);
    expect(repo.given.first.player.name, 'Player Two');
    final writes = requests.where((r) => r.method == 'POST').toList();
    expect(writes.first.headers['Authorization'], 'Bearer rating-test');
    expect(writes.first.data, {
      'matchId': 10,
      'ratedUserId': 2,
      'score': 4,
      'comment': 'Chơi rất vui',
    });
    await expectLater(repo.submit('10', entries()), throwsStateError);
    expect(saved.length, 2);
  });
  test(
    'partial failure retries only recipients confirmed missing on server',
    () async {
      failSecond = true;
      await expectLater(
        repo.submit('10', entries()),
        throwsA(isA<RatingFailure>()),
      );
      expect(saved.length, 1);
      expect(repo.submitting, false);
      expect(repo.submitted('10'), false);
      failSecond = false;
      await repo.submit('10', entries());
      expect(saved.map((r) => r['ratedUserId']), [2, 3]);
    },
  );
  test('blocks preview IDs, self/non participants, uncompleted matches before POST', () async {
    await expectLater(
      repo.submit('preview', entries()),
      throwsA(isA<RatingFailure>()),
    );
    status = 'OPEN';
    await expectLater(
      repo.submit('10', entries()),
      throwsA(isA<RatingFailure>()),
    );
    status = 'COMPLETED';
    participant = false;
    await expectLater(
      repo.submit('10', entries()),
      throwsA(isA<RatingFailure>()),
    );
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
  test('expired permissions and switched accounts do not fall back to sample ratings', () async {
    failStatus = 403;
    await repo.refresh();
    expect(repo.error, isNotNull);
    expect(repo.received, isEmpty);
    expect(repo.summary, isNull);
    client.setToken('other-account');
    requests.clear();
    await expectLater(
      repo.submit('10', entries()),
      throwsA(isA<RatingFailure>()),
    );
    expect(requests, isEmpty);
  });
  test('Dio rejects a queued request bound to the previous account', () async {
    client.setToken('new-account');
    await expectLater(
      client.dio.get(
        '/ratings/given',
        options: Options(extra: {'expectedAuthToken': 'rating-test'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(requests, isEmpty);
  });
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('live rating layouts fit $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final match = FeedbackMatch(
        id: '10',
        title: 'Real Match',
        players: players,
      );
      for (final screen in <Widget>[
        RatingHistoryScreen(repository: repo),
        CommunityRatingScreen(player: players.first, live: true),
        FeedbackFormScreen(repository: repo, match: match, matchId: '10'),
        const PlayerProfileScreen(),
      ]) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
    'real pending match -> completed -> form -> saved Given history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: RatingHistoryScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 ratings'), findsOneWidget);
      await tester.tap(find.text('Real Match'));
      await tester.pumpAndSettle();
      expect(find.text('Match Complete!'), findsOneWidget);
      expect(find.textContaining('UI preview'), findsNothing);
      await tester.ensureVisible(find.text('Rate Your Teammates'));
      await tester.tap(find.text('Rate Your Teammates'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackFormScreen), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        final card = find.byKey(ValueKey('feedback-card-$i'));
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
      await tester.pumpAndSettle();
      expect(saved.length, 2);
      await tester.ensureVisible(find.text('View Rating History'));
      await tester.tap(find.text('View Rating History'));
      await tester.pumpAndSettle();
      expect(find.text('To Player Two'), findsOneWidget);
      expect(find.textContaining('UI preview'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('host explicitly completes an ended match before celebration', (
    tester,
  ) async {
    status = 'OPEN';
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: RatingHistoryScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real Match'));
    await tester.pumpAndSettle();
    expect(find.text('Complete Match'), findsOneWidget);
    expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    await tester.tap(find.text('Complete Match'));
    await tester.pumpAndSettle();
    expect(find.text('Match Complete!'), findsOneWidget);
    expect(find.textContaining('UI preview'), findsNothing);
    expect(
      requests
          .where(
            (r) => r.uri.path == '/matches/10/complete' && r.method == 'PATCH',
          )
          .length,
      1,
    );
    expect(saved, isEmpty);
  });
  testWidgets(
    'authenticated Profile replaces static rating and refreshes on rating event',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlayerProfileScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('4.6 (24)', findRichText: true), findsNothing);
      saved.add({'score': 4});
      ratingRevision.value++;
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4.0 (1)', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'community uses actual empty summary instead of fixture ratings',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityRatingScreen(player: players.first, live: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('No ratings yet'), 180);
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(find.text('4.9'), findsNothing);
      expect(find.textContaining('Reliability 4.50/5'), findsOneWidget);
    },
  );
}
