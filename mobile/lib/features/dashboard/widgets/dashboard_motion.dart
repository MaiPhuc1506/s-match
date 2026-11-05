import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visit-local memory, independent of repository/provider state.
class DashboardMotionVisit {
  final revealed = <String>{};
  final values = <String, double>{};
}

class DashboardReveal extends StatefulWidget {
  const DashboardReveal({
    super.key,
    required this.child,
    required this.visit,
    required this.id,
    this.delay = 0,
    this.down = false,
  });
  final Widget child;
  final DashboardMotionVisit visit;
  final String id;
  final int delay;
  final bool down;
  @override
  State<DashboardReveal> createState() => _DashboardRevealState();
}

class _DashboardRevealState extends State<DashboardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  ScrollPosition? position;
  Timer? timer;
  bool started = false;
  bool active = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    position?.removeListener(check);
    position = Scrollable.maybeOf(context)?.position;
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        widget.visit.revealed.contains(widget.id)) {
      started = true;
      active = true;
      controller.value = 1;
    } else {
      position?.addListener(check);
      WidgetsBinding.instance.addPostFrameCallback((_) => check());
    }
  }

  void check() {
    if (!mounted || started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y + box.size.height <= 0 ||
        y >= MediaQuery.sizeOf(context).height - 90) {
      return;
    }
    started = true;
    position?.removeListener(check);
    widget.visit.revealed.add(widget.id);
    timer = Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        setState(() => active = true);
        controller.forward();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    position?.removeListener(check);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: _MotionScope(
      active: active,
      visit: widget.visit,
      id: widget.id,
      child: widget.child,
    ),
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(controller.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (widget.down ? -20 : 24) * (1 - t)),
          child: child,
        ),
      );
    },
  );
}

class _MotionScope extends InheritedWidget {
  const _MotionScope({
    required this.active,
    required this.visit,
    required this.id,
    required super.child,
  });
  final bool active;
  final DashboardMotionVisit visit;
  final String id;
  @override
  bool updateShouldNotify(_MotionScope oldWidget) => active != oldWidget.active;
}

class DashboardCount extends StatelessWidget {
  const DashboardCount(this.value, {super.key, required this.style});
  final String value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'[0-9][0-9,]*(?:\.[0-9]+)?').firstMatch(value);
    if (match == null) return Text(value, style: style);
    final number = double.tryParse(match.group(0)!.replaceAll(',', ''));
    if (number == null) return Text(value, style: style);
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final scope = context.dependOnInheritedWidgetOfExactType<_MotionScope>();
    final memoryKey = '${scope?.id}:count:${key ?? value}';
    final previous = scope?.visit.values[memoryKey] ?? 0;
    final active = scope?.active ?? true;
    final decimals = match.group(0)!.contains('.')
        ? match.group(0)!.split('.').last.length
        : 0;
    return Semantics(
      label: value,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: reduced ? number : previous,
          end: active || reduced ? number : previous,
        ),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 2000),
        curve: Curves.easeOutCubic,
        builder: (context, current, child) {
          scope?.visit.values[memoryKey] = current;
          var formatted = current.toStringAsFixed(decimals);
          if (match.group(0)!.contains(',')) {
            final parts = formatted.split('.');
            parts[0] = parts[0].replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'),
              (_) => ',',
            );
            formatted = parts.join('.');
          }
          return Text(
            current == number
                ? value
                : value.replaceRange(match.start, match.end, formatted),
            style: style,
          );
        },
      ),
    );
  }
}

/// Clips the existing artwork; never fabricates analytics series.
class DashboardChartReveal extends StatelessWidget {
  const DashboardChartReveal({
    super.key,
    required this.child,
    this.vertical = false,
    this.radial = false,
  });
  final Widget child;
  final bool vertical, radial;
  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final scope = context.dependOnInheritedWidgetOfExactType<_MotionScope>();
    final memoryKey = '${scope?.id}:chart:${key ?? child.toStringShort()}';
    final previous = scope?.visit.values[memoryKey] ?? 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: reduced ? 1 : previous,
        end: reduced || (scope?.active ?? true) ? 1 : previous,
      ),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) {
        scope?.visit.values[memoryKey] = t;
        return vertical
            ? Transform.scale(
                scaleY: t,
                alignment: Alignment.bottomCenter,
                child: child,
              )
            : ClipPath(
                clipper: radial ? _SweepClip(t) : _AxisClip(t, false),
                child: child,
              );
      },
    );
  }
}

class _SweepClip extends CustomClipper<Path> {
  _SweepClip(this.t);
  final double t;
  @override
  Path getClip(Size size) {
    if (t == 1) return Path()..addRect(Offset.zero & size);
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * t,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_SweepClip oldClipper) => t != oldClipper.t;
}

class _AxisClip extends CustomClipper<Path> {
  _AxisClip(this.t, this.vertical);
  final double t;
  final bool vertical;
  @override
  Path getClip(Size size) => Path()
    ..addRect(
      vertical
          ? Rect.fromLTWH(0, size.height * (1 - t), size.width, size.height * t)
          : Rect.fromLTWH(0, 0, size.width * t, size.height),
    );
  @override
  bool shouldReclip(_AxisClip oldClipper) =>
      t != oldClipper.t || vertical != oldClipper.vertical;
}

class DashboardPress extends StatefulWidget {
  const DashboardPress({super.key, required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  State<DashboardPress> createState() => _DashboardPressState();
}

class _DashboardPressState extends State<DashboardPress> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (_) => setState(() => pressed = true)
        : null,
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale:
          pressed &&
              !MediaQuery.disableAnimationsOf(context) &&
              !MediaQuery.accessibleNavigationOf(context)
          ? .985
          : 1,
      duration: const Duration(milliseconds: 100),
      child: widget.child,
    ),
  );
}
