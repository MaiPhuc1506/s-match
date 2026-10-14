import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../booking/screens/booking_flow_screen.dart';
import '../exploration_data.dart';
import '../widgets/exploration_widgets.dart';

final courtFavoriteProvider = StateProvider<bool>((ref) => false);

class CourtPreviewScreen extends ConsumerStatefulWidget {
  const CourtPreviewScreen({super.key, this.onViewCourts});
  final VoidCallback? onViewCourts;
  @override
  ConsumerState<CourtPreviewScreen> createState() => _CourtPreviewScreenState();
}

class _CourtPreviewScreenState extends ConsumerState<CourtPreviewScreen> {
  final _gallery = PageController();
  int _image = 0;
  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  void _viewCourts() {
    if (widget.onViewCourts != null) {
      widget.onViewCourts!();
      return;
    }
    // Verified Figma destination 301:637: existing Player booking schedule.
    Navigator.of(context).push(
      explorationRoute<void>(const BookingFlowScreen(), '/player-booking'),
    );
  }

  void _info(String title, String value) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: exploreText(18, weight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(value, style: exploreText(14)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  Future<void> _share(BuildContext anchor, CourtPreviewData court) async {
    final box = anchor.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${court.name}\n${court.address}\n06:00 - 23:00\n80.000 - 120.000 VND / hour',
          subject: court.name,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được chia sẻ. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(courtPreviewProvider);
    return Scaffold(
      backgroundColor: exploreBackground,
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          math.max(24, MediaQuery.paddingOf(context).bottom),
        ),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            key: const Key('view_courts'),
            onPressed: data.hasValue ? _viewCourts : null,
            style: FilledButton.styleFrom(
              backgroundColor: exploreGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ExploreGlyph('calendar'),
                const SizedBox(width: 8),
                Text(
                  'View Courts',
                  style: exploreText(
                    14,
                    weight: FontWeight.w600,
                    color: Colors.white,
                    line: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: data.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: exploreGreen),
          ),
          error: (error, _) => Stack(
            children: [
              ExploreMessage(
                message: 'Không tải được thông tin sân.',
                onRetry: () => ref.invalidate(courtPreviewProvider),
              ),
              Positioned(top: 8, left: 20, child: _back()),
            ],
          ),
          data: (court) => _content(court),
        ),
      ),
    );
  }

  Widget _back() => ExploreControl(
    label: 'Back',
    size: 40,
    onTap: () => Navigator.of(context).maybePop(),
    child: const ExploreGlyph('preview_back'),
  );

  Widget _content(CourtPreviewData court) => SingleChildScrollView(
    key: const PageStorageKey('court_preview_scroll'),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 262,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -262,
                  height: 490,
                  child: SvgPicture.asset(
                    '${explorationAssets}schematic_map.svg',
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(left: 20, top: 8, child: _back()),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 52,
                  height: 222,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: court.photos.isEmpty
                        ? const ExploreMessage(message: 'Chưa có ảnh sân.')
                        : PageView.builder(
                            controller: _gallery,
                            itemCount: court.photos.length,
                            onPageChanged: (value) =>
                                setState(() => _image = value),
                            itemBuilder: (_, index) =>
                                ExplorePhoto(asset: court.photos[index]),
                          ),
                  ),
                ),
                Positioned(
                  top: 66,
                  right: 68,
                  child: ExploreControl(
                    size: 40,
                    label: 'Favorite court',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(courtFavoriteProvider.notifier).state = !ref
                          .read(courtFavoriteProvider);
                    },
                    child: ref.watch(courtFavoriteProvider)
                        ? const Icon(
                            Icons.favorite,
                            size: 20,
                            color: Color(0xFFF25561),
                          )
                        : const ExploreGlyph('preview_heart'),
                  ),
                ),
                Positioned(
                  top: 66,
                  right: 16,
                  child: Builder(
                    builder: (anchor) => ExploreControl(
                      size: 40,
                      label: 'Share court',
                      onTap: () => _share(anchor, court),
                      child: const ExploreGlyph('preview_share'),
                    ),
                  ),
                ),
                if (court.photos.isNotEmpty)
                  Positioned(
                    bottom: 18,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: exploreGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${math.min(_image + 1, court.photos.length)} / ${court.photos.length}',
                        style: exploreText(10, color: Colors.white, line: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.zero,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -9,
                  left: 0,
                  right: 0,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: exploreText(22, weight: FontWeight.w600, line: 30),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '★',
                          style: exploreText(
                            16,
                            color: const Color(0xFFF6B42E),
                            line: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '4.6 (128)',
                          style: exploreText(
                            12,
                            weight: FontWeight.w500,
                            line: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const ExploreGlyph('location', size: 14),
                        const SizedBox(width: 8),
                        Text('1.3 km', style: exploreText(12, line: 17)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const ExploreGlyph('location', size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            court.address,
                            style: exploreText(
                              12,
                              color: exploreMuted,
                              line: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _amenities(),
                    const SizedBox(height: 12),
                    _valueRow(
                      'clock',
                      'Operating Hours',
                      '06:00 - 23:00',
                      onTap: () => _info('Operating Hours', '06:00 - 23:00'),
                      badge: true,
                    ),
                    _valueRow(
                      'price',
                      'Price Range',
                      '80.000 - 120.000 VND / hour',
                      onTap: () => _info(
                        'Price Range',
                        'Court 1 / Court 2: 80.000 VND / hour\nCourt 3: 100.000 VND / hour\nDemo pricing — not a live quote.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Court Information',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: exploreText(
                              14,
                              weight: FontWeight.w600,
                              line: 19,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _showCourts,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              'See all',
                              style: exploreText(
                                12,
                                color: exploreMuted,
                                line: 17,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _courtCard(i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _amenities() => SizedBox(
    height: 56,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children:
          [
                ('indoor', 'Indoor'),
                ('parking', 'Parking'),
                ('shower', 'Shower'),
                ('rest', 'Rest area'),
                ('shop', 'Pro shop'),
              ]
              .map(
                (a) => SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: exploreLight,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(child: ExploreGlyph(a.$1, size: 21)),
                      ),
                      const SizedBox(height: 4),
                      Text(a.$2, maxLines: 1, style: exploreText(9, line: 13)),
                    ],
                  ),
                ),
              )
              .toList(),
    ),
  );

  Widget _valueRow(
    String icon,
    String title,
    String value, {
    required VoidCallback onTap,
    bool badge = false,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDF0ED), width: .5)),
      ),
      child: Row(
        children: [
          ExploreGlyph(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: exploreText(12, weight: FontWeight.w500, line: 17),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: exploreText(12, color: exploreMuted, line: 17),
                      ),
                    ),
                    if (badge) ...[
                      const SizedBox(width: 14),
                      const ExploreBadge('Open now'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const ExploreGlyph('chevron', size: 16),
        ],
      ),
    ),
  );

  Widget _courtCard(int index) => InkWell(
    onTap: _viewCourts,
    child: Container(
      width: 112,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A133C31),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 62, width: 112, child: ExplorePhoto()),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Court ${index + 1}',
                  style: exploreText(12, weight: FontWeight.w600, line: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  index == 2 ? '● Busy' : '● Available',
                  maxLines: 1,
                  style: exploreText(
                    10,
                    line: 14,
                    color: index == 2
                        ? const Color(0xFFF25561)
                        : const Color(0xFF07934F),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  index == 2 ? '100.000 VND' : '80.000 VND',
                  maxLines: 1,
                  style: exploreText(10, line: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  void _showCourts() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Court Information',
              style: exploreText(18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _courtCard(i),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
