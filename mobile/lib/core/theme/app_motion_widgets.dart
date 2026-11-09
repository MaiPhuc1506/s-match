import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_motion.dart';

/// Shared section motion, matching the dashboard's 600 ms / 24 px entrance.
/// State lives in the widget/route, never in repositories or Riverpod providers.
class AppReveal extends StatefulWidget {
  const AppReveal({
    super.key,
    required this.child,
    this.id,
    this.delay = 0,
    this.down = false,
  });
  final Widget child;
  final Object? id;
  final int delay;
  final bool down;

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal>
    with SingleTickerProviderStateMixin {
  static final _visits = Expando<Set<Object>>();
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  ScrollPosition? _position;
  Timer? _timer;
  Set<Object>? _revealed;
  bool _started = false;
  bool _visibilityCheckQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_queueVisibilityCheck);
    final route = ModalRoute.of(context);
    if (route != null) {
      _revealed = _visits[route] ??= <Object>{};
    }
    if (AppMotion.reduced(context) ||
        (widget.id != null && (_revealed?.contains(widget.id) ?? false))) {
      _started = true;
      _timer?.cancel();
      _controller.value = 1;
    } else if (!_started) {
      _position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
      _position?.addListener(_queueVisibilityCheck);
      _queueVisibilityCheck();
    }
  }

  void _queueVisibilityCheck() {
    if (!mounted || _started || _visibilityCheckQueued) return;
    _visibilityCheckQueued = true;
    // Scroll notifications can precede layout; inspect the final viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckQueued = false;
      _checkVisible();
    });
  }

  void _checkVisible() {
    if (!mounted || _started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final viewportBox = viewport is RenderBox ? viewport as RenderBox : null;
    final top = viewportBox?.localToGlobal(Offset.zero).dy ?? 0.0;
    final bottom = viewportBox != null
        ? top + viewportBox.size.height
        : MediaQuery.sizeOf(context).height;
    if (y + box.size.height <= top || y >= bottom) return;
    _started = true;
    _position?.removeListener(_queueVisibilityCheck);
    if (widget.id != null) _revealed?.add(widget.id!);
    if (widget.delay == 0) {
      _controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_queueVisibilityCheck);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_controller.value);
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

/// Keeps the original Column layout, including Spacer/Expanded parent data.
/// Only content sections animate; the stagger is capped at 270 ms.
class AppStaggeredColumn extends StatelessWidget {
  const AppStaggeredColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    var section = 0;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (final child in children)
          if (child is SizedBox ||
              child is Spacer ||
              child is Flexible ||
              child is AppReveal)
            child
          else
            AppReveal(
              key: child.key == null ? null : ValueKey(child.key),
              delay: (section++).clamp(0, 3) * 90,
              child: child,
            ),
      ],
    );
  }
}

/// Pointer feedback without an extra gesture recognizer or callback.
/// Native buttons/InkWells retain their existing tap and loading behavior.
class AppPressFeedback extends StatefulWidget {
  const AppPressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<AppPressFeedback> createState() => _AppPressFeedbackState();
}

class _AppPressFeedbackState extends State<AppPressFeedback> {
  bool _pressed = false;
  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(AppPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (_) => setState(() => _pressed = true)
        : null,
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedScale(
      scale: _pressed && !AppMotion.reduced(context) ? .985 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
