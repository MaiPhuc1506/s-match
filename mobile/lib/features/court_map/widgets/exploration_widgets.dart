import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

const exploreGreen = Color(0xFF05644F);
const exploreInk = Color(0xFF102D28);
const exploreMuted = Color(0xFF647976);
const exploreBackground = Color(0xFFFAFBF9);
const exploreLight = Color(0xFFF0F4F1);
const explorationAssets = 'assets/sprint6/exploration/';

TextStyle exploreText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = exploreInk,
  double? line,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: (line ?? (size * 1.35).ceilToDouble()) / size,
  letterSpacing: 0,
);

Route<T> explorationRoute<T>(Widget screen, String name) => PageRouteBuilder<T>(
  settings: RouteSettings(name: name),
  transitionDuration: const Duration(milliseconds: 250),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (_, _, _) => screen,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

class ExploreGlyph extends StatelessWidget {
  const ExploreGlyph(this.file, {super.key, this.size = 20});
  final String file;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    '$explorationAssets$file.svg',
    width: size,
    height: size,
  );
}

class ExploreControl extends StatelessWidget {
  const ExploreControl({
    super.key,
    required this.label,
    required this.child,
    required this.onTap,
    this.size = 44,
    this.background = Colors.white,
    this.elevation = 1,
  });
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final double size;
  final Color background;
  final double elevation;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: background,
      shape: const CircleBorder(),
      elevation: elevation,
      shadowColor: const Color(0x14133C31),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class ExplorePhoto extends StatelessWidget {
  const ExplorePhoto({
    super.key,
    this.asset = 'assets/images/match/facility_court.jpg',
    this.radius = 0,
  });
  final String asset;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: LayoutBuilder(
      builder: (_, c) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -c.maxHeight * .3235294,
            height: c.maxHeight / .68,
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ],
      ),
    ),
  );
}

class ExploreBadge extends StatelessWidget {
  const ExploreBadge(
    this.text, {
    super.key,
    this.offensive = false,
    this.neutral = false,
    this.fontSize = 10,
  });
  final String text;
  final bool offensive, neutral;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: offensive
          ? const Color(0xFFFCE5E5)
          : neutral
          ? exploreLight
          : const Color(0xFFDFF2E8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: exploreText(
        fontSize,
        weight: FontWeight.w500,
        color: offensive
            ? const Color(0xFFA63838)
            : neutral
            ? exploreMuted
            : exploreGreen,
        line: fontSize + 4,
      ),
    ),
  );
}

class ExploreMessage extends StatelessWidget {
  const ExploreMessage({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: exploreText(13)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
