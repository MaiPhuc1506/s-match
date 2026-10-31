import 'package:flutter/material.dart';

/// Shared motion policy; reduced motion retains feedback without movement.
abstract final class AppMotion {
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Duration duration(BuildContext context, [int milliseconds = 220]) =>
      Duration(milliseconds: reduced(context) ? 150 : milliseconds);

  static Route<T> route<T>(
    Widget screen, {
    String? name,
    int milliseconds = 220,
  }) => PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: Duration(milliseconds: milliseconds),
    reverseTransitionDuration: Duration(milliseconds: milliseconds),
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: reduced(context)
            ? Interval(0, 150 / milliseconds)
            : Curves.easeOut,
      ),
      child: child,
    ),
  );
}
