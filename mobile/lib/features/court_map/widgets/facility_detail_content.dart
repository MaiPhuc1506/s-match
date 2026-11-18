import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exploration_data.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../../../core/theme/app_motion.dart';
import 'exploration_widgets.dart';
import 'facility_gallery.dart';
import 'facility_services.dart';

/// One live, data-driven detail composition for catalogue and uploaded facilities.
class FacilityDetailContent extends ConsumerStatefulWidget {
  const FacilityDetailContent({
    super.key,
    required this.initial,
    required this.onBook,
    required this.onFavorite,
    required this.favorite,
    required this.onShare,
  });
  final CourtLocation initial;
  final void Function([int? courtId]) onBook;
  final VoidCallback onFavorite, onShare;
  final bool favorite;
  @override
  ConsumerState<FacilityDetailContent> createState() =>
      _FacilityDetailContentState();
}

class _FacilityDetailContentState extends ConsumerState<FacilityDetailContent> {
  int tab = 2;
  CourtLocation get location =>
      ref.read(facilityDetailProvider(widget.initial.id)).valueOrNull ??
      widget.initial;
  bool get illustrative =>
      location.photos.any((p) => p.startsWith('assets/sprint10/courts/'));
  void gallery() {
    final f = location;
    Navigator.of(context).push(
      AppMotion.route<void>(
        FacilityGallery(
          name: f.name,
          photos: f.photos,
          illustrative: illustrative,
          onBook: () => widget.onBook(),
          onServices: () {
            Navigator.of(context).pop();
            setState(() => tab = 2);
          },
        ),
        name: '/facility-images',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(facilityDetailProvider(widget.initial.id));
    final f = async.valueOrNull ?? widget.initial;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F5),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 4, 17, 9),
            child: SizedBox(
              width: double.infinity,
              height: 49,
              child: FilledButton(
                style: facilityPrimaryStyle().copyWith(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                key: const Key('view_courts'),
                onPressed: () => widget.onBook(),
                child: const Text('Select Court & Book'),
              ),
            ),
          ),
          const PlayerBottomNavigation(
            currentTab: PlayerNavTab.home,
            allowCurrentTabNavigation: true,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(facilityDetailProvider(f.id));
            await ref.read(facilityDetailProvider(f.id).future);
          },
          child: CustomScrollView(
            key: const PageStorageKey('court_preview_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: gallery,
                      child: SizedBox(
                        height: 127,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: f.photos.isEmpty
                              ? const ColoredBox(
                                  color: exploreLight,
                                  child: Center(
                                    child: Icon(
                                      CupertinoIcons.photo,
                                      color: exploreMuted,
                                    ),
                                  ),
                                )
                              : FacilityPhoto(f.photos.first),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 10,
                      child: ExploreControl(
                        label: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          color: exploreGreen,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 17,
                      top: 10,
                      child: SizedBox(
                        width: 104,
                        height: 44,
                        child: FilledButton(
                          style: facilityPrimaryStyle().copyWith(
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 12),
                            ),
                            textStyle: WidgetStatePropertyAll(
                              exploreText(
                                12,
                                weight: FontWeight.w600,
                                color: Colors.white,
                                line: 18,
                              ),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          onPressed: () => widget.onBook(),
                          child: const Text('Book Court', maxLines: 1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 8,
                      child: Row(
                        children: [
                          _photoAction(
                            'Favorite',
                            widget.favorite
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            widget.onFavorite,
                          ),
                          const SizedBox(width: 8),
                          _photoAction(
                            'Share',
                            CupertinoIcons.share,
                            widget.onShare,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (async.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CupertinoActivityIndicator(),
                  ),
                ),
              if (async.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Could not refresh facility details.',
                            style: exploreText(12, color: exploreMuted),
                          ),
                        ),
                        CupertinoButton(
                          onPressed: () =>
                              ref.invalidate(facilityDetailProvider(f.id)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(17, 14, 17, 8),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0705644F),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: exploreText(
                          22,
                          weight: FontWeight.w600,
                          color: const Color(0xFF1C1C1C),
                          line: 30,
                        ),
                      ),
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                illustrative
                                    ? 'BADMINTON · CONCEPT IMAGERY'
                                    : 'BADMINTON',
                                style: exploreText(
                                  10,
                                  color: const Color(0xFF6B6B6B),
                                  line: 14,
                                ),
                              ),
                            ),
                            if (illustrative)
                              Container(
                                width: 64,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: FacilityServices.mint,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  'CONCEPT',
                                  style: exploreText(
                                    10,
                                    color: exploreGreen,
                                    line: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE1EBE5),
                      ),
                      const SizedBox(height: 7),
                      _label(
                        'Location',
                        CupertinoIcons.placemark,
                        f.address.isEmpty ? 'Address unavailable' : f.address,
                      ),
                      const SizedBox(height: 4),
                      _label(
                        'Opening hours',
                        CupertinoIcons.clock,
                        '${f.operatingHoursText ?? 'Hours unavailable'} · ${f.courts.length}${f.courts.isNotEmpty && f.courts.every((c) => c['courtType'] == 'INDOOR') ? ' indoor' : ''} courts',
                      ),
                      const SizedBox(height: 3),
                      Text(
                        f.rating == null ? 'No reviews yet' : f.ratingText,
                        style: exploreText(
                          11,
                          color: const Color(0xFF6B6B6B),
                          line: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FacilityTabs(
                  selected: tab,
                  onSelect: (i) {
                    if (i == 3) {
                      gallery();
                    } else {
                      setState(() => tab = i);
                    }
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                sliver: SliverToBoxAdapter(child: _section(f)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoAction(String label, IconData icon, VoidCallback onTap) =>
      Semantics(
        label: label,
        button: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          onPressed: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: exploreGreen),
          ),
        ),
      );

  Widget _label(String label, IconData icon, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, color: exploreGreen, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: exploreText(
                12,
                weight: FontWeight.w500,
                color: const Color(0xFF1C1C1C),
                line: 17,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: exploreText(13, color: const Color(0xFF6B6B6B), line: 18),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _section(CourtLocation f) {
    if (tab == 2) {
      return FacilityServices(
        courts: f.courts,
        services: f.services
            .map(
              (s) => FacilityServiceItem(
                name: s['name'] as String,
                price: s['price'] as num?,
                unit: s['unit'] as String?,
                category: s['category'] as String?,
              ),
            )
            .toList(),
      );
    }
    if (tab == 1) {
      return _empty('Membership', 'No membership plans listed yet.');
    }
    if (tab == 4) {
      return _empty('Facility rules', 'No facility rules have been published.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (f.description?.isNotEmpty == true) ...[
          Text(
            f.description!,
            style: exploreText(13, color: exploreMuted, line: 20),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Court Information',
                style: exploreText(14, weight: FontWeight.w600),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => widget.onBook(),
              child: const Text('See all'),
            ),
          ],
        ),
        if (f.courts.isEmpty) _empty('Courts', 'No courts listed yet.'),
        for (final court in f.courts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                title: Text(
                  court['name']?.toString() ?? 'Court',
                  style: exploreText(13, weight: FontWeight.w600),
                ),
                subtitle: Text(
                  court['courtType']?.toString() ?? 'Type unavailable',
                ),
                trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                onTap: court['id'] is num
                    ? () => widget.onBook((court['id'] as num).toInt())
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(String title, String message) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: exploreText(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(message, style: exploreText(12, color: exploreMuted)),
      ],
    ),
  );
}

class _FacilityTabs extends SliverPersistentHeaderDelegate {
  _FacilityTabs({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  bool shouldRebuild(covariant _FacilityTabs old) => old.selected != selected;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: const Color(0xFFF3F8F5),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (final entry in const [
            'Info',
            'Membership',
            'Services',
            'Images',
            'Rules',
          ].asMap().entries)
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => onSelect(entry.key),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          entry.value,
                          style: exploreText(
                            11.5,
                            weight: selected == entry.key
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: selected == entry.key
                                ? exploreGreen
                                : const Color(0xFF6B6B6B),
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AppMotion.duration(context),
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: selected == entry.key
                            ? exploreGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
