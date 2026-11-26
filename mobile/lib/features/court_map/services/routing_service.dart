import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RoutePreview {
  const RoutePreview(this.points, this.distance, this.duration);
  final List<LatLng> points;
  final double distance, duration;
}

class RoutingService {
  RoutingService({Dio? dio, String? baseUrl})
    : _dio = dio ?? Dio(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'OSRM_BASE_URL',
            defaultValue: kDebugMode ? 'https://router.project-osrm.org' : '',
          );
  final Dio _dio;
  final String baseUrl;
  final _cache = <String, RoutePreview>{};
  Future<RoutePreview> route(LatLng origin, LatLng destination) async {
    bool valid(LatLng p) =>
        p.latitude.isFinite &&
        p.longitude.isFinite &&
        p.latitude.abs() <= 90 &&
        p.longitude.abs() <= 180;
    if (!valid(origin) || !valid(destination)) {
      throw StateError('Invalid coordinates.');
    }
    if (baseUrl.isEmpty) throw StateError('Routing service is not configured.');
    final path =
        '${origin.longitude.toStringAsFixed(6)},${origin.latitude.toStringAsFixed(6)};${destination.longitude.toStringAsFixed(6)},${destination.latitude.toStringAsFixed(6)}';
    if (_cache.containsKey(path)) return _cache[path]!;
    final response = await _dio.get(
      '$baseUrl/route/v1/driving/$path',
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    final data = response.data;
    if (data is! Map ||
        data['code'] != 'Ok' ||
        data['routes'] is! List ||
        (data['routes'] as List).isEmpty) {
      throw StateError('No route available.');
    }
    final r = data['routes'][0];
    final geometry = r['geometry'];
    if (geometry is! Map ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List ||
        r['distance'] is! num ||
        r['duration'] is! num) {
      throw StateError('Invalid routing response.');
    }
    final points = <LatLng>[];
    for (final p in geometry['coordinates']) {
      if (p is! List || p.length < 2 || p[0] is! num || p[1] is! num) {
        throw StateError('Invalid route geometry.');
      }
      final point = LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
      if (!valid(point)) throw StateError('Invalid route coordinate.');
      points.add(point);
    }
    final distance = (r['distance'] as num).toDouble(),
        duration = (r['duration'] as num).toDouble();
    if (points.length < 2 ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) {
      throw StateError('Invalid route data.');
    }
    return _cache[path] = RoutePreview(points, distance, duration);
  }
}
