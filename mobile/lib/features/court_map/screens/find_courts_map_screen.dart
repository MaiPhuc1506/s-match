import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/navigation/player_bottom_navigation.dart';

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
class FindCourtsMapScreen extends StatefulWidget {
  final VoidCallback? onFindPlayers;
  final VoidCallback? onCourtPreview;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateProfile;
  final VoidCallback? onNavigateMatch;
  final VoidCallback? onNavigateFeedback;

  const FindCourtsMapScreen({
    super.key,
    this.onFindPlayers,
    this.onCourtPreview,
    this.onNavigateHome,
    this.onNavigateProfile,
    this.onNavigateMatch,
    this.onNavigateFeedback,
  });

  @override
  State<FindCourtsMapScreen> createState() => _FindCourtsMapScreenState();
}

enum _SheetSnapState { collapsed, halfExpanded, expanded }

class _FindCourtsMapScreenState extends State<FindCourtsMapScreen>
    with SingleTickerProviderStateMixin {
  // --- UI States (Initial prototype values from Figma collection) ---
  bool _selection = true; // Sky Badminton bubble selected by default
  bool _searchOpen = false;
  bool _filtersOpen = false;
  bool _layersOpen = false;
  bool _cluster = false;
  bool _pins = true;
  final bool _accuracy = true;
  bool _filtersApplied = false;

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

  // Map canvas offset (canvas size 500 × 900)
  Offset _mapOffset = Offset.zero;
  late final AnimationController _recenterController;
  late Animation<Offset> _recenterAnimation;

  @override
  void initState() {
    super.initState();
    _recenterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _recenterController.dispose();
    super.dispose();
  }

  void _openCourtPreview() {
    if (widget.onCourtPreview != null) {
      widget.onCourtPreview!();
    } else {
      Navigator.of(context).push(
        explorationRoute<void>(const CourtPreviewScreen(), '/court-preview'),
      );
    }
  }

  void _openPlayers() {
    if (widget.onFindPlayers != null) {
      widget.onFindPlayers!();
    } else {
      Navigator.of(context).push(
        explorationRoute<void>(const FindPlayersMapScreen(), '/find-players'),
      );
    }
  }

  void _dismissOverlays() {
    if (_selection || _searchOpen || _filtersOpen || _layersOpen) {
      setState(() {
        _selection = false;
        _searchOpen = false;
        _filtersOpen = false;
        _layersOpen = false;
      });
    }
  }

  void _recenterToUser() {
    // Recenter target: canvas (0, 46), 0.40s ease-out scroll
    final target = const Offset(0, -46);
    _recenterAnimation =
        Tween<Offset>(begin: _mapOffset, end: target).animate(
          CurvedAnimation(parent: _recenterController, curve: Curves.easeOut),
        )..addListener(() {
          setState(() => _mapOffset = _recenterAnimation.value);
        });

    setState(() {
      _selection = false;
      _searchOpen = false;
      _filtersOpen = false;
      _layersOpen = false;
    });

    _recenterController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

              // LAYER 2: FLOATING HEADER (Segmented control, Search, Quick filters)
              Positioned(
                left: 0,
                top: 0,
                width: screenWidth,
                child: _buildFloatingHeader(screenWidth),
              ),

              // LAYER 3A: MAP CONTROLS (Location & Layers buttons)
              if (_sheetState != _SheetSnapState.expanded)
                Positioned(
                  right: 16,
                  bottom: navHeight + sheetHeight + 16,
                  child: _buildMapControls(),
                ),

              // LAYER 3B: NEARBY COURTS BOTTOM SHEET
              Positioned(
                left: 0,
                right: 0,
                bottom: navHeight,
                height: sheetHeight,
                child: _buildNearbyCourtsSheet(screenWidth, sheetHeight),
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
              if (_searchOpen)
                Positioned(
                  left: (screenWidth - 353) / 2,
                  top: 220,
                  width: 353,
                  child: _buildSearchPanel(),
                ),

              if (_filtersOpen)
                Positioned(
                  left: (screenWidth - 353) / 2,
                  top: 220,
                  width: 353,
                  child: _buildFiltersPanel(),
                ),

              if (_layersOpen)
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
  // 1. MAP VIEWPORT & SCHEMATIC CANVAS
  // ==========================================
  Widget _buildMapViewport(double viewportWidth, double viewportHeight) {
    const canvasWidth = 500.0;
    const canvasHeight = 900.0;

    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            final newDx = (_mapOffset.dx + details.delta.dx).clamp(
              -(canvasWidth - viewportWidth),
              20.0,
            );
            final newDy = (_mapOffset.dy + details.delta.dy).clamp(
              -(canvasHeight - viewportHeight),
              20.0,
            );
            _mapOffset = Offset(newDx, newDy);
          });
        },
        onTap: _dismissOverlays,
        child: SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _mapOffset.dx,
                top: _mapOffset.dy,
                width: canvasWidth,
                height: canvasHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Base Schematic Map SVG
                    SvgPicture.asset(
                      'assets/sprint6/find_courts/map_base.svg',
                      width: canvasWidth,
                      height: canvasHeight,
                      fit: BoxFit.fill,
                    ),

                    // User Location Group (152, 386), size 88 × 88
                    if (_accuracy)
                      Positioned(
                        left: 152,
                        top: 386,
                        width: 88,
                        height: 88,
                        child: _buildUserLocation(),
                      ),

                    // Pins (visible when _pins is true)
                    if (_pins) ...[
                      // VNB Court Marker: (96, 280), 26 × 30
                      Positioned(
                        left: 96,
                        top: 280,
                        width: 26,
                        height: 30,
                        child: GestureDetector(
                          onTap: _openCourtPreview,
                          child: SvgPicture.asset(
                            'assets/sprint6/find_courts/court_pin.svg',
                            width: 26,
                            height: 30,
                          ),
                        ),
                      ),

                      // Sky Badminton Marker: (255, 400), 26 × 30
                      Positioned(
                        left: 255,
                        top: 400,
                        width: 26,
                        height: 30,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selection = true;
                              _searchOpen = false;
                              _filtersOpen = false;
                              _layersOpen = false;
                            });
                          },
                          child: SvgPicture.asset(
                            'assets/sprint6/find_courts/court_pin.svg',
                            width: 26,
                            height: 30,
                          ),
                        ),
                      ),

                      // Duy Tân Sport Center Marker: (100, 548), 26 × 30
                      Positioned(
                        left: 100,
                        top: 548,
                        width: 26,
                        height: 30,
                        child: GestureDetector(
                          onTap: _openCourtPreview,
                          child: SvgPicture.asset(
                            'assets/sprint6/find_courts/court_pin.svg',
                            width: 26,
                            height: 30,
                          ),
                        ),
                      ),
                    ],

                    // Selected Sky Badminton Bubble: (207, 300), 156 × 52
                    if (_selection && _pins)
                      Positioned(
                        left: 207,
                        top: 300,
                        width: 156,
                        height: 52,
                        child: _buildSelectedSkyBubble(),
                      ),

                    // Cluster Group: (168, 392), 56 × 56
                    if (_cluster)
                      Positioned(
                        left: 168,
                        top: 392,
                        width: 56,
                        height: 56,
                        child: _buildClusterBadge(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Accuracy circle: 88 × 88, #2996F5 at 15% opacity
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

  Widget _buildSelectedSkyBubble() {
    return GestureDetector(
      onTap: _openCourtPreview,
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
            SizedBox(
              width: 96,
              height: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sky Badminton',
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
                    '1.3 km · \$',
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

  Widget _buildClusterBadge() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _cluster = false;
          _pins = true;
          _selection = false;
          _layersOpen = false;
          _activeLayer = 'standard';
        });
      },
      child: Stack(
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
              '3',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 21 / 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
      ('Within 5 km ⌄', 104.0),
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
      children: [
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
              if (isCollapsed)
                Text(
                  '3 courts',
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
            _buildCroppedPhoto(44, 44, 12),
            const SizedBox(width: 10),

            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sky Badminton',
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
                          '4.6 (128) · 1.3 km',
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
                'Open now',
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
    final courts = ['Sky Badminton', 'VNB Court', 'Duy Tân Sport Center'];

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: courts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCourtCard(courts[index]);
      },
    );
  }

  Widget _buildCourtCard(String courtName) {
    return GestureDetector(
      onTap: _openCourtPreview,
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
            _buildCroppedPhoto(92, 94, 12),
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
                          courtName,
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
                          '4.6 (128)   1.3 km',
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
                    'Hải Châu, Đà Nẵng',
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
                          'Open now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                            color: const Color(0xFF05644F),
                          ),
                        ),
                      ),
                      Text(
                        '\$\$',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 17 / 12,
                          color: const Color(0xFF05644F),
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
  Widget _buildCroppedPhoto(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        image: const DecorationImage(
          image: AssetImage('assets/images/match/facility_court.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment(
            0,
            0.12,
          ), // Center of 0.22 -> 0.90 vertical slice
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
                Text(
                  'Sky Badminton',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 19 / 14,
                    color: const Color(0xFF102D28),
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
          _buildCourtCard('Sky Badminton'),
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
            'Distance',
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
                    onTap: () => setState(() => _selectedDistance = dist),
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
                    label: '\$\$',
                    width: 71,
                    selected: _price2Selected,
                    onTap: () =>
                        setState(() => _price2Selected = !_price2Selected),
                  ),
                ],
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF05644F) : const Color(0xFFF3F6F3),
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
                _pins = false;
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
