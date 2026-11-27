import '../../booking/screens/booking_facility_schedule_screen.dart';
import '../facility_images.dart';
import '../widgets/facility_gallery.dart';

import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/routing_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/navigation/player_bottom_navigation.dart';

import '../exploration_data.dart';
import '../widgets/court_maplibre_map.dart';
import '../widgets/exploration_widgets.dart';
import 'court_preview_screen.dart';
import 'find_players_map_screen.dart';

/// Sprint 6 — Find Courts Map (Figma Frame 469:1027, 393 × 852).
///
/// Implements the schematic map-first court discovery screen with local UI interactions:
/// - Panning schematic canvas with court pins, user location, and cluster.
/// - Floating header (Segmented control, search field, filter button, quick filters).
/// - 3-state draggable Nearby Courts sheet (Collapsed, Half-expanded, Expanded).
/// - Conditional overlays: Search panel, Filters panel, and Map layers panel.
/// - Bottom navigation matching S-Match visual system with Map selected.
class FindCourtsMapScreen extends ConsumerStatefulWidget {
  final VoidCallback? onFindPlayers;
  final bool startWithPlayers;
  final VoidCallback? onSwitchToCourts;
  final ValueChanged<NearbyPlayer>? onPlayerDetail;
  final int? initialFacilityId;
  final double initialMapZoom;
  final bool centerOnFirstCourt;
  final VoidCallback? onCourtPreview;
  final ValueChanged<CourtLocation>? onSelectCourtPreview;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateProfile;
  final VoidCallback? onNavigateMatch;
  final VoidCallback? onNavigateFeedback;

  const FindCourtsMapScreen({
    super.key,
    this.onFindPlayers,
    this.startWithPlayers = false,
    this.onSwitchToCourts,
    this.onPlayerDetail,
    this.initialFacilityId,
    this.initialMapZoom = 14,
    this.centerOnFirstCourt = true,
    this.onCourtPreview,
    this.onSelectCourtPreview,
    this.onNavigateHome,
    this.onNavigateProfile,
    this.onNavigateMatch,
    this.onNavigateFeedback,
  });

  @override
  ConsumerState<FindCourtsMapScreen> createState() =>
      _FindCourtsMapScreenState();
}

enum _SheetSnapState { collapsed, halfExpanded, expanded }

class _FindCourtsMapScreenState extends ConsumerState<FindCourtsMapScreen> {
  late bool _playersMode = widget.startWithPlayers;
  late bool _playersOpened = widget.startWithPlayers;
  final _playersKey = GlobalKey<PlayerDiscoveryOverlayState>();
  List<NearbyPlayer> _visiblePlayers = const [];
  // --- UI States (Initial prototype values from Figma collection) ---
  final _routing = RoutingService();
  CourtLocation? _routeDestination;
  RoutePreview? _route;
  String? _routeError;
  bool _routeLoading = false, _settingsNeeded = false;
  int _routeRequest = 0;
  bool _selection = true; // Sky Badminton bubble selected by default
  CourtLocation? _selectedCourt;
  CourtLocation? _previewCourt;
  bool _previewExpanded = false;
  double _previewDrag = 0;
  Future<void> _mapOperations = Future.value();
  Future<void> _mapOperation(Future<void> Function() action) {
    final next = _mapOperations.catchError((Object _) {}).then((_) => action());
    _mapOperations = next;
    return next;
  }

