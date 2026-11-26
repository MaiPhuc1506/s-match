import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';

import '../platform_view/bot_avatar_view.dart';

/// Small Messenger-style floating button with the native Smash Scot mascot.
///
/// The bubble is deliberately a deep forest green, like the approved design,
/// so the bright clover, white headband and red "S" stay legible. State
/// accents (thought bubble, motion lines, sparkles, Zz) sit outside the button
/// so they never cover the mascot.
class FloatingMascotBubble extends StatefulWidget {
  final BotAvatarState avatarState;
  final BotAvatarController? controller;
  final bool isChatOpen;
  final VoidCallback onTap;
  final double size;

  const FloatingMascotBubble({
    super.key,
    required this.avatarState,
    this.controller,
    required this.isChatOpen,
    required this.onTap,
    this.size = 64.0,
  });

  @override
  State<FloatingMascotBubble> createState() => _FloatingMascotBubbleState();
}

class _FloatingMascotBubbleState extends State<FloatingMascotBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    _animController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _buildStateAccents(),
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.22, -0.38),
                        radius: 0.95,
                        colors: [Color(0xFF1C7355), Color(0xFF0B4B36)],
                      ),
                      border: Border.all(
                        color: widget.isChatOpen
                            ? const Color(0x55D8F5E4)
                            : const Color(0x2EFFFFFF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A4733)
                              .withValues(alpha: 0.30),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: IgnorePointer(
                        child: BotAvatarWidget(
                          controller: widget.controller,
                          type: BotAvatarType.clover,
                          state: widget.avatarState,
                          colorHex: '#35B96C',
                          size: 54.0,
                          // The bubble itself owns the tap so opening chat is
                          // never swallowed by the native poke gesture.
                          interactive: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStateAccents() {
    switch (widget.avatarState) {
      case BotAvatarState.thinking:
        return const Positioned(
          top: -9,
          right: -7,
          child: IgnorePointer(child: _ThoughtBubble()),
        );
      case BotAvatarState.working:
        return const Positioned(
          left: -15,
          top: 18,
          child: IgnorePointer(
            child: _MotionLines(count: 2, height: 14, color: Color(0xFF2FBF74)),
          ),
        );
      case BotAvatarState.success:
        return const Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -10,
                  top: 2,
                  child: _Sparkle(size: 17, color: Color(0xFFFFC93C)),
                ),
                Positioned(
                  right: -11,
                  top: -7,
                  child: _Sparkle(size: 22, color: Color(0xFFFFC93C)),
                ),
                Positioned(
                  right: 2,
                  top: 18,
                  child: _Sparkle(size: 10, color: Color(0xFFFFD86B)),
                ),
              ],
            ),
          ),
        );
      case BotAvatarState.sleeping:
        return const Positioned(
          top: -14,
          right: -2,
          child: IgnorePointer(
            child: Text(
              'Zz',
              style: TextStyle(
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                color: Color(0xFF1A6B50),
              ),
            ),
          ),
        );
      case BotAvatarState.defaultState:
        return const Positioned(
          left: -13,
          top: 17,
          child: IgnorePointer(
            child: _MotionLines(count: 3, height: 11, color: Color(0xFF2FBF74)),
          ),
        );
    }
  }
}

class _ThoughtBubble extends StatelessWidget {
  const _ThoughtBubble();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 1,
            right: 1,
            top: 0,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x8835B96C), width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220A4733),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ThoughtDot(opacity: 0.45),
                  SizedBox(width: 4),
                  _ThoughtDot(opacity: 0.72),
                  SizedBox(width: 4),
                  _ThoughtDot(opacity: 1.0),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 21,
            child: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8EE),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: const Color(0x8835B96C),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThoughtDot extends StatelessWidget {
  final double opacity;
  const _ThoughtDot({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4.5,
      height: 4.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A7A55).withValues(alpha: opacity),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '✦',
      style: TextStyle(
        fontSize: size,
        height: 1,
        color: color,
        shadows: const [
          BoxShadow(color: Color(0x33FFB800), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _MotionLines extends StatelessWidget {
  final int count;
  final double height;
  final Color color;
  const _MotionLines({
    required this.count,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(count, (i) {
          final h = i == 1 ? height : height * 0.62;
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: color.withValues(alpha: i == 1 ? 1.0 : 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
