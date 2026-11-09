import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/widgets/native_player_layers.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Discovery provider uses authenticated API data without demo fallback',
    () async {
      final adapter = _Adapter(200, {
        'candidates': [
          {
            'userId': 91,
            'nickname': ' ',
            'fullName': 'Database Player',
            'skillLevel': 'ADVANCED',
            'distanceKm': 2.75,
          },
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          apiPlayerDiscoveryRepositoryProvider.overrideWithValue(
            ApiPlayerDiscoveryRepository(dio: dio, token: () => 'session'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final players = await container.read(nearbyPlayersProvider.future);
      expect(players.map((p) => p.id), ['91']);
      expect(players.single.name, 'Database Player');
      expect(players.single.distance, 2.75);
      expect(players.single.demo, isFalse);
      expect(adapter.request!.path, '/candidates/nearby');
      expect(adapter.request!.queryParameters, {'radiusKm': 10, 'limit': 100});
      expect(adapter.request!.extra['expectedAuthToken'], 'session');
    },
  );

  for (final entry in <int, Type>{
    400: ExplorationLocationRequired,
    401: ExplorationSignInRequired,
    403: ExplorationAccountAccessDenied,
  }.entries) {
    test('Discovery reports API ${entry.key} without fixtures', () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter(entry.key, {'message': 'Unavailable'});
      await expectLater(
        ApiPlayerDiscoveryRepository(
          dio: dio,
          token: () => 'session',
        ).players(),
        throwsA(predicate((error) => error.runtimeType == entry.value)),
      );
    });
  }

  test(
    'Live discovery discards private coordinates and unsupported metadata',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _Adapter(200, {
          'candidates': [
            {
              'userId': 42,
              'fullName': 'Actual Player',
              'skillLevel': 'INTERMEDIATE',
              'distanceKm': 1.4,
              'latitude': 16.061234,
              'longitude': 108.212345,
            },
          ],
        });
      final players = await ApiPlayerDiscoveryRepository(
        dio: dio,
        token: () => 'session',
      ).players();
      expect(players.single.id, '42');
      expect(players.single.level, 'Intermediate');
      expect(players.single.playingArea, isNull);
      expect(players.single.availableNow, isNull);
      expect(players.single.demo, isFalse);
      expect(NativePlayerLayers.features(players)['features'], isEmpty);
    },
  );
  test('Live failures do not silently return demo players', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter(500, {'message': 'Unavailable'});
    expect(
      ApiPlayerDiscoveryRepository(dio: dio, token: () => 'session').players(),
      throwsA(isA<DioException>()),
    );
    expect(
      ApiPlayerDiscoveryRepository(dio: dio, token: () => null).players(),
      throwsA(isA<ExplorationSignInRequired>()),
    );
  });
  test(
    'Native player layer uses only valid explicitly permitted playing areas',
    () {
      NearbyPlayer player(String id, DiscoveryPlayingArea area) => NearbyPlayer(
        id,
        'Player',
        'Beginner',
        2,
        '',
        '',
        '',
        Offset.zero,
        playingArea: area,
      );
      final data = NativePlayerLayers.features([
        player(
          'public',
          const DiscoveryPlayingArea(
            'Public hall',
            16.06,
            108.21,
            permitted: true,
          ),
        ),
        player(
          'private',
          const DiscoveryPlayingArea(
            'Private',
            16.06,
            108.21,
            permitted: false,
          ),
        ),
        player(
          'invalid',
          const DiscoveryPlayingArea('Invalid', 100, 108.21, permitted: true),
        ),
      ]);
      final features = data['features'] as List;
      expect(features, hasLength(1));
      expect(features.single['id'], 'player:public');
      expect(features.single['geometry']['coordinates'], [108.21, 16.06]);
    },
  );
}
