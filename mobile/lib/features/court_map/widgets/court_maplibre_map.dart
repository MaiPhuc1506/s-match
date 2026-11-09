import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../exploration_data.dart';
import 'native_court_layers.dart';
import 'native_player_layers.dart';

/// Controller interface to programmatically control the CourtMapLibreMap.
abstract class CourtMapController {
  Future<void> recenter();
  Future<void> moveToCourt(CourtLocation court);
  Future<void> zoomIn();
  Future<void> zoomOut();
  LatLng? get center;
  double? get zoom;
}

/// Reusable MapLibre GL widget for S-Match court discovery.
///
/// Uses S-Match Mint custom MapLibre style (`assets/map/smatch_mint_style.json`)
/// with OpenFreeMap vector tiles, preserving the approved Figma visual elements
/// (pins, accuracy halo, selected bubble, cluster badge).
class CourtMapLibreMap extends StatefulWidget {
  final List<CourtLocation> courts;
  final List<NearbyPlayer> players;
  final bool showPlayers;
  final ValueChanged<NearbyPlayer>? onPlayerSelected;
  final CourtLocation? selectedCourt;
  final bool showPins;
  final bool showAccuracy;
  final bool showCluster;
  final bool showSelection;
  final ValueChanged<CourtLocation>? onCourtSelected;
  final VoidCallback? onCourtPreview;
  final VoidCallback? onClusterTap;
  final VoidCallback? onBackgroundTap;
  final void Function(CourtMapController controller)? onMapReady;
  final LatLng initialCenter;
  final double initialZoom;
  final String styleString;

  const CourtMapLibreMap({
    super.key,
    required this.courts,
    this.players = const [],
    this.showPlayers = false,
    this.onPlayerSelected,
    this.selectedCourt,
    this.showPins = true,
    this.showAccuracy = true,
    this.showCluster = false,
    this.showSelection = true,
    this.onCourtSelected,
    this.onCourtPreview,
    this.onClusterTap,
    this.onBackgroundTap,
    this.onMapReady,
    this.initialCenter = const LatLng(16.0610, 108.2165),
    this.initialZoom = 14.0,
    this.styleString = smatchMintStyleAsset,
  });

  /// S-Match Mint custom MapLibre style asset path
  static const String smatchMintStyleAsset =
      'assets/map/smatch_mint_style.json';

  /// OpenFreeMap Liberty style endpoint (preserved as fallback reference)
  static const String openFreeMapLibertyStyle =
      'https://tiles.openfreemap.org/styles/liberty';

  /// Standard reference user location in Da Nang
  static const LatLng userLocation = LatLng(16.0630, 108.2160);

  @override
  State<CourtMapLibreMap> createState() => CourtMapLibreMapState();
}

