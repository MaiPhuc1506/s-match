import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

/// Available bot avatar shapes supported by the native mascot
enum BotAvatarType {
  clover,
  flower,
  triangle,
  square,
  blob,
  ghost,
  circle,
  drop,
  star,
  droid,
  mech,
  alien,
  hexagon,
  cat,
  cloud,
  pill,
  pebble,
  puddle,
}

/// Dynamic motion state of the avatar.
///
/// Thinking and success map onto the native rig's calm and working motions;
/// thinking additionally uses the native concentrated-eye expression.
enum BotAvatarState {
  /// Idle state with subtle breathing, glancing, and occasional flips
  defaultState('default'),

  /// Calm body with concentrated `> <` eyes
  thinking('thinking'),

  /// Active state: jumping, spinning, and animated hopping
  working('working'),

  /// Happy working face with success sparkles
  success('success'),

  /// Sleeping state: eyes closed, gentle pulse
  sleeping('sleeping');

  final String rawValue;
  const BotAvatarState(this.rawValue);

  bool get isActive =>
      this == BotAvatarState.working ||
      this == BotAvatarState.success ||
      this == BotAvatarState.thinking;

  String get label {
    switch (this) {
      case BotAvatarState.defaultState:
        return 'Idle';
      case BotAvatarState.thinking:
        return 'Thinking';
      case BotAvatarState.working:
        return 'Typing';
      case BotAvatarState.success:
        return 'Success';
      case BotAvatarState.sleeping:
        return 'Sleep';
    }
  }
}

/// Controller allowing Flutter widgets to dynamically instruct the native SwiftUI
/// BotAvatar component via Flutter Platform View MethodChannel.
class BotAvatarController {
  MethodChannel? _channel;
  int? _viewId;

  bool get isAttached => _channel != null;
  int? get viewId => _viewId;

  void attach(int id) {
    _viewId = id;
    _channel = MethodChannel('smashscot/bot_avatar_$id');
  }

  void detach() {
    _channel = null;
    _viewId = null;
  }

  /// Change the avatar state (e.g. idle vs working)
  Future<bool> setState(BotAvatarState state) async {
    if (_channel == null) return false;
    try {
      final res = await _channel!.invokeMethod<bool>('setState', {
        'state': state.rawValue,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('Error setting avatar state: $e');
      return false;
    }
  }

  /// Change the avatar body type (e.g. clover, blob, etc.)
  Future<bool> setType(BotAvatarType type) async {
    if (_channel == null) return false;
    try {
      final res = await _channel!.invokeMethod<bool>('setType', {
        'type': type.name,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('Error setting avatar type: $e');
      return false;
    }
  }

  /// Change the avatar tint color
  Future<bool> setColor(String hexColor) async {
    if (_channel == null) return false;
    try {
      final res = await _channel!.invokeMethod<bool>('setColor', {
        'color': hexColor,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('Error setting avatar color: $e');
      return false;
    }
  }

  /// Change rendered size in points
  Future<bool> setSize(double size) async {
    if (_channel == null) return false;
    try {
      final res = await _channel!.invokeMethod<bool>('setSize', {'size': size});
      return res ?? true;
    } catch (e) {
      debugPrint('Error setting avatar size: $e');
      return false;
    }
  }
}

/// Embeds the native SwiftUI BotAvatar component inside Flutter using UIKitView.
class BotAvatarWidget extends StatefulWidget {
  final BotAvatarType type;
  final BotAvatarState state;
  final String colorHex;
  final double size;
  final bool interactive;
  final BotAvatarController? controller;
  final VoidCallback? onCreated;

  const BotAvatarWidget({
    super.key,
    this.type = BotAvatarType.clover,
    this.state = BotAvatarState.defaultState,
    this.colorHex = '#35B96C', // Smash Scot emerald clover green
    this.size = 64.0,
    this.interactive = true,
    this.controller,
    this.onCreated,
  });

  @override
  State<BotAvatarWidget> createState() => _BotAvatarWidgetState();
}

class _BotAvatarWidgetState extends State<BotAvatarWidget> {
  late BotAvatarController _internalController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _internalController = widget.controller!;
    } else {
      _internalController = BotAvatarController();
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(covariant BotAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _internalController.setState(widget.state);
    }
    if (oldWidget.type != widget.type) {
      _internalController.setType(widget.type);
    }
    if (oldWidget.colorHex != widget.colorHex) {
      _internalController.setColor(widget.colorHex);
    }
    if (oldWidget.size != widget.size) {
      _internalController.setSize(widget.size);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController.detach();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 64 pt avatar view with extra padding so jumps/squash do not clip
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: kIsWeb || defaultTargetPlatform != TargetPlatform.iOS
          ? const Center(
              child: Icon(Icons.sports_tennis, color: Color(0xFFB8F5C9)),
            )
          : UiKitView(
              viewType: 'smashscot/bot_avatar',
              layoutDirection: TextDirection.ltr,
              creationParams: {
                'type': widget.type.name,
                'state': widget.state.rawValue,
                'color': widget.colorHex,
                'size': widget.size,
                'interactive': widget.interactive,
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (int id) {
                _internalController.attach(id);
                _internalController.setState(widget.state);
                _internalController.setType(widget.type);
                _internalController.setColor(widget.colorHex);
                _internalController.setSize(widget.size);
                widget.onCreated?.call();
              },
            ),
    );
  }
}
