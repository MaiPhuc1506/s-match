import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Test adapter only. Native rendering is verified separately on Simulator.
class FakeCourtMapPlatform extends MapLibrePlatform {
  bool created = false;
  double zoom = 14;
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
    final json = update.toJson() as List;
    if (json.first == 'newLatLngZoom') {
      zoom = (json[2] as num).toDouble();
      final target = json[1] as List;
      onCameraMovePlatform.call(
        CameraPosition(
          target: LatLng(
            (target[0] as num).toDouble(),
            (target[1] as num).toDouble(),
          ),
          zoom: zoom,
        ),
      );
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