  String _query = '';
  List<CourtLocation> get _allCourts =>
      ref.read(nearbyCourtsProvider).asData?.value ?? [];
  bool get _supportsDistance => _allCourts.any((c) => c.distanceKm != null);
  bool _supports(String label) => switch (label) {
    'Open now' => _allCourts.any((c) => c.currentlyOpen != null),
    'Indoor' => _allCourts.any((c) => c.courts.isNotEmpty),
    r'$' || r'$$' => _allCourts.any((c) => c.discoveryPriceBand != null),
    _ => true,
  };
  List<CourtLocation> get _courts {
    final all =
        ref.read(nearbyCourtsProvider).asData?.value ?? <CourtLocation>[];
    return all
        .where(
          (c) => ('${c.name} ${c.address}').toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .where((c) {
          if (!_filtersApplied) return true;
          if (_distanceChosen &&
              (c.distanceKm == null ||
                  c.distanceKm! >
                      double.parse(_selectedDistance.split(' ').first))) {
            return false;
          }
          if (_openNowSelected && c.currentlyOpen != true) return false;
          if (_indoorSelected &&
              !c.courts.any((court) => court['courtType'] == 'INDOOR')) {
            return false;
          }
          if ((_price1Selected || _price2Selected) &&
              !(_price1Selected && c.discoveryPriceBand == r'$') &&
              !(_price2Selected && c.discoveryPriceBand == r'$$')) {
            return false;
          }
          return true;
        })
        .toList();
  }

  CourtLocation? get _currentCourt {
    final courts = _courts;
    for (final court in courts) {
      if (court.id == _selectedCourt?.id) return court;
    }
    return courts.isEmpty ? null : courts.first;
  }

  CourtMapController? _courtMapController;
  bool _hasCentered = false;
  void _centerOnFirstCourt() {
    final matches = _allCourts.where((c) => c.id == widget.initialFacilityId);
    final court = widget.initialFacilityId == null
        ? _currentCourt
        : (matches.isEmpty ? null : matches.first);
    if (_playersMode ||
        !widget.centerOnFirstCourt ||
        _hasCentered ||
        _courtMapController == null ||
        court == null ||
        !court.hasCoordinates) {
      return;
    }
    _hasCentered = true;
    _courtMapController!.moveToCourt(court);
    if (widget.initialFacilityId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectMarker(court);
      });
    }
  }

  bool _searchOpen = false;
  bool _filtersOpen = false;
  bool _layersOpen = false;
  bool _cluster = false;
  bool _pins = true;
  final bool _accuracy = true;
  bool _filtersApplied = false;
  bool _distanceChosen = false;

  // Filter values
  String _selectedDistance = '5 km'; // '3 km', '5 km', '10 km'
  bool _openNowSelected = false;
  bool _indoorSelected = false;
  bool _price1Selected = false;
  bool _price2Selected = false;

  // Layer mode: 'standard' or 'cluster'
  String _activeLayer = 'standard';

  // Sheet state
  _SheetSnapState _sheetState = _SheetSnapState.collapsed;
  double _sheetDragDelta = 0;

  Future<void> _startDirections(CourtLocation court) async {
    final request = ++_routeRequest;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchOpen = false;
      _filtersOpen = false;
      _layersOpen = false;
      _previewCourt = null;
      _routeDestination = court;
      _routeLoading = true;
      _routeError = null;
      _route = null;
      _settingsNeeded = false;
    });
    await _mapOperation(() async => _courtMapController?.clearRoute());
    if (!mounted || request != _routeRequest) return;
    try {
      if (!court.hasCoordinates ||
          (court.latitude == 0 && court.longitude == 0)) {
        throw StateError('Destination coordinates are unavailable.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Location services are disabled. Enable them in Settings.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _settingsNeeded = true;
        throw StateError(
          'Location permission is permanently denied. Open Settings to allow it.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was denied.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!position.accuracy.isFinite || position.accuracy > 200) {
        throw StateError(
          'Location is not accurate enough. Move to an open area and retry.',
        );
      }
      if (!mounted || request != _routeRequest) return;
      final route = await _routing.route(
        LatLng(position.latitude, position.longitude),
        LatLng(court.latitude!, court.longitude!),
      );
      if (!mounted || request != _routeRequest) return;
      final map = _courtMapController;
      if (map == null) throw StateError('Map is not ready. Please retry.');
      await _mapOperation(() async {
        if (mounted && request == _routeRequest) await map.showRoute(route);
      });
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _route = route;
        _routeLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _routeRequest) return;
      setState(() {
        _routeLoading = false;
        _routeError = error is StateError
            ? error.message.toString()
            : 'Could not load directions. Check your connection and try again.';
      });
    }
  }

  void _exitDirections() {
    _routeRequest++;
    _mapOperation(() async => _courtMapController?.clearRoute());
    if (_selectedCourt != null) {
      _courtMapController?.moveToCourt(_selectedCourt!);
    }
    setState(() {
      _routeDestination = null;
      _route = null;
      _routeError = null;
      _routeLoading = false;
    });
  }

  Widget _directionsSheet() => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Builder(
                      builder: (_) {
                        final f = _routeDestination!;
                        final photos = FacilityImages.resolve(
                          name: f.name,
                          address: f.address,
                          photos: f.photos,
                        );
                        return photos.isEmpty
                            ? const ColoredBox(
                                color: Color(0xFFE9F3EE),
                                child: Icon(CupertinoIcons.photo),
                              )
                            : FacilityPhoto(
                                photos.first,
                                key: ValueKey('${f.id}:${photos.first}'),
                              );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _routeDestination!.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'From your current location · Driving\nLocation is sent to the routing service for this preview.',
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF1677E8), size: 10),
                    SizedBox(width: 5),
                    Text('Your location', style: TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFFE87D24), size: 10),
                    SizedBox(width: 5),
                    Text('Destination', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_routeLoading)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF7F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(radius: 8),
                    SizedBox(width: 8),
                    Text(
                      'Finding the best route…',
                      style: TextStyle(fontSize: 13, color: Color(0xFF05644F)),
                    ),
                  ],
                ),
              ),
            if (_routeError != null)
              Text(_routeError!, style: const TextStyle(color: Colors.red)),
            if (_route != null)
              Text(
                '${(_route!.distance / 1000).toStringAsFixed(1)} km · ${(_route!.duration / 60).ceil()} min',
                style: const TextStyle(
                  color: Color(0xFF05644F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                if (_route != null)
                  TextButton.icon(
                    onPressed: () => _courtMapController?.fitRoute(),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Fit route'),
                  ),
                if (_routeError != null)
                  TextButton(
                    onPressed: () => _startDirections(_routeDestination!),
                    child: const Text('Retry'),
                  ),
                if (_settingsNeeded)
                  TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                TextButton(
                  onPressed: _exitDirections,
                  child: const Text('Exit directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _selectMarker(CourtLocation court) {
    _courtMapController?.focusCourt(court);
    _routeRequest++;
    _mapOperation(() async => _courtMapController?.clearRoute());
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _routeDestination = null;
      _route = null;
      _routeError = null;
      _routeLoading = false;
      _selectedCourt = court;
      _previewCourt = court;
      _previewExpanded = false;
      _selection = true;
      _searchOpen = false;
      _filtersOpen = false;
      _layersOpen = false;
    });
  }

  Widget _compactCourtPreview(CourtLocation selected) {
    final detail = ref.watch(facilityDetailProvider(selected.id));
    final f = detail.valueOrNull ?? selected;
    final photos = FacilityImages.resolve(
      name: f.name,
      address: f.address,
      photos: f.photos,
    );
    final courts = f.courts
        .where((c) => c['status'] == null || c['status'] == 'ACTIVE')
        .toList();
    final rates = <num>[];
    for (final court in courts) {
      for (final slot in (court['timeSlots'] as List? ?? [])) {
        if (slot is Map && slot['isActive'] != false) {
          if (slot['hourlyRate'] is num) {
            rates.add(slot['hourlyRate'] as num);
          } else if (slot['price'] is num &&
              slot['startTime'] is String &&
              slot['endTime'] is String) {
            int minutes(String time) {
              final parts = time.split(':');
              return (int.tryParse(parts.first) ?? -1000) * 60 +
                  (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
            }

            if (minutes(slot['endTime'] as String) -
                    minutes(slot['startTime'] as String) ==
                60) {
              rates.add(slot['price'] as num);
            }
          }
        }
      }
    }
    rates.sort();
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() > 100) {
            setState(() {
              if (velocity > 0 && !_previewExpanded) {
                _previewCourt = null;
              } else {
                _previewExpanded = velocity < 0;
              }
            });
          }
        },
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.57,
            ),
            child: SingleChildScrollView(
              physics:
                  MediaQuery.textScalerOf(context).scale(1) > 1.1 ||
                      MediaQuery.sizeOf(context).height < 750
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: _previewExpanded
                            ? 'Collapse facility preview'
                            : 'Expand facility preview',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) => _previewDrag = 0,
                          onVerticalDragUpdate: (details) =>
                              _previewDrag += details.delta.dy,
                          onVerticalDragEnd: (_) {
                            if (_previewDrag.abs() > 20) {
                              setState(() {
                                if (_previewDrag > 0 && !_previewExpanded) {
                                  _previewCourt = null;
                                } else {
                                  _previewExpanded = _previewDrag < 0;
                                }
                              });
                            }
                          },
                          onTap: () => setState(
                            () => _previewExpanded = !_previewExpanded,
                          ),
                          child: SizedBox(
                            height: 30,
                            width: double.infinity,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4DEDA),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_previewExpanded) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 150,
                            child: photos.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFFE9F3EE),
                                    child: Icon(
                                      Icons.sports_tennis,
                                      color: Color(0xFF05644F),
                                    ),
                                  )
                                : FacilityPhoto(
                                    photos.first,
                                    fadeIn: true,
                                    key: ValueKey('${f.id}:${photos.first}'),
                                  ),
                          ),
                        ),
                        if (photos.length > 1) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length - 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 84,
                                  child: FacilityPhoto(
                                    photos[index + 1],
                                    fadeIn: true,
                                    key: ValueKey(
                                      '${f.id}:${photos[index + 1]}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_previewExpanded)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: photos.isEmpty
                                    ? const ColoredBox(
                                        color: Color(0xFFE9F3EE),
                                        child: Icon(
                                          Icons.sports_tennis,
                                          color: Color(0xFF05644F),
                                        ),
                                      )
                                    : FacilityPhoto(
                                        photos.first,
                                        fadeIn: true,
                                        key: ValueKey(
                                          '${f.id}:${photos.first}',
                                        ),
                                      ),
                              ),
                            ),
                          if (!_previewExpanded) const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  f.address.isEmpty
                                      ? 'Address unavailable'
                                      : f.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  f.operatingHoursText ??
                                      (detail.isLoading
                                          ? 'Loading hours…'
                                          : 'Hours unavailable'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${courts.isEmpty ? 'Court count unavailable' : '${courts.length} courts'} · ${rates.isEmpty ? 'Price unavailable' : 'From ${rates.first.toStringAsFixed(0)} VND / hour'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF05644F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close preview',
                            onPressed: () =>
                                setState(() => _previewCourt = null),
                            icon: const Icon(Icons.close, size: 20),
                          ),
                        ],
                      ),
                      if (_previewExpanded &&
                          f.description != null &&
                          f.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            f.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF61716B),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              key: const Key('preview-directions'),
                              onPressed: () => _startDirections(f),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF05644F),
                              ),
                              child: const Text('Directions'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('preview-book'),
                              onPressed: () =>
                                  BookingFacilityScheduleScreen.open(
                                    context,
                                    facilityId: f.id,
                                    onViewFacility: _openCourtPreview,
                                  ),
                              child: const Text('Book Court'),
                            ),
                          ),
                        ],
                      ),
                      if (_previewExpanded)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const Key('preview-details'),
                            onPressed: _openCourtPreview,
                            icon: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                            ),
                            label: const Text('View Details'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCourtPreview() {
    if (_currentCourt == null) return;
    if (widget.onSelectCourtPreview != null) {
      widget.onSelectCourtPreview!(_currentCourt!);
    } else if (widget.onCourtPreview != null) {
      widget.onCourtPreview!();
    } else {
      Navigator.of(context)
          .push(
            explorationRoute<void>(
              CourtPreviewScreen(
                location: _currentCourt,
                onDirections: (court) {
                  Navigator.of(context).pop();
                  _startDirections(court);
                },
              ),
              '/court-preview',
            ),
          )
          .then((_) {
            if (mounted) ref.invalidate(nearbyCourtsProvider);
          });
    }
  }

  void _openPlayers() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onFindPlayers != null) {
      widget.onFindPlayers!();
      return;
    }
    setState(() {
      _playersMode = true;
      _playersOpened = true;
      _hasCentered = true;
    });
  }

  void _showCourts() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.onSwitchToCourts != null) {
      widget.onSwitchToCourts!();
      return;
    }
    setState(() => _playersMode = false);
  }

  void _dismissOverlays() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_selection ||
        _searchOpen ||
        _filtersOpen ||
        _layersOpen ||
        _previewCourt != null) {
      setState(() {
        _selection = false;
        _previewCourt = null;
        _searchOpen = false;
        _filtersOpen = false;
        _layersOpen = false;
      });
    }
  }

  void _recenterToUser() {
    _courtMapController?.recenter();
    setState(() {
      _selection = false;
      _searchOpen = false;
      _filtersOpen = false;
      _layersOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(nearbyCourtsProvider);
    ref.listen(nearbyCourtsProvider, (_, next) {
      if (next.hasValue) _centerOnFirstCourt();
    });
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFAFBF9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;
          final navHeight = PlayerBottomNavigation.heightFor(context);
          final mapHeight = screenHeight - navHeight;

          // Sheet design coordinates at 393 × 852:
          // Collapsed: y=648 -> height = 768 - 648 = 120
          // Half: y=472 -> height = 768 - 472 = 296
          // Expanded: y=296 -> height = 768 - 296 = 472
          double sheetHeight;
          switch (_sheetState) {
            case _SheetSnapState.collapsed:
              sheetHeight = 120.0;
              break;
            case _SheetSnapState.halfExpanded:
              sheetHeight = 296.0;
              break;
            case _SheetSnapState.expanded:
              sheetHeight = (mapHeight - 296.0).clamp(296.0, 472.0);
              break;
          }
          sheetHeight = (sheetHeight + _sheetDragDelta).clamp(
            120.0,
            mapHeight - 160.0,
          );

          return Stack(
            children: [
              // LAYER 1: MAP VIEWPORT (0, 0, width, mapHeight)
              Positioned(
                left: 0,
                top: 0,
                width: screenWidth,
                height: mapHeight,
                child: _buildMapViewport(screenWidth, mapHeight),
              ),

              if (_playersOpened)
                Positioned.fill(
                  child: Offstage(
                    offstage: !_playersMode,
                    child: PlayerDiscoveryOverlay(
                      key: _playersKey,
                      onFindCourts: _showCourts,
                      onPlayerDetail: widget.onPlayerDetail,
                      onRecenter: () => _courtMapController?.recenter(),
                      onVisiblePlayersChanged: (players) {
                        if (mounted) setState(() => _visiblePlayers = players);
                      },
                    ),
                  ),
                ),
              // LAYER 2: FLOATING HEADER (Segmented control, Search, Quick filters)
              if (!_playersMode)
                Positioned(
                  left: 0,
                  top: 0,
                  width: screenWidth,
                  child: _buildFloatingHeader(screenWidth),
                ),

              // LAYER 3A: MAP CONTROLS (Location & Layers buttons)
              if (!_playersMode &&
                  _routeDestination == null &&
                  _sheetState != _SheetSnapState.expanded)
                Positioned(
                  right: 16,
                  bottom: navHeight + sheetHeight + 16,
                  child: _buildMapControls(),
                ),

              // LAYER 3B: NEARBY COURTS BOTTOM SHEET
              if (!_playersMode &&
                  _routeDestination == null &&
                  _previewCourt == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navHeight,
                  height: sheetHeight,
                  child: _buildNearbyCourtsSheet(screenWidth, sheetHeight),
                ),

              if (!_playersMode &&
                  _previewCourt != null &&
                  _routeDestination == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navHeight,
                  child: _compactCourtPreview(_previewCourt!),
                ),
              if (_routeDestination != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navHeight,
                  child: _directionsSheet(),
                ),
              // LAYER 4: FIXED BOTTOM NAVIGATION (0, screenHeight - 84, width, 84)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: navHeight,
                child: PlayerBottomNavigation(
                  currentTab: PlayerNavTab.map,
                  onNavigateHome: widget.onNavigateHome,
                  onNavigateMatch: widget.onNavigateMatch,
                  onNavigateFeedback: widget.onNavigateFeedback,
                  onNavigateProfile: widget.onNavigateProfile,
                ),
              ),

              // LAYER 5: CONDITIONAL PANELS
              if (!_playersMode && _searchOpen)
                Positioned(
                  left: (screenWidth - 353) / 2,
                  top: 220,
                  width: 353,
                  child: _buildSearchPanel(),
                ),

              if (!_playersMode && _filtersOpen)
                Positioned(
                  left: (screenWidth - 353) / 2,
                  top: 220,
                  width: 353,
                  child: _buildFiltersPanel(),
                ),

              if (!_playersMode && _layersOpen)
                Positioned(
                  right: 20,
                  top: 360,
                  width: 210,
                  child: _buildLayersPanel(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 1. MAP VIEWPORT & MAPLIBRE VECTOR MAP
  // ==========================================
  Widget _buildMapViewport(double viewportWidth, double viewportHeight) {
    return SizedBox(
      width: viewportWidth,
      height: viewportHeight,
      child: CourtMapLibreMap(
        initialZoom: widget.initialMapZoom,
        courts: _courts,
        players: _visiblePlayers,
        showPlayers: _playersMode,
        onPlayerSelected: (player) =>
            _playersKey.currentState?.showPlayerPreview(player),
        selectedCourt: _currentCourt,
        showPins: _pins && !_playersMode,
        showAccuracy:
            _routeDestination == null &&
            _accuracy &&
            (_playersMode
                ? _visiblePlayers.any((p) => p.demo)
                : _courts.any((court) => court.demo)),
        showCluster: _cluster,
        showSelection:
            _routeDestination == null &&
            _previewCourt == null &&
            _selection &&
            !_playersMode,
        onMapReady: (controller) {
          _courtMapController = controller;
          _centerOnFirstCourt();
        },
        onCourtSelected: _selectMarker,
        onCourtPreview: _openCourtPreview,
        onClusterTap: () {
          setState(() {
            _cluster = false;
            _pins = true;
            _selection = false;
            _layersOpen = false;
            _activeLayer = 'standard';
          });
        },
        onBackgroundTap: _dismissOverlays,
      ),
    );
  }

  // ==========================================
  // 2. FLOATING HEADER
  // ==========================================
  Widget _buildFloatingHeader(double screenWidth) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Segmented Control (353 × 44, radius 22)
            _buildSegmentedControl(),
            const SizedBox(height: 8),

            // Search Row (353 × 44, gap 8)
            _buildSearchRow(),
            const SizedBox(height: 8),

            // Quick Filters (353 × 44, horizontal scroll)
            _buildQuickFiltersRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(19, 60, 49, 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Find Courts (Selected: green bg, white text)
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF05644F),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                'Find Courts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 17 / 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Find Players (Transparent bg, secondary text)
          Expanded(
            child: GestureDetector(
              onTap: _openPlayers,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  'Find Players',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 17 / 12,
                    color: const Color(0xFF647976),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        // Search Input Trigger (301 × 44, white, radius 22, S2 shadow)
        Expanded(
          child: GestureDetector(
            key: const Key('find_courts_search_trigger'),
            onTap: () {
              setState(() {
                _searchOpen = true;
                _filtersOpen = false;
                _layersOpen = false;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(19, 60, 49, 0.06),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/sprint6/find_courts/search.svg',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search court name or area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 18 / 13,
                        color: const Color(0xFF8B9794),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Filter Button (44 × 44, radius 22, S2 shadow)
        GestureDetector(
          key: const Key('find_courts_filter_trigger'),
          onTap: () {
            setState(() {
              _filtersOpen = true;
              _searchOpen = false;
              _layersOpen = false;
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(19, 60, 49, 0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(
                  'assets/sprint6/find_courts/filter.svg',
                  width: 20,
                  height: 20,
                ),
                // Filter applied green dot: 6 × 6 at top-right
                if (_filtersApplied)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF05644F),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFiltersRow() {
    final chips = [
      (_supportsDistance ? 'Within $_selectedDistance ⌄' : 'Distance ⌄', 104.0),
      ('Open now', 85.0),
      ('Indoor', 66.0),
      ('Price ⌄', 72.0),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, width) = chips[index];
          return Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _filtersOpen = true;
                  _searchOpen = false;
                  _layersOpen = false;
                });
              },
              child: Container(
                width: width,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE3EBE6),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 17 / 12,
                    color: const Color(0xFF102D28),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // 3. MAP CONTROLS (Location & Layers)
  // ==========================================
  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_sheetState == _SheetSnapState.collapsed) ...[
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => _courtMapController?.zoomIn(),
                  icon: const Icon(Icons.add, color: Color(0xFF05644F)),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => _courtMapController?.zoomOut(),
                  icon: const Icon(Icons.remove, color: Color(0xFF05644F)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Current location button
        GestureDetector(
          key: const Key('find_courts_location_button'),
          onTap: _recenterToUser,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(19, 60, 49, 0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/sprint6/find_courts/current_location.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Layers button
        GestureDetector(
          key: const Key('find_courts_layers_button'),
          onTap: () {
            setState(() {
              _layersOpen = !_layersOpen;
              _searchOpen = false;
              _filtersOpen = false;
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(19, 60, 49, 0.06),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/sprint6/find_courts/layers.svg',
              width: 20,
              height: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. NEARBY COURTS SHEET (3 Snap States)
  // ==========================================
  Widget _buildNearbyCourtsSheet(double screenWidth, double sheetHeight) {
    final isCollapsed = _sheetState == _SheetSnapState.collapsed;

    return Container(
      width: screenWidth,
      height: sheetHeight,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(19, 60, 49, 0.06),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle touch target (353 × 24, visible bar 44 × 4)
          GestureDetector(
            key: const Key('find_courts_sheet_grabber'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              setState(() {
                _sheetDragDelta -= details.delta.dy;
              });
            },
            onVerticalDragEnd: (details) {
              _resolveSheetSnap();
            },
            onTap: () {
              if (isCollapsed) {
                setState(() => _sheetState = _SheetSnapState.halfExpanded);
              }
            },
            child: SizedBox(
              width: double.infinity,
              height: 24,
              child: Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEDA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Header row (353 × 20)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Courts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 19 / 14,
                  color: const Color(0xFF102D28),
                ),
              ),
              Semantics(
                button: true,
                label: 'Refresh courts',
                child: GestureDetector(
                  key: const Key('refresh_courts'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.invalidate(nearbyCourtsProvider),
                  child: const SizedBox.square(
                    dimension: 20,
                    child: Icon(Icons.refresh, size: 18),
                  ),
                ),
              ),

              if (isCollapsed)
                Text(
                  '${_courts.length} ${_courts.length == 1 ? 'facility' : 'facilities'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 15 / 11,
                    color: const Color(0xFF647976),
                  ),
                )
              else
                // Collapse control: 44 × 44, radius 14, subtle bg #F0F4F1
                GestureDetector(
                  key: const Key('find_courts_collapse_sheet'),
                  onTap: () {
                    setState(() {
                      _sheetState = _SheetSnapState.collapsed;
                      _sheetDragDelta = 0;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/sprint6/find_courts/chevron_down.svg',
                      width: 18,
                      height: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Sheet Content
          Expanded(
            child: isCollapsed
                ? _buildCollapsedSummary()
                : _buildExpandedCourtList(),
          ),
        ],
      ),
    );
  }

  void _resolveSheetSnap() {
    setState(() {
      final effective = switch (_sheetState) {
        _SheetSnapState.collapsed => 120.0 + _sheetDragDelta,
        _SheetSnapState.halfExpanded => 296.0 + _sheetDragDelta,
        _SheetSnapState.expanded => 472.0 + _sheetDragDelta,
      };
      _sheetDragDelta = 0;

      if (effective < 200) {
        _sheetState = _SheetSnapState.collapsed;
      } else if (effective < 380) {
        _sheetState = _SheetSnapState.halfExpanded;
      } else {
        _sheetState = _SheetSnapState.expanded;
      }
    });
  }

  Widget _buildCollapsedSummary() {
    final state = ref.watch(nearbyCourtsProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError) {
      return TextButton(
        onPressed: () => ref.invalidate(nearbyCourtsProvider),
        child: const Text('Could not load facilities. Retry'),
      );
    }
    final court = _currentCourt;
    if (court == null) {
      if (_allCourts.isEmpty && _query.isEmpty && !_filtersApplied) {
        return Center(
          child: TextButton(
            onPressed: () => ref.invalidate(nearbyCourtsProvider),
            child: const Text('No facilities yet. Refresh'),
          ),
        );
      }
      return Center(
        child: TextButton(
          onPressed: () => setState(() {
            _query = '';
            _filtersApplied = false;
          }),
          child: const Text('No matching facilities. Clear filters'),
        ),
      );
    }
    return GestureDetector(
      key: const Key('find_courts_sheet_summary'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _sheetState = _SheetSnapState.halfExpanded);
      },
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            // Photo: 44 × 44, radius 12
            _buildCroppedPhoto(44, 44, 12, court),
            const SizedBox(width: 10),

            // Text column
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 18 / 13,
                      color: const Color(0xFF102D28),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '★',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 18 / 13,
                          color: const Color(0xFFF6B42E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${court.ratingText} · ${court.distanceText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 15 / 11,
                            color: const Color(0xFF647976),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Open now badge (66 × 20, radius 10)
            Container(
              width: 66,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFDFF2E8),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                court.availabilityText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 14 / 10,
                  color: const Color(0xFF05644F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCourtList() {
    if (_courts.isEmpty) return _buildCollapsedSummary();
    final courts = _courts;

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: courts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCourtCard(courts[index]);
      },
    );
  }

  Widget _buildCourtCard(CourtLocation court) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCourt = court;
          _selection = true;
        });
        _courtMapController?.moveToCourt(court);
        _openCourtPreview();
      },
      child: Container(
        width: double.infinity,
        height: 102,
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(19, 60, 49, 0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo: 92 × 94, radius 12
            _buildCroppedPhoto(92, 94, 12, court),
            const SizedBox(width: 12),

            // Summary Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  // Name and Favorite Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          court.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 18 / 13,
                            color: const Color(0xFF102D28),
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/sprint6/find_courts/heart_outline.svg',
                        width: 18,
                        height: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Rating and Distance
                  Row(
                    children: [
                      Text(
                        '★',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 19 / 14,
                          color: const Color(0xFFF6B42E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${court.ratingText} · ${court.distanceText}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            height: 15 / 11,
                            color: const Color(0xFF647976),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Address
                  Text(
                    court.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      height: 15 / 11,
                      color: const Color(0xFF647976),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Status badge and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 71,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF2E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          court.availabilityText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                            color: const Color(0xFF05644F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          court.priceSummary ?? 'Chưa có giá',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 17 / 12,
                            color: const Color(0xFF05644F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Photo cropped matching Figma transform: [[1, 0, 0], [0, 0.68, 0.22]]
  Widget _buildCroppedPhoto(
    double width,
    double height,
    double radius,
    CourtLocation court,
  ) {
    final path = court.photos.isEmpty ? null : court.photos.first;
    final placeholder = Container(
      color: const Color(0xFFEAF4EE),
      child: const Center(
        child: Icon(Icons.sports_tennis, color: Color(0xFF05644F)),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: path == null
            ? placeholder
            : path.startsWith('https://') || path.startsWith('http://')
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  // ==========================================
  // 6. SEARCH PANEL
  // ==========================================
  Widget _buildSearchPanel() {
    return Container(
      width: 353,
      height: 274,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(19, 60, 49, 0.12),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Search courts" & Close control (32 × 32, #F0F4F1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search courts',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 22 / 16,
                  color: const Color(0xFF102D28),
                ),
              ),
              _buildCloseButton(() {
                setState(() => _searchOpen = false);
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Sample query row (321 × 44, radius 14, #F0F4F1)
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/sprint6/find_courts/search.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF05644F),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Tên sân hoặc khu vực',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Helper text
          Text(
            'Court name or area',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 17 / 12,
              color: const Color(0xFF647976),
            ),
          ),
          const SizedBox(height: 8),

          // Sample Result Court Card (321 × 102)
          _courts.isEmpty
              ? const Text('Không tìm thấy sân.')
              : _buildCourtCard(_courts.first),
        ],
      ),
    );
  }

  // ==========================================
  // 7. FILTERS PANEL
  // ==========================================
  Widget _buildFiltersPanel() {
    return Container(
      width: 353,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(19, 60, 49, 0.12),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: "Filters" & Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 22 / 16,
                  color: const Color(0xFF102D28),
                ),
              ),
              _buildCloseButton(() {
                setState(() => _filtersOpen = false);
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Distance Group
          Text(
            _supportsDistance ? 'Distance' : 'Distance · Chưa có dữ liệu',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
              color: const Color(0xFF102D28),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: ['3 km', '5 km', '10 km'].map((dist) {
              final isSelected = _selectedDistance == dist;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: !_supportsDistance
                        ? null
                        : () => setState(() {
                            _selectedDistance = dist;
                            _distanceChosen = true;
                          }),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF05644F)
                            : const Color(0xFFF3F6F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dist,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 18 / 13,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF142824),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Availability Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Availability',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                  color: const Color(0xFF102D28),
                ),
              ),
              _buildChoicePill(
                label: 'Open now',
                width: 104,
                selected: _openNowSelected,
                onTap: () =>
                    setState(() => _openNowSelected = !_openNowSelected),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Court Type Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Court type',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                  color: const Color(0xFF102D28),
                ),
              ),
              _buildChoicePill(
                label: 'Indoor',
                width: 104,
                selected: _indoorSelected,
                onTap: () => setState(() => _indoorSelected = !_indoorSelected),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                  color: const Color(0xFF102D28),
                ),
              ),
              Row(
                children: [
                  _buildChoicePill(
                    label: '\$',
                    width: 71,
                    selected: _price1Selected,
                    onTap: () =>
                        setState(() => _price1Selected = !_price1Selected),
                  ),
                  const SizedBox(width: 8),
                  _buildChoicePill(
                    label: r'$$',
                    width: 71,
                    selected: _price2Selected,
                    onTap: () =>
                        setState(() => _price2Selected = !_price2Selected),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              r'$ ≤ 100,000 VND/hour · $$ > 100,000 VND/hour',
              style: TextStyle(fontSize: 11, color: Color(0xFF64716D)),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _query = '';
              _filtersApplied = false;
              _distanceChosen = false;
              _selectedDistance = '5 km';
              _openNowSelected = false;
              _indoorSelected = false;
              _price1Selected = false;
              _price2Selected = false;
              _previewCourt = null;
            }),
            child: const Text('Reset filters'),
          ),
          const SizedBox(height: 16),

          // Apply Filters Button (321 × 44, radius 26, #05644F)
          GestureDetector(
            key: const Key('find_courts_apply_filters'),
            onTap: () {
              setState(() {
                _filtersOpen = false;
                _filtersApplied = true;
                _selection = false;
                if (!_courts.any((court) => court.id == _previewCourt?.id)) {
                  _previewCourt = null;
                  _previewExpanded = false;
                }
              });
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF05644F),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Apply filters',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/sprint6/find_courts/button_arrow.svg',
                    width: 20,
                    height: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicePill({
    required String label,
    required double width,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: _supports(label) ? 1 : .45,
      child: Semantics(
        enabled: _supports(label),
        label: _supports(label) ? label : '$label · Chưa có dữ liệu',
        child: GestureDetector(
          onTap: _supports(label) ? onTap : null,
          child: Container(
            width: width,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF05644F)
                  : const Color(0xFFF3F6F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 18 / 13,
                color: selected ? Colors.white : const Color(0xFF142824),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 8. LAYERS PANEL
  // ==========================================
  Widget _buildLayersPanel() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(19, 60, 49, 0.12),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Map layers',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 19 / 14,
              color: const Color(0xFF102D28),
            ),
          ),
          const SizedBox(height: 8),

          // Standard layer row
          _buildLayerOptionRow(
            label: 'Standard',
            isActive: _activeLayer == 'standard',
            onTap: () {
              setState(() {
                _activeLayer = 'standard';
                _pins = true;
                _cluster = false;
                _layersOpen = false;
              });
            },
          ),

          // Court clusters layer row
          _buildLayerOptionRow(
            label: 'Court clusters',
            isActive: _activeLayer == 'cluster',
            onTap: () {
              setState(() {
                _activeLayer = 'cluster';
                _pins = true;
                _cluster = true;
                _selection = false;
                _layersOpen = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLayerOptionRow({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 17 / 12,
                color: const Color(0xFF102D28),
              ),
            ),
            if (isActive)
              const Icon(Icons.check, size: 18, color: Color(0xFF05644F)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPERS
  // ==========================================
  Widget _buildCloseButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, size: 16, color: Color(0xFF05644F)),
      ),
    );
  }
}
