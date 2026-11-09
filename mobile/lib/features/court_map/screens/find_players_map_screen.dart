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
import '../../recommendation/screens/recommended_player_detail_screen.dart';

class FindPlayersMapScreen extends StatelessWidget {
  const FindPlayersMapScreen({
    super.key,
    this.onFindCourts,
    this.onPlayerDetail,
  });
  final VoidCallback? onFindCourts;
  final ValueChanged<NearbyPlayer>? onPlayerDetail;
  @override
  Widget build(BuildContext context) => FindCourtsMapScreen(
    startWithPlayers: true,
    onSwitchToCourts: onFindCourts,
    onPlayerDetail: onPlayerDetail,
  );
}

final playerFavoritesProvider = StateProvider<Set<String>>((ref) => {});

class PlayerDiscoveryOverlay extends ConsumerStatefulWidget {
  const PlayerDiscoveryOverlay({
    super.key,
    required this.onFindCourts,
    required this.onRecenter,
    required this.onVisiblePlayersChanged,
    this.onPlayerDetail,
  });
  final VoidCallback onFindCourts;
  final VoidCallback onRecenter;
  final ValueChanged<List<NearbyPlayer>> onVisiblePlayersChanged;
  final ValueChanged<NearbyPlayer>? onPlayerDetail;
  @override
  ConsumerState<PlayerDiscoveryOverlay> createState() =>
      PlayerDiscoveryOverlayState();
}

class PlayerDiscoveryOverlayState
    extends ConsumerState<PlayerDiscoveryOverlay> {
  String? _published;
  bool get _supportsAvailability =>
      ref
          .read(nearbyPlayersProvider)
          .asData
          ?.value
          .any((p) => p.availableNow != null) ??
      false;
  void showPlayerPreview(NearbyPlayer p) {
    setState(() => _selected = p.id);
    _detail(p);
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
    _sheet.dispose();
    _search.dispose();
    super.dispose();
  }

  void _courts() => widget.onFindCourts();
  void _recenter() => widget.onRecenter();

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
    // Reuse the public, read-only player detail; never open the signed-in user's editor.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
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
                  '~${p.distance} km · ${p.availabilityText}',
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
                  p.demo
                      ? 'Demo profile · Approximate location only'
                      : 'Public profile · Exact location is private',
                  style: exploreText(11, color: exploreMuted),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      explorationRoute<void>(
                        RecommendedPlayerDetailScreen(
                          player: RecommendedPlayer(
                            id: p.id,
                            score: null,
                            name: p.name,
                            level: p.level,
                            distanceKm: p.distance,
                            avatarAsset: p.avatar.isEmpty ? null : p.avatar,
                            location: p.playingArea?.name,
                            mode: p.mode.isEmpty ? null : p.mode,
                            playStyle: p.style.isEmpty ? null : p.style,
                            availability: p.availabilityText,
                            bio: p.demo
                                ? 'Demo discovery profile · Approximate playing area only.'
                                : null,
                          ),
                        ),
                        '/discovered-player',
                      ),
                    );
                  },
                  child: const Text('View profile'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<NearbyPlayer> _filtered(List<NearbyPlayer> players) => players
      .where(
        (p) =>
            p.distance <= _distance &&
            (!_available || p.availableNow == true) &&
            (_level == 'All levels' || p.level == _level) &&
            (_style == 'All styles' || p.style == _style) &&
            ('${p.name} ${p.level} ${p.playingArea?.name ?? ''}'
                .toLowerCase()
                .contains(_query)),
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
                  subtitle: !_supportsAvailability
                      ? const Text(
                          'Availability is not shared by these players.',
                        )
                      : null,
                  onChanged: _supportsAvailability
                      ? (v) => update(() => available = v)
                      : null,
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
                          onSelected:
                              s == 'All styles' ||
                                  (ref
                                          .read(nearbyPlayersProvider)
                                          .asData
                                          ?.value
                                          .any((p) => p.style.isNotEmpty) ??
                                      false)
                              ? (_) => update(() => style = s)
                              : null,
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
    return LayoutBuilder(
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
        final signature = visible
            .map(
              (p) =>
                  '${p.id}:${p.playingArea?.latitude}:${p.playingArea?.longitude}',
            )
            .join('|');
        if (_published != signature) {
          _published = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onVisiblePlayersChanged(visible);
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top,
              child: const ColoredBox(color: Color(0xFFFAFBF9)),
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
                              ? 'Location access denied. Enable location access to find nearby players.'
                              : error is ExplorationAccountAccessDenied
                              ? 'This account cannot access Player discovery.'
                              : error is ExplorationSignInRequired
                              ? 'Sign in as Player to discover nearby players.'
                              : error is ExplorationLocationRequired
                              ? 'Your account has no saved discovery location. Nearby players cannot be loaded yet.'
                              : 'Could not load nearby players.',
                          onRetry: () => ref.invalidate(nearbyPlayersProvider),
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
                        Text(
                          'Players from S-Match · Private coordinates are not shown',
                          style: exploreText(11, color: exploreMuted),
                        ),
                        if (visible.isNotEmpty &&
                            visible.every((p) => !p.hasPublicLocation))
                          Text(
                            'These players have not shared public map locations. Browse their cards or find matching players.',
                            style: exploreText(11, color: exploreMuted),
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
                                'Players are loaded from S-Match. Map markers require a shared public playing area; private GPS coordinates are not displayed.',
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
          ],
        );
      },
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
              _chip(
                'Available now',
                108,
                _supportsAvailability
                    ? () {
                        setState(() => _available = !_available);
                      }
                    : null,
                selected: _available,
              ),
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
    VoidCallback? tap, {
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

  Widget _avatar(NearbyPlayer p, double size) => p.avatar.isEmpty
      ? CircleAvatar(
          radius: size / 2,
          backgroundColor: exploreLight,
          child: const Icon(Icons.person_outline, color: exploreGreen),
        )
      : ClipOval(
          child: Image.asset(
            p.avatar,
            width: size,
            height: size,
            fit: BoxFit.cover,
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
                            '${p.distance} km · ${p.availabilityText}',
                            maxLines: 1,
                            style: exploreText(
                              10,
                              color: exploreMuted,
                              line: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (p.mode.isNotEmpty)
                          ExploreBadge(p.mode, fontSize: 11),
                        const SizedBox(width: 5),
                        if (p.style.isNotEmpty)
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
}
