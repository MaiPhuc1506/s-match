import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../exploration_data.dart';

/// Geographic decorations are rendered by MapLibre, on the same frame as tiles.
/// Flutter never projects or moves these markers while the camera is moving.
class NativeCourtLayers {
  NativeCourtLayers(this.controller, {Future<Uint8List> Function()? loadPin})
    : _loadPin = loadPin ?? _pinPng;
  final MapLibreMapController controller;
  final Future<Uint8List> Function() _loadPin;
  static const pins = 'smatch-court-pins';
  static const clusteredPins = 'smatch-clustered-pins';
  static const clusterHalo = 'smatch-cluster-halo';
  static const clusterCore = 'smatch-cluster-core';
  static const clusterCount = 'smatch-cluster-count';
  static const source = 'smatch-courts';
  static const clusteredSource = 'smatch-clustered-courts';
  static const locationSource = 'smatch-reference-location';
  static const locationHalo = 'smatch-location-halo';
  static const locationDot = 'smatch-location-dot';
  final _sources = <String>{};
  final _layers = <String>{};
  String? _dataKey;
  bool _imageAdded = false;
  bool disposed = false;

  static Future<Uint8List> _pinPng() async {
    final info = await vg.loadPicture(
      const SvgAssetLoader('assets/sprint6/find_courts/court_pin.svg'),
      null,
    );
    // Preserve the existing vector artwork at 3x; MapLibre accepts PNG sprites.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(78 / info.size.width, 90 / info.size.height);
    canvas.drawPicture(info.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(78, 90);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Unable to render the court pin.');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
      info.picture.dispose();
    }
  }

  static Map<String, dynamic> features(List<CourtLocation> courts) => {
    'type': 'FeatureCollection',
    'features': [
      for (final c in courts.where((c) => c.hasCoordinates))
        {
          'type': 'Feature',
          'id': c.id,
          'geometry': {
            'type': 'Point',
            'coordinates': [c.longitude, c.latitude],
          },
          'properties': {'courtId': c.id},
        },
    ],
  };

  Future<void> sync(
    List<CourtLocation> courts, {
    required bool showPins,
    required bool showCluster,
    required bool showAccuracy,
    required LatLng referenceLocation,
  }) async {
    if (disposed) return;
    if (!_imageAdded) {
      final bytes = await _loadPin();
      if (disposed) return;
      await controller.addImage('smatch-court-pin', bytes, false, 3);
      _imageAdded = true;
    }
    final data = features(courts);
    for (final id in [source, clusteredSource]) {
      if (disposed) return;
      if (!_sources.contains(id)) {
        await controller.addSource(
          id,
          GeojsonSourceProperties(
            data: data,
            cluster: id == clusteredSource,
            clusterRadius: 60,
            clusterMaxZoom: 18,
          ),
        );
        _sources.add(id);
      }
    }
    final key = courts
        .map((c) => '${c.id}:${c.latitude}:${c.longitude}')
        .join('|');
    if (_dataKey != key) {
      await controller.setGeoJsonSource(source, data);
      await controller.setGeoJsonSource(clusteredSource, data);
      _dataKey = key;
    }
    if (!_sources.contains(locationSource)) {
      await controller.addGeoJsonSource(locationSource, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'reference',
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [
                referenceLocation.longitude,
                referenceLocation.latitude,
              ],
            },
          },
        ],
      });
      _sources.add(locationSource);
    }
    if (disposed) return;
    if (!_layers.contains(locationHalo)) {
      await controller.addCircleLayer(
        locationSource,
        locationHalo,
        const CircleLayerProperties(
          circleRadius: 44,
          circleColor: '#2996F5',
          circleOpacity: .15,
          circlePitchAlignment: 'viewport',
          circlePitchScale: 'viewport',
        ),
        enableInteraction: false,
      );
      _layers.add(locationHalo);
    }
    if (!_layers.contains(locationDot)) {
      await controller.addCircleLayer(
        locationSource,
        locationDot,
        const CircleLayerProperties(
          circleRadius: 10,
          circleColor: '#1689FA',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
          circlePitchAlignment: 'viewport',
          circlePitchScale: 'viewport',
        ),
        enableInteraction: false,
      );
      _layers.add(locationDot);
    }
    for (final id in [pins, clusteredPins]) {
      if (!_layers.contains(id)) {
        await controller.addSymbolLayer(
          id == pins ? source : clusteredSource,
          id,
          const SymbolLayerProperties(
            iconImage: 'smatch-court-pin',
            iconSize: 1,
            iconAnchor: 'bottom',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconPitchAlignment: 'viewport',
            iconRotationAlignment: 'viewport',
          ),
          filter: id == clusteredPins
              ? [
                  '!',
                  ['has', 'point_count'],
                ]
              : null,
        );
        _layers.add(id);
      }
    }
    for (final id in [clusterHalo, clusterCore]) {
      if (!_layers.contains(id)) {
        await controller.addCircleLayer(
          clusteredSource,
          id,
          CircleLayerProperties(
            circleRadius: id == clusterHalo ? 28 : 20,
            circleColor: '#05644F',
            circleOpacity: id == clusterHalo ? .12 : 1,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: id == clusterHalo ? 0 : 2,
            circlePitchAlignment: 'viewport',
            circlePitchScale: 'viewport',
          ),
          filter: ['has', 'point_count'],
        );
        _layers.add(id);
      }
    }
    if (!_layers.contains(clusterCount)) {
      await controller.addSymbolLayer(
        clusteredSource,
        clusterCount,
        const SymbolLayerProperties(
          textField: [
            'to-string',
            ['get', 'point_count'],
          ],
          textFont: ['Noto Sans Regular'],
          textSize: 15,
          textColor: '#FFFFFF',
          textAllowOverlap: true,
          textIgnorePlacement: true,
          textPitchAlignment: 'viewport',
          textRotationAlignment: 'viewport',
        ),
        filter: ['has', 'point_count'],
      );
      _layers.add(clusterCount);
    }
    if (disposed) return;
    await controller.setLayerVisibility(pins, showPins && !showCluster);
    for (final id in [clusteredPins, clusterHalo, clusterCore, clusterCount]) {
      await controller.setLayerVisibility(id, showPins && showCluster);
    }
    for (final id in [locationHalo, locationDot]) {
      await controller.setLayerVisibility(id, showAccuracy);
    }
  }

  Future<void> expandCluster(math.Point<double> point) async {
    final hits = await controller.queryRenderedFeatures(point, [
      clusterCore,
      clusterCount,
    ], null);
    if (disposed || hits.isEmpty) return;
    final feature = Map<String, dynamic>.from(hits.first as Map);
    final properties = feature['properties'] as Map;
    final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
    final expansion = await controller.getClusterExpansionZoom(
      clusteredSource,
      (properties['cluster_id'] as num).toInt(),
    );
    if (disposed) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          (coordinates[1] as num).toDouble(),
          (coordinates[0] as num).toDouble(),
        ),
        math.min(20, expansion + .5).toDouble(),
      ),
    );
  }
}
