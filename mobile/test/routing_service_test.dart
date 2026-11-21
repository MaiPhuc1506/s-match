import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mobile/features/court_map/services/routing_service.dart';

void main() {
  test('OSRM uses longitude first, parses latitude first and caches', () async {
    final dio = Dio();
    var calls = 0;
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          calls++;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'code': 'Ok',
                'routes': [
                  {
                    'distance': 1234,
                    'duration': 300,
                    'geometry': {
                      'type': 'LineString',
                      'coordinates': [
                        [108.2, 16.0],
                        [108.15, 16.08],
                      ],
                    },
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final service = RoutingService(dio: dio, baseUrl: 'https://route.example');
    final result = await service.route(
      const LatLng(16, 108.2),
      const LatLng(16.08, 108.15),
    );
    expect(
      request!.path,
      contains('108.200000,16.000000;108.150000,16.080000'),
    );
    expect(result.points.last.latitude, 16.08);
    expect(result.points.last.longitude, closeTo(108.15, 0.000001));
    expect(result.distance, 1234);
    await service.route(const LatLng(16, 108.2), const LatLng(16.08, 108.15));
    expect(calls, 1);
  });
  test('NoRoute produces an error', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {'code': 'NoRoute', 'routes': []},
            ),
          ),
        ),
      );
    expect(
      () => RoutingService(
        dio: dio,
        baseUrl: 'https://route.example',
      ).route(const LatLng(16, 108), const LatLng(17, 109)),
      throwsStateError,
    );
  });
}
