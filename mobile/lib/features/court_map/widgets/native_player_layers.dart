import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../exploration_data.dart';

/// Native, geographically anchored player bubbles; only permitted public areas.
class NativePlayerLayers {
  NativePlayerLayers(this.controller);
  final MapLibreMapController controller;
  static const source = 'smatch-public-player-areas';
  static const layer = 'smatch-public-player-markers';
  bool _sourceAdded = false, _layerAdded = false;
  final _images = <String>{};
  bool disposed = false;

  static Map<String, dynamic> features(List<NearbyPlayer> players) => {
    'type': 'FeatureCollection',
    'features': [
      for (final p in players.where((p) => p.hasPublicLocation))
        {
          'type': 'Feature',
          'id': 'player:${p.id}',
          'geometry': {
            'type': 'Point',
            'coordinates': [p.playingArea!.longitude, p.playingArea!.latitude],
          },
          'properties': {
            'image':
                'smatch-player-${p.id}-${p.avatar.hashCode}-${p.level.hashCode}-${p.distance}',
            'draggable': false,
          },
        },
    ],
  };

  Future<void> sync(List<NearbyPlayer> players, {required bool visible}) async {
    if (disposed) return;
    final data = features(players);
    for (final p in players.where((p) => p.hasPublicLocation)) {
      final name =
          'smatch-player-${p.id}-${p.avatar.hashCode}-${p.level.hashCode}-${p.distance}';
      if (_images.contains(name)) continue;
      final bytes = await _bubble(p);
      if (disposed) return;
      await controller.addImage(name, bytes, false, 3);
      _images.add(name);
    }
    if (disposed) return;
    if (!_sourceAdded) {
      await controller.addGeoJsonSource(source, data);
      _sourceAdded = true;
    } else {
      await controller.setGeoJsonSource(source, data);
    }
    if (!_layerAdded) {
      await controller.addSymbolLayer(
        source,
        layer,
        const SymbolLayerProperties(
          iconImage: ['get', 'image'],
          iconSize: 1,
          iconAnchor: 'left',
          iconOffset: [-30, 0],
          iconAllowOverlap: false,
          iconIgnorePlacement: false,
          iconRotationAlignment: 'viewport',
          iconPitchAlignment: 'viewport',
        ),
      );
      _layerAdded = true;
    }
    if (!disposed) await controller.setLayerVisibility(layer, visible);
  }

  Future<Uint8List> _bubble(NearbyPlayer player) async {
    ui.Image? avatar;
    if (player.avatar.isNotEmpty) {
      final data = await rootBundle.load(player.avatar);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: 132,
        targetHeight: 132,
      );
      try {
        avatar = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(3)
      ..translate(6, 6);
    final shape = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 145, 50),
      const Radius.circular(18),
    );
    canvas.drawShadow(
      Path()..addRRect(shape),
      const Color(0x14133C31),
      4,
      false,
    );
    canvas.drawRRect(shape, Paint()..color = Colors.white);
    const avatarRect = Rect.fromLTWH(2, 3, 44, 44);
    canvas.save();
    canvas.clipPath(Path()..addOval(avatarRect));
    if (avatar != null) {
      paintImage(
        canvas: canvas,
        rect: avatarRect,
        image: avatar,
        fit: BoxFit.cover,
      );
    } else {
      canvas.drawRect(avatarRect, Paint()..color = const Color(0xFFEAF6EF));
      final icon = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.person.codePoint),
          style: TextStyle(
            fontFamily: Icons.person.fontFamily,
            fontSize: 28,
            color: const Color(0xFF05644F),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(canvas, const Offset(10, 10));
      icon.dispose();
    }
    canvas.restore();
    void label(String text, Offset offset, double size, FontWeight weight) {
      final painter = TextPainter(
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size,
            fontWeight: weight,
            color: const Color(0xFF102D28),
          ),
        ),
      )..layout(maxWidth: 86);
      painter.paint(canvas, offset);
      painter.dispose();
    }

    label(player.level, const Offset(54, 8), 12, FontWeight.w600);
    label(
      '~${player.distance.toStringAsFixed(1)} km',
      const Offset(54, 28),
      11,
      FontWeight.w400,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(471, 186);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Unable to render player marker');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
      avatar?.dispose();
    }
  }
}