class CourtMapLibreMapState extends State<CourtMapLibreMap>
    implements CourtMapController {
  MapLibreMapController? _mapLibreController;
  NativeCourtLayers? _nativeLayers;
  NativePlayerLayers? _nativePlayers;
  late CameraPosition _currentCamera;
  Offset? _selectedOffset;
  bool _moving = false;
  bool _syncing = false;
  bool _syncPending = false;
  int _projectionGeneration = 0;
  String? _mapError;
  Size? _viewportSize;
  double? _trackpadZoom;
  bool _installingSimulatorPinch = false;

  @override
  LatLng get center => _currentCamera.target;
  @override
  double get zoom => _currentCamera.zoom;
  @override
  void initState() {
    super.initState();
    _currentCamera = CameraPosition(
      target: widget.initialCenter,
      zoom: widget.initialZoom,
    );
  }

  @override
  void didUpdateWidget(CourtMapLibreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_syncNative());
    if (oldWidget.selectedCourt != widget.selectedCourt ||
        oldWidget.showSelection != widget.showSelection) {
      unawaited(_refreshCallout());
    }
  }

  @override
  void dispose() {
    _projectionGeneration++;
    _nativeLayers?.disposed = true;
    _nativePlayers?.disposed = true;
    _mapLibreController?.onFeatureTapped.remove(_onFeatureTap);
    // MapLibreMap owns and disposes its controller.
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapLibreController = controller;
    controller.onFeatureTapped.add(_onFeatureTap);
    unawaited(_installSimulatorPinch());
    widget.onMapReady?.call(this);
    unawaited(_refreshCallout());
  }

  Future<void> _installSimulatorPinch() async {
    if (kIsWeb ||
        !kDebugMode ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        _installingSimulatorPinch) {
      return;
    }
    _installingSimulatorPinch = true;
    try {
      // UIKit platform views are attached during composition, after onMapCreated.
      await WidgetsBinding.instance.endOfFrame;
      for (var attempt = 0; attempt < 8 && mounted; attempt++) {
        final installed = await const MethodChannel(
          'smatch/simulator_map_pinch',
        ).invokeMethod<int>('install');
        if (installed != null && installed > 0) {
          debugPrint(
            'Simulator pinch: $installed native map view(s) registered',
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      if (mounted) {
        debugPrint('Simulator pinch: native map view is not attached');
      }
    } on MissingPluginException {
      // Intentionally absent on physical iPhones and non-iOS platforms.
    } on PlatformException catch (error) {
      debugPrint('Simulator pinch adapter: ${error.code}');
    } finally {
      _installingSimulatorPinch = false;
    }
  }

  void _onStyleLoaded() {
    final controller = _mapLibreController;
    if (controller == null) return;
    _nativeLayers?.disposed = true;
    _nativePlayers?.disposed = true;
    _nativeLayers = NativeCourtLayers(controller);
    _nativePlayers = NativePlayerLayers(controller);
    unawaited(_installSimulatorPinch());
    unawaited(_syncNative());
    unawaited(_refreshCallout());
  }

  Future<void> _syncNative() async {
    if (_nativeLayers == null || !mounted) return;
    if (_syncing) {
      _syncPending = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncPending = false;
        final layers = _nativeLayers;
        await layers?.sync(
          widget.courts,
          showPins: widget.showPins,
          showCluster: widget.showCluster,
          showAccuracy: widget.showAccuracy,
          referenceLocation: CourtMapLibreMap.userLocation,
        );
        await _nativePlayers?.sync(widget.players, visible: widget.showPlayers);
      } while (mounted && _syncPending);
    } catch (_) {
      if (mounted) {
        setState(() => _mapError = 'Could not load map markers. Tap to retry.');
      }
    } finally {
      _syncing = false;
    }
  }

  void _onFeatureTap(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId == NativePlayerLayers.layer) {
      if (!widget.showPlayers) return;
      for (final player in widget.players) {
        if ('player:${player.id}' == id && player.hasPublicLocation) {
          widget.onPlayerSelected?.call(player);
          break;
        }
      }
    } else if (layerId == NativeCourtLayers.clusterCore ||
        layerId == NativeCourtLayers.clusterCount ||
        layerId == NativeCourtLayers.clusterHalo) {
      unawaited(_expandCluster(point));
    } else if (layerId == NativeCourtLayers.pins ||
        layerId == NativeCourtLayers.clusteredPins) {
      for (final court in widget.courts) {
        if (court.id.toString() == id) {
          widget.onCourtSelected?.call(court);
          break;
        }
      }
    }
  }

  Future<void> _expandCluster(math.Point<double> point) async {
    try {
      await _nativeLayers?.expandCluster(point);
    } catch (_) {
      if (mounted) {
        setState(
          () => _mapError = 'Could not expand this cluster. Tap to retry.',
        );
      }
    }
  }

  // Only the editable callout uses a screen coordinate, once the camera stops.
  // Hide it during movement; never paint an asynchronous, stale projection.
  Future<void> _refreshCallout() async {
    final request = ++_projectionGeneration;
    final court = widget.selectedCourt;
    final controller = _mapLibreController;
    if (_moving ||
        controller == null ||
        court == null ||
        !court.hasCoordinates) {
      return;
    }
    try {
      final points = await controller.toScreenLocationBatch([
        LatLng(court.latitude!, court.longitude!),
      ]);
      if (!mounted ||
          _moving ||
          request != _projectionGeneration ||
          widget.selectedCourt?.id != court.id) {
        return;
      }
      setState(
        () => _selectedOffset = Offset(
          points.single.x.toDouble(),
          points.single.y.toDouble(),
        ),
      );
    } catch (_) {
      if (mounted && request == _projectionGeneration) {
        setState(() => _selectedOffset = null);
      }
    }
  }

  void _beginCameraMove() {
    _projectionGeneration++;
    if (!_moving) {
      setState(() {
        _moving = true;
        _selectedOffset = null;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCamera = position;
    _beginCameraMove();
  }

  void _onCameraIdle() {
    _moving = false;
    unawaited(_refreshCallout());
  }

  @override
  Future<void> recenter() async => _mapLibreController?.animateCamera(
    CameraUpdate.newLatLngZoom(CourtMapLibreMap.userLocation, 14),
  );
  @override
  Future<void> moveToCourt(CourtLocation court) async {
    if (!court.hasCoordinates) return;
    await _mapLibreController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(court.latitude!, court.longitude!), 15),
    );
  }

  @override
  Future<void> zoomIn() async {
    await _mapLibreController?.animateCamera(CameraUpdate.zoomIn());
  }

  @override
  Future<void> zoomOut() async {
    await _mapLibreController?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_viewportSize != size) {
        _viewportSize = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refreshCallout());
        });
      }
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Listener(
              // Forward trackpad pan/zoom events when the host sends them to Flutter.
              // Physical two-finger touch gestures remain owned by the native map.
              onPointerPanZoomStart: (_) => _trackpadZoom = _currentCamera.zoom,
              onPointerPanZoomUpdate: (event) {
                final start = _trackpadZoom;
                if (start == null || event.scale <= 0) return;
                unawaited(
                  _mapLibreController?.moveCamera(
                    CameraUpdate.newLatLngZoom(
                      _currentCamera.target,
                      (start + math.log(event.scale) / math.ln2)
                          .clamp(0, 20)
                          .toDouble(),
                    ),
                  ),
                );
              },
              onPointerPanZoomEnd: (_) => _trackpadZoom = null,
              child: MapLibreMap(
                styleString: widget.styleString,
                initialCameraPosition: CameraPosition(
                  target: widget.initialCenter,
                  zoom: widget.initialZoom,
                ),
                trackCameraPosition: true,
                compassEnabled: false,
                myLocationEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                gestureRecognizers: {
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                },
                annotationOrder: const [],
                symbolPlacementTransitionsEnabled: false,
                attributionButtonPosition: AttributionButtonPosition.topLeft,
                attributionButtonMargins: const math.Point(8, 240),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                onCameraMoveStarted: (_) => _beginCameraMove(),
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                onMapClick: (_, _) => widget.onBackgroundTap?.call(),
              ),
            ),
          ),
          if (!_moving &&
              widget.showSelection &&
              widget.showPins &&
              widget.selectedCourt != null &&
              _selectedOffset != null)
            Positioned(
              left: (_selectedOffset!.dx - 78).clamp(
                0.0,
                math.max(0.0, size.width - 156),
              ),
              top: (_selectedOffset!.dy - 90).clamp(
                0.0,
                math.max(0.0, size.height - 52),
              ),
              width: 156,
              height: 52,
              child: _buildSelectedCalloutBubble(widget.selectedCourt!),
            ),
          if (_mapError != null)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: Material(
                child: TextButton(
                  onPressed: () {
                    setState(() => _mapError = null);
                    unawaited(_syncNative());
                  },
                  child: Text(_mapError!),
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _buildSelectedCalloutBubble(CourtLocation court) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onCourtPreview,
      child: Container(
        width: 156,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(19, 60, 49, 0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Green circular badge: 40 × 40, radius 20
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF05644F),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/sprint6/find_courts/shuttle_white.svg',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 8),

            // Text block: 96 × 36
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    court.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 17 / 12,
                      color: const Color(0xFF102D28),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    court.mapSubtitle,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 15 / 11,
                      color: const Color(0xFF102D28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
