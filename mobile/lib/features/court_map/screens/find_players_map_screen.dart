import '../../../core/theme/app_motion.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../navigation/player_bottom_navigation.dart';
import '../exploration_data.dart';
import '../widgets/exploration_widgets.dart';
import 'find_courts_map_screen.dart';
import '../../recommendation/models/recommended_player.dart';
import '../../recommendation/screens/recommendation_list_screen.dart';

final playerFavoritesProvider = StateProvider<Set<String>>((ref) => {});

class FindPlayersMapScreen extends ConsumerStatefulWidget {
  const FindPlayersMapScreen({
    super.key,
    this.onFindCourts,
    this.onPlayerDetail,
  });
  final VoidCallback? onFindCourts;
  final ValueChanged<NearbyPlayer>? onPlayerDetail;
  @override
  ConsumerState<FindPlayersMapScreen> createState() =>
      _FindPlayersMapScreenState();
}

class _FindPlayersMapScreenState extends ConsumerState<FindPlayersMapScreen>
    with SingleTickerProviderStateMixin {
  late final TransformationController _map;
  late final AnimationController _recenterController;
  Matrix4Tween? _recenterTween;
  @override
  void initState() {
    super.initState();
    _map = TransformationController(ref.read(playerMapCameraProvider).clone());
    _recenterController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          final tween = _recenterTween;
          if (tween != null) {
            _map.value = tween.transform(
              Curves.easeOut.transform(_recenterController.value),
            );
          }
        });
  }

  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '', _level = 'All levels', _style = 'All styles';
  double _distance = 5;
  bool _available = false;
  String? _selected;
  @override
  void dispose() {
    _debounce?.cancel();
    _recenterController.dispose();
    _map.dispose();
    _sheet.dispose();
    _search.dispose();
    super.dispose();
  }

  void _courts() {
    if (widget.onFindCourts != null) {
      widget.onFindCourts!();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    PlayerBottomNavigation.navigateTo(
      context,
      const FindCourtsMapScreen(),
      routeName: '/player-map',
    );
  }

  void _recenter() {
    if (AppMotion.reduced(context)) {
      _recenterController.stop();
      _map.value = Matrix4.identity();
      ref.read(playerMapCameraProvider.notifier).state = Matrix4.identity();
      return;
    }
    // Only the schematic camera is animated; no precise GPS data is used.
    HapticFeedback.selectionClick();
    _recenterTween = Matrix4Tween(
      begin: _map.value.clone(),
      end: Matrix4.identity(),
    );
    ref.read(playerMapCameraProvider.notifier).state = Matrix4.identity();
    _recenterController.forward(from: 0);
  }

  void _favorite(NearbyPlayer p) {
    HapticFeedback.selectionClick();
    final favorites = {...ref.read(playerFavoritesProvider)};
    if (!favorites.remove(p.id)) favorites.add(p.id);
    ref.read(playerFavoritesProvider.notifier).state = favorites;
  }

  void _detail(NearbyPlayer p) {
    if (widget.onPlayerDetail != null) {
      widget.onPlayerDetail!(p);
      return;
    }
    // No public Player Detail route exists yet; expose only the supplied demo data.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Player preview',
                style: exploreText(18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _avatar(p, 72),
              const SizedBox(height: 12),
              Text(p.name, style: exploreText(20, weight: FontWeight.w600)),
              Text(p.level, style: exploreText(14, color: exploreMuted)),
              const SizedBox(height: 8),
              Text(
                '~${p.distance} km · Available now',
                style: exploreText(12, color: exploreMuted),
              ),
              const SizedBox(height: 8),
              if (p.mode.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    ExploreBadge(p.mode, fontSize: 11),
                    ExploreBadge(
                      p.style,
                      fontSize: 11,
                      neutral: p.style == 'Balanced',
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Demo profile · Approximate location only',
                style: exploreText(11, color: exploreMuted),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<NearbyPlayer> _filtered(List<NearbyPlayer> players) => players
      .where(
        (p) =>
            p.distance <= _distance &&
            (_level == 'All levels' || p.level == _level) &&
            (_style == 'All styles' || p.style == _style) &&
            ('${p.name} ${p.level} Đà Nẵng'.toLowerCase().contains(_query)),
      )
      .toList();

  void _filters() {
    var level = _level, style = _style;
    var distance = _distance;
    var available = _available;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player filters',
                  style: exploreText(18, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text('Distance', style: exploreText(13)),
                Wrap(
                  spacing: 8,
                  children: [3.0, 5.0, 10.0]
                      .map(
                        (d) => ChoiceChip(
                          label: Text('${d.toInt()} km'),
                          selected: distance == d,
                          onSelected: (_) => update(() => distance = d),
                        ),
                      )
                      .toList(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: exploreGreen,
                  title: Text('Available now', style: exploreText(13)),
                  value: available,
                  onChanged: (v) => update(() => available = v),
                ),
                Text('Level', style: exploreText(13)),
                Wrap(
                  spacing: 8,
                  children:
                      ['All levels', 'Beginner', 'Intermediate', 'Advanced']
                          .map(
                            (s) => ChoiceChip(
                              label: Text(s),
                              selected: level == s,
                              onSelected: (_) => update(() => level = s),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                Text('Playing style', style: exploreText(13)),
                Wrap(
                  spacing: 8,
                  children: ['All styles', 'Balanced', 'Offensive', 'Defensive']
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: style == s,
                          onSelected: (_) => update(() => style = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: exploreGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _level = level;
                        _style = style;
                        _distance = distance;
                        _available = available;
                        _selected = null;
                      });
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(nearbyPlayersProvider);
    final top = math.max(52.0, MediaQuery.paddingOf(context).top);
    final nav = PlayerBottomNavigation.heightFor(context);
    return Scaffold(
      backgroundColor: exploreBackground,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (_, c) {
          final header = top + 226;
          final mapHeight = math.max(120.0, c.maxHeight - header - nav);
          final collapsedHeight = math.min(194.0, mapHeight * .65);
          final expandedHeight = math.min(352.0, mapHeight - 16);
          final minSize = collapsedHeight / mapHeight;
          final maxSize = math.max(minSize, expandedHeight / mapHeight);
          final halfSize = (minSize + maxSize) / 2;
          final players = data.asData?.value ?? const <NearbyPlayer>[];
          final visible = _filtered(players);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: header,
                left: 0,
                right: 0,
                bottom: nav,
                child: ClipRect(
                  child: InteractiveViewer(
                    key: const Key('players_map'),
                    transformationController: _map,
                    onInteractionEnd: (_) {
                      ref.read(playerMapCameraProvider.notifier).state = _map
                          .value
                          .clone();
                    },
                    minScale: 1,
                    maxScale: 3,
                    boundaryMargin: const EdgeInsets.all(80),
                    constrained: false,
                    child: SizedBox(
                      width: c.maxWidth,
                      height: math.max(490.0, mapHeight),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: SvgPicture.asset(
                              '${explorationAssets}schematic_map.svg',
                              fit: BoxFit.fill,
                            ),
                          ),
                          Positioned(
                            left: 163 * c.maxWidth / 393,
                            top: 100,
                            child: _location(),
                          ),
                          for (final point in [
                            const Offset(75, 125),
                            const Offset(297, 136),
                            const Offset(103, 248),
                            const Offset(165, 244),
                          ])
                            Positioned(
                              left: point.dx * c.maxWidth / 393,
                              top: point.dy,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: exploreGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          for (final p in visible)
                            Positioned(
                              left: p.marker.dx * c.maxWidth / 393,
                              top: p.marker.dy,
                              child: Semantics(
                                label:
                                    '${p.level}, approximate distance ${p.distance} km',
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selected = p.id);
                                  },
                                  onDoubleTap: () => _detail(p),
                                  child: AnimatedScale(
                                    scale: !AppMotion.reduced(context) && _selected == p.id ? 1.04 : 1,
                                    duration: AppMotion.duration(context, 180),
                                    child: _bubble(p),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.only(top: top),
                  child: _header(),
                ),
              ),
              Positioned(
                top: header,
                left: 0,
                right: 0,
                bottom: nav,
                child: DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: minSize,
                  minChildSize: minSize,
                  maxChildSize: maxSize,
                  snap: true,
                  snapSizes: [minSize, halfSize, maxSize],
                  builder: (_, scroll) => Container(
                    key: const Key('players_sheet'),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0F133C31),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: data.when(
                      loading: () => ListView(
                        controller: scroll,
                        children: const [
                          SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: exploreGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      error: (error, _) => ListView(
                        controller: scroll,
                        children: [
                          ExploreMessage(
                            message: error is ExplorationPermissionDenied
                                ? 'Location access denied. You can still browse approximate demo locations.'
                                : 'Không tải được người chơi.',
                            onRetry: () =>
                                ref.invalidate(nearbyPlayersProvider),
                          ),
                        ],
                      ),
                      data: (_) => ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD8DEDA),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Nearby Players',
                            style: exploreText(
                              14,
                              weight: FontWeight.w600,
                              line: 19,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (visible.where((p) => p.listed).isEmpty)
                            const ExploreMessage(
                              message: 'No nearby players match your filters.',
                            ),
                          for (final p in visible.where((p) => p.listed)) ...[
                            _row(p),
                            const SizedBox(height: 8),
                          ],
                          if (_selected != null &&
                              visible.any((p) => p.id == _selected))
                            TextButton(
                              onPressed: () => _detail(
                                visible.firstWhere((p) => p.id == _selected),
                              ),
                              child: const Text('View selected player'),
                            ),
                          SizedBox(
                            height: 44,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: exploreGreen,
                              ),
                              onPressed: () async {
                                final searchAgain = await Navigator.of(context)
                                    .push<bool>(
                                      explorationRoute<bool>(
                                        RecommendationListScreen(
                                          query: RecommendationQuery(
                                            distanceKm: _distance,
                                            level: _level,
                                            style: _style,
                                          ),
                                        ),
                                        '/recommendations',
                                      ),
                                    );
                                if (searchAgain == true && mounted) _filters();
                              },
                              child: Text(
                                'Find Matching Players',
                                style: exploreText(
                                  14,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _sheet,
                builder: (_, _) {
                  final activeHeight = _sheet.isAttached
                      ? _sheet.size * mapHeight
                      : collapsedHeight;
                  if (activeHeight >= expandedHeight - 1) {
                    return const Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox.shrink(),
                    );
                  }
                  return Positioned(
                    right: 16,
                    bottom: nav + activeHeight + 12,
                    child: Column(
                      children: [
                        ExploreControl(
                          label: 'Approximate location',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => const SafeArea(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Player locations are approximate demo positions. Precise GPS coordinates are not collected or displayed.',
                                ),
                              ),
                            ),
                          ),
                          child: const ExploreGlyph('navigate'),
                        ),
                        const SizedBox(height: 8),
                        ExploreControl(
                          label: 'Recenter players map',
                          onTap: _recenter,
                          child: SvgPicture.asset(
                            'assets/sprint6/find_courts/current_location.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PlayerBottomNavigation(currentTab: PlayerNavTab.map),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() => Container(
    color: exploreBackground,
    height: 226,
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 66,
          width: double.infinity,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: exploreText(23, weight: FontWeight.w600, line: 32),
                  ),
                  Text(
                    'Discover badminton courts and players\nnear you.',
                    maxLines: 2,
                    style: exploreText(12, line: 17),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: ExploreControl(
                  label: 'Recenter',
                  background: exploreLight,
                  elevation: 0,
                  size: 40,
                  onTap: _recenter,
                  child: SvgPicture.asset(
                    'assets/sprint6/find_courts/current_location.svg',
                    width: 20,
                    height: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: exploreLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _courts,
                  child: Center(
                    child: Text(
                      'Find Courts',
                      style: exploreText(12, color: exploreMuted),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: exploreGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Find Players',
                    style: exploreText(
                      12,
                      weight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: exploreText(13),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) {
                        setState(() => _query = value.trim().toLowerCase());
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search player name or area',
                    hintStyle: exploreText(13, color: const Color(0xFF8B9794)),
                    filled: true,
                    fillColor: exploreLight,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(9),
                      child: SvgPicture.asset(
                        'assets/sprint6/find_courts/search.svg',
                        width: 18,
                        height: 18,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ExploreControl(
                label: 'Player filters',
                background: exploreLight,
                elevation: 0,
                size: 36,
                onTap: _filters,
                child: SvgPicture.asset(
                  'assets/sprint6/find_courts/filter.svg',
                  width: 20,
                  height: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip('Within ${_distance.toInt()} km ⌄', 104, _filters),
              _chip('Available now', 108, () {
                setState(() => _available = !_available);
              }, selected: _available),
              _chip(_level == 'All levels' ? 'Level ⌄' : _level, 74, _filters),
              _chip(
                _style == 'All styles' ? 'Playing style ⌄' : _style,
                116,
                _filters,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(
    String label,
    double width,
    VoidCallback tap, {
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: selected ? const Color(0xFFDFF2E8) : exploreLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: exploreText(12, weight: FontWeight.w500),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _avatar(NearbyPlayer p, double size) => ClipOval(
    child: Image.asset(p.avatar, width: size, height: size, fit: BoxFit.cover),
  );
  Widget _bubble(NearbyPlayer p) => Container(
    width: 145,
    height: 50,
    padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: _selected == p.id ? Border.all(color: exploreGreen) : null,
      boxShadow: const [
        BoxShadow(
          color: Color(0x14133C31),
          blurRadius: 6,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        _avatar(p, 44),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.level,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: exploreText(12, weight: FontWeight.w600, line: 17),
              ),
              const SizedBox(height: 3),
              Text('${p.distance} km', style: exploreText(11, line: 15)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(NearbyPlayer p) => InkWell(
    key: ValueKey('player_${p.id}'),
    onTap: () => _detail(p),
    child: SizedBox(
      height: 66,
      child: Row(
        children: [
          _avatar(p, 56),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: exploreText(14, weight: FontWeight.w600, line: 19),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.level,
                      style: exploreText(11, color: exploreMuted, line: 15),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${p.distance} km · Available now',
                            maxLines: 1,
                            style: exploreText(
                              10,
                              color: exploreMuted,
                              line: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        ExploreBadge(p.mode, fontSize: 11),
                        const SizedBox(width: 5),
                        ExploreBadge(
                          p.style,
                          fontSize: 11,
                          neutral: p.style == 'Balanced',
                          offensive: p.style == 'Offensive',
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: -8,
                  right: -6,
                  child: IconButton(
                    tooltip: 'Favorite ${p.name}',
                    onPressed: () => _favorite(p),
                    icon: ref.watch(playerFavoritesProvider).contains(p.id)
                        ? const Icon(
                            Icons.favorite,
                            size: 18,
                            color: exploreGreen,
                          )
                        : SvgPicture.asset(
                            'assets/sprint6/find_courts/heart_outline.svg',
                            width: 18,
                            height: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _location() => SizedBox(
    width: 88,
    height: 88,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0x262996F5),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1689FA),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ],
    ),
  );
}
