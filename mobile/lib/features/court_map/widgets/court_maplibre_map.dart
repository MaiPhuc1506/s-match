import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../exploration_data.dart';

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
  late CameraPosition _currentCamera;
  final Map<int, Offset> _points = {};
  bool _projecting = false;
  bool _projectionPending = false;
  String? _mapError;
  Size? _viewportSize;

  Future<void> _updatePositions() async {
    if (_mapLibreController == null || !mounted) return;
    if (_projecting) {
      _projectionPending = true;
      return;
    }
    _projecting = true;
    try {
      do {
        _projectionPending = false;
        final courts = widget.courts.where((c) => c.hasCoordinates).toList();
        final positions = await _mapLibreController!.toScreenLocationBatch([
          CourtMapLibreMap.userLocation,
          ...courts.map((c) => LatLng(c.latitude!, c.longitude!)),
        ]);
        if (!mounted) return;
        setState(() {
          _points.clear();
          _points[-1] = Offset(
            positions.first.x.toDouble(),
            positions.first.y.toDouble(),
          );
          for (var i = 0; i < courts.length; i++) {
            _points[courts[i].id] = Offset(
              positions[i + 1].x.toDouble(),
              positions[i + 1].y.toDouble(),
            );
          }
        });
      } while (_projectionPending && mounted);
    } catch (_) {
      if (mounted) {
        setState(() => _mapError = 'Không cập nhật được bản đồ. Hãy thử lại.');
      }
    } finally {
      _projecting = false;
    }
  }

  @override
  void didUpdateWidget(CourtMapLibreMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courts != widget.courts) unawaited(_updatePositions());
  }

  @override
  LatLng? get center => _currentCamera.target;

  @override
  double? get zoom => _currentCamera.zoom;

  @override
  void initState() {
    super.initState();
    _currentCamera = CameraPosition(
      target: widget.initialCenter,
      zoom: widget.initialZoom,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapLibreController = controller;
    widget.onMapReady?.call(this);
    unawaited(_updatePositions());
  }

  void _onCameraMove(CameraPosition position) {
    _currentCamera = position;
    unawaited(_updatePositions());
  }

  @override
  Future<void> recenter() async {
    final target = CourtMapLibreMap.userLocation;

    if (_mapLibreController != null) {
      await _mapLibreController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14.0),
      );
    }
  }

  @override
  Future<void> moveToCourt(CourtLocation court) async {
    if (!court.hasCoordinates) return;
    final target = LatLng(court.latitude!, court.longitude!);
    if (_mapLibreController != null) {
      await _mapLibreController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15.0),
      );
    }
  }

  @override
  Future<void> zoomIn() async {
    if (_mapLibreController != null) {
      await _mapLibreController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  @override
  Future<void> zoomOut() async {
    if (_mapLibreController != null) {
      await _mapLibreController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewportSize != size) {
          _viewportSize = size;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => unawaited(_updatePositions()),
          );
        }

        final userOffset = _points[-1];
        final groups = <List<CourtLocation>>[];
        for (final court in widget.courts.where(
          (c) => _points.containsKey(c.id),
        )) {
          List<CourtLocation>? group;
          if (widget.showCluster) {
            for (final candidate in groups) {
              if ((_points[candidate.first.id]! - _points[court.id]!).distance <
                  60) {
                group = candidate;
                break;
              }
            }
          }
          (group ?? (groups..add(<CourtLocation>[])).last).add(court);
        }
        final singles = groups.where((g) => g.length == 1).map((g) => g.first);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 1. MapLibre GL Interactive vector map layer
            Positioned.fill(
              child: MapLibreMap(
                styleString: widget.styleString,
                initialCameraPosition: CameraPosition(
                  target: widget.initialCenter,
                  zoom: widget.initialZoom,
                ),
                trackCameraPosition: true,
                compassEnabled: false,
                myLocationEnabled: false,
                attributionButtonPosition: AttributionButtonPosition.topLeft,
                attributionButtonMargins: const math.Point(8, 240),
                onStyleLoadedCallback: () => unawaited(_updatePositions()),
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                onCameraIdle: () => unawaited(_updatePositions()),
                onMapClick: (point, coordinates) {
                  widget.onBackgroundTap?.call();
                },
              ),
            ),

            // 2. User Location Halo & Dot (Figma Frame 469:1027 visual spec)
            if (widget.showAccuracy && userOffset != null)
              Positioned(
                left: userOffset.dx - 44,
                top: userOffset.dy - 44,
                width: 88,
                height: 88,
                child: IgnorePointer(child: _buildUserLocationHalo()),
              ),

            // 3. Court Pins (when cluster is off and pins are visible)
            if (widget.showPins)
              for (final court in singles) ...[
                () {
                  final pinOffset = _points[court.id]!;
                  return Positioned(
                    left: pinOffset.dx - 13,
                    top: pinOffset.dy - 30,
                    width: 26,
                    height: 30,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.onCourtSelected?.call(court);
                      },
                      child: SvgPicture.asset(
                        'assets/sprint6/find_courts/court_pin.svg',
                        width: 26,
                        height: 30,
                      ),
                    ),
                  );
                }(),
              ],

            // 4. Selected Court Callout Bubble (Figma Frame 469:1027 spec)
            if (widget.showSelection &&
                widget.showPins &&
                widget.selectedCourt != null &&
                _points.containsKey(widget.selectedCourt!.id)) ...[
              () {
                final selectedOffset = _points[widget.selectedCourt!.id]!;
                return Positioned(
                  left: (selectedOffset.dx - 78).clamp(
                    0.0,
                    math.max(0.0, size.width - 156),
                  ),
                  top: (selectedOffset.dy - 90).clamp(
                    0.0,
                    math.max(0.0, size.height - 52),
                  ),
                  width: 156,
                  height: 52,
                  child: _buildSelectedCalloutBubble(widget.selectedCourt!),
                );
              }(),
            ],

            if (widget.showPins && widget.showCluster)
              for (final group in groups.where((g) => g.length > 1))
                Positioned(
                  left: _points[group.first.id]!.dx - 28,
                  top: _points[group.first.id]!.dy - 28,
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: () async {
                      final controller = _mapLibreController;
                      if (controller != null) {
                        await controller.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(
                              group.first.latitude!,
                              group.first.longitude!,
                            ),
                            (_currentCamera.zoom + 2).clamp(0, 20).toDouble(),
                          ),
                        );
                      }
                    },
                    child: _buildClusterBadge(group.length),
                  ),
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
                      unawaited(_updatePositions());
                    },
                    child: Text(_mapError!),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserLocationHalo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Accuracy halo: 88 × 88, #2996F5 at 15% opacity
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x262996F5),
          ),
        ),
        // Center dot: 20 × 20, #1689FA, white border 3, S3 shadow
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1689FA),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(19, 60, 49, 0.08),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  Widget _buildClusterBadge(int count) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Green halo: 56 × 56, #05644F at 12% opacity
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x1F05644F),
          ),
        ),
        // Green core: 40 × 40, white border 2, S4 shadow
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF05644F),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(19, 60, 49, 0.10),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 21 / 15,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
