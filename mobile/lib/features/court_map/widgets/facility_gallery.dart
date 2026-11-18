import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../navigation/player_bottom_navigation.dart';
import 'exploration_widgets.dart';

ButtonStyle facilityPrimaryStyle() => FilledButton.styleFrom(
  backgroundColor: exploreGreen,
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
  textStyle: exploreText(13, weight: FontWeight.w600, color: Colors.white),
);

/// Both uploaded remote photos and approved local illustrations share one renderer.
class FacilityPhoto extends StatefulWidget {
  const FacilityPhoto(this.path, {super.key, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;
  @override
  State<FacilityPhoto> createState() => _FacilityPhotoState();
}

class _FacilityPhotoState extends State<FacilityPhoto> {
  int attempt = 0;
  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    Widget failed(BuildContext context, Object error, StackTrace? stack) =>
        ColoredBox(
          color: exploreLight,
          child: Center(
            child: CupertinoButton(
              onPressed: () => setState(() {
                if (path.startsWith('http')) NetworkImage(path).evict();
                attempt++;
              }),
              child: const Text('Image unavailable · Retry'),
            ),
          ),
        );
    Widget frame(BuildContext context, Widget child, int? frame, bool sync) =>
        sync || frame != null
        ? child
        : const ColoredBox(
            color: exploreLight,
            child: Center(child: CupertinoActivityIndicator()),
          );
    return path.startsWith('http')
        ? Image.network(
            path,
            key: ValueKey('$path-$attempt'),
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            frameBuilder: frame,
            errorBuilder: failed,
          )
        : Image.asset(
            path,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            frameBuilder: frame,
            errorBuilder: failed,
          );
  }
}

class FacilityGallery extends StatefulWidget {
  const FacilityGallery({
    super.key,
    required this.name,
    required this.photos,
    required this.onBook,
    required this.onServices,
    this.illustrative = false,
  });
  final String name;
  final List<String> photos;
  final VoidCallback onBook, onServices;
  final bool illustrative;
  @override
  State<FacilityGallery> createState() => _FacilityGalleryState();
}

class _FacilityGalleryState extends State<FacilityGallery> {
  int selected = 0;
  Future<void> open(int index) async {
    final result = await Navigator.of(context).push<int>(
      AppMotion.route<int>(
        _FacilityImageViewer(
          name: widget.name,
          photos: widget.photos,
          initialIndex: index,
          illustrative: widget.illustrative,
        ),
        name: '/facility-images/fullscreen',
      ),
    );
    if (mounted && result != null) setState(() => selected = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8F5),
    appBar: AppBar(
      title: const Text('Images'),
      titleTextStyle: exploreText(16, weight: FontWeight.w600),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: exploreGreen,
          size: 20,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFFF7F8F5),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 8, 17, 9),
          child: SizedBox(
            width: double.infinity,
            height: 49,
            child: FilledButton(
              style: facilityPrimaryStyle(),
              onPressed: widget.onBook,
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
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      children: [
        Text(
          widget.name,
          style: exploreText(22, weight: FontWeight.w600, line: 30),
        ),
        const SizedBox(height: 14),
        if (widget.photos.isEmpty)
          Container(
            height: 230,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: exploreLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('No images yet', style: exploreText(14)),
          )
        else ...[
          CupertinoButton(
            padding: EdgeInsets.zero,
            key: const Key('gallery-hero'),
            onPressed: () => open(selected),
            child: AspectRatio(
              aspectRatio: 345 / 230,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FacilityPhoto(widget.photos[selected]),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _counter(
                        '${selected + 1} / ${widget.photos.length}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${widget.illustrative ? 'Illustrative concept gallery · ' : ''}${widget.photos.length} images',
            style: exploreText(12, color: exploreMuted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 13,
              runSpacing: 14,
              children: [
                for (var i = 0; i < widget.photos.length; i++)
                  SizedBox(
                    width: (constraints.maxWidth - 13) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          key: ValueKey('gallery-thumbnail-$i'),
                          onPressed: () => open(i),
                          child: AspectRatio(
                            aspectRatio: 166 / 110,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FacilityPhoto(widget.photos[i]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          i == 0 ? 'Main court' : 'Interior view',
                          style: exploreText(11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.illustrative)
          Text(
            'Concept images are illustrative and are not verified photographs of a real facility.',
            style: exploreText(12, color: exploreMuted, line: 19),
          ),
        const SizedBox(height: 20),
        CupertinoButton(
          color: exploreLight,
          onPressed: widget.onServices,
          child: Text(
            'View pricing & services',
            style: exploreText(13, color: exploreGreen),
          ),
        ),
      ],
    ),
  );
}

Widget _counter(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: exploreGreen.withValues(alpha: .9),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Text(text, style: exploreText(11, color: Colors.white)),
);

class _FacilityImageViewer extends StatefulWidget {
  const _FacilityImageViewer({
    required this.name,
    required this.photos,
    required this.initialIndex,
    required this.illustrative,
  });
  final String name;
  final List<String> photos;
  final int initialIndex;
  final bool illustrative;
  @override
  State<_FacilityImageViewer> createState() => _FacilityImageViewerState();
}

class _FacilityImageViewerState extends State<_FacilityImageViewer> {
  late final controller = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(int delta) {
    final next = index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    if (AppMotion.reduced(context)) {
      controller.jumpToPage(next);
    } else {
      controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0F1916),
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${index + 1} / ${widget.photos.length}',
                  key: const Key('viewer-counter'),
                  style: exploreText(14, color: Colors.white),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: CupertinoButton(
                    key: const Key('viewer-close'),
                    onPressed: () => Navigator.of(context).pop(index),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  key: const Key('facility-image-pages'),
                  controller: controller,
                  itemCount: widget.photos.length,
                  onPageChanged: (value) => setState(() => index = value),
                  itemBuilder: (_, i) =>
                      FacilityPhoto(widget.photos[i], fit: BoxFit.contain),
                ),
                if (index > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CupertinoButton(
                      onPressed: () => move(-1),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (index + 1 < widget.photos.length)
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      onPressed: () => move(1),
                      child: const Icon(
                        CupertinoIcons.chevron_right,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.name,
                    style: exploreText(
                      18,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.illustrative
                      ? 'Illustrative concept image · swipe to browse'
                      : 'Swipe to browse',
                  style: exploreText(11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
