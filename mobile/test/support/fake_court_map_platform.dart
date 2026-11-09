import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Test adapter only. Native rendering is verified separately on Simulator.
class FakeCourtMapPlatform extends MapLibrePlatform {
  bool created = false;
  double zoom = 14;
  int projectionRequests = 0;
  final sources = <String, Map<String, dynamic>>{};
  final layers = <String, Map<String, dynamic>>{};
  final visibility = <String, bool>{};
  final cameraUpdates = <CameraUpdate>[];
  @override
  Future<void> addSource(String id, SourceProperties properties) async {
    sources[id] = Map<String, dynamic>.from(properties.toJson());
  }

  @override
  Future<void> addGeoJsonSource(
    String id,
    Map<String, dynamic> data, {
    String? promoteId,
  }) async {
    sources[id] = {'data': data};
  }

  @override
  Future<void> setGeoJsonSource(String id, Map<String, dynamic> data) async {
    sources[id]!['data'] = data;
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
    double? pixelRatio,
  ]) async {}
  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    layers[layerId] = {'source': sourceId, ...properties, 'filter': filter};
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  }) async {
    layers[layerId] = {'source': sourceId, ...properties, 'filter': filter};
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    visibility[layerId] = visible;
  }

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String>? layerIds,
    List<Object>? filter,
  ) async => [
    {
      'properties': {'cluster_id': 7, 'point_count': 3},
      'geometry': {
        'type': 'Point',
        'coordinates': [108.2, 16.06],
      },
    },
  ];
  @override
  Future<int> getClusterExpansionZoom(String sourceId, int clusterId) async =>
      16;
  @override
  Future<bool?> moveCamera(CameraUpdate update) => animateCamera(update);

  @override
  Widget buildView(
    Map<String, dynamic> params,
    OnPlatformViewCreatedCallback onCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestures,
  ) {
    if (!created) {
      created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => onCreated(1));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onMapClickPlatform.call({
        'point': const Point(0.0, 0.0),
        'latLng': const LatLng(16, 108),
      }),
      child: const SizedBox.expand(),
    );
  }

  @override
  Future<void> initPlatform(int id) async {}
  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> options,
  ) async => null;
  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> points) async {
    projectionRequests++;
    return points.indexed
        .map(
          (entry) => Point<double>(
            180 + entry.$1 * (zoom > 15 ? 90.0 : 10.0),
            350 + entry.$1 * 5.0,
          ),
        )
        .toList();
  }

  @override
  Future<bool?> animateCamera(CameraUpdate update, {Duration? duration}) async {
    cameraUpdates.add(update);
    final json = update.toJson() as List;
    LatLng target = const LatLng(16.061, 108.2165);
    if (json.first == 'newLatLngZoom') {
      zoom = (json[2] as num).toDouble();
      final raw = json[1] as List;
      target = LatLng((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
    } else if (json.first == 'zoomIn') {
      zoom++;
    } else if (json.first == 'zoomOut') {
      zoom--;
    }
    final camera = CameraPosition(target: target, zoom: zoom);
    onCameraMovePlatform.call(camera);
    onCameraIdlePlatform.call(camera);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
