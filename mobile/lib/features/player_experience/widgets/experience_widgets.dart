import '../../../core/theme/app_motion_widgets.dart';

import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../navigation/player_bottom_navigation.dart';
import 'smash_scot.dart';

const mint = AppColors.primary;
const experienceBackground = Color(0xFFF3F8F5);
void openExperience(BuildContext context, Widget page) =>
    Navigator.of(context).push(AppMotion.route<void>(page));

class ExperienceScaffold extends StatelessWidget {
  const ExperienceScaffold({
    super.key,
    required this.title,
    required this.child,
    this.tab = PlayerNavTab.home,
    this.bottom,
    this.mascot = true,
  });
  final String title;
  final Widget child;
  final PlayerNavTab tab;
  final Widget? bottom;
  final bool mascot;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: experienceBackground,
    appBar: AppBar(title: Text(title), backgroundColor: experienceBackground),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bottom != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: bottom!,
          ),
        PlayerBottomNavigation(
          currentTab: tab,
          allowCurrentTabNavigation: true,
        ),
      ],
    ),
    body: Stack(
      children: [
        Positioned.fill(child: child),
        if (mascot) const SmashScot(),
      ],
    ),
  );
}

class ExperienceCard extends StatelessWidget {
  const ExperienceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => AppReveal(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE6EEEA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class ExperiencePhoto extends StatelessWidget {
  const ExperiencePhoto(this.path, {super.key, this.height = 170});
  final String path;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.asset(
      path,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({
    super.key,
    this.text = 'Demo content · Illustrative listings and availability',
  });
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(text, style: const TextStyle(fontSize: 11, color: mint)),
  );
}

class ExperienceAction extends StatelessWidget {
  const ExperienceAction({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => AppPressFeedback(
    enabled: onPressed != null,
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(label),
      ),
    ),
  );
}
