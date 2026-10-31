import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Sprint2Style {
  static const background = Color(0xFFF7F8F5);
  static const primary = Color(0xFF05644F);
  static const text = Color(0xFF142824);
  static const secondary = Color(0xFF64716D);
  static const surface = Color(0xFFF3F6F3);
  static TextStyle font(
    double size,
    double line, {
    FontWeight weight = FontWeight.w400,
    Color color = text,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    height: line / size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
  );
}

class Sprint2BackHeader extends StatelessWidget {
  const Sprint2BackHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: math.max(96, MediaQuery.paddingOf(context).top + 44),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        math.max(40, MediaQuery.paddingOf(context).top),
        20,
        0,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: SvgPicture.asset(
                'assets/icons/register_back.svg',
                width: 19.2,
                height: 19.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Sprint2Style.font(
                18,
                25,
                weight: FontWeight.w700,
                color: const Color(0xFF1C1C1C),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    ),
  );
}

/// A scrollable native form; the CTA keeps the Figma bottom alignment when the
/// content fits and remains reachable with the keyboard or larger text.
class Sprint2FormBody extends StatelessWidget {
  const Sprint2FormBody({
    super.key,
    required this.children,
    required this.button,
    this.spacing = 16,
  });
  final List<Widget> children;
  final Widget button;
  final double spacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bottom = math.max(34.0, MediaQuery.paddingOf(context).bottom);
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) SizedBox(height: spacing),
                    children[i],
                  ],
                  SizedBox(height: spacing),
                  const Spacer(),
                  button,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class Sprint2CourtPhoto extends StatelessWidget {
  const Sprint2CourtPhoto({super.key, this.opacity = 1});
  final double opacity;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              left: 0,
              top: -constraints.maxHeight * .3235,
              width: constraints.maxWidth,
              height: constraints.maxHeight * 1.4706,
              child: Image.asset(
                'assets/images/sprint2_profile_ProfileHeroReusedCourtPhotograph.png',
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class Sprint2CameraBadge extends StatelessWidget {
  const Sprint2CameraBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Sprint2Style.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black, width: 3),
    ),
    child: Center(
      child: SvgPicture.asset(
        'assets/icons/sprint2_profile_Camera.svg',
        width: 18,
        height: 18,
      ),
    ),
  );
}
