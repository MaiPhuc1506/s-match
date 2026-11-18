import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../court_map/exploration_data.dart';
import '../data/demo_catalog.dart';
import '../platform_view/bot_avatar_view.dart';
import 'compact_chat_popup.dart';
import 'floating_mascot_bubble.dart';

/// Floating overlay; does not take space in the dashboard layout.
class SmashScot extends StatefulWidget {
  const SmashScot({super.key});
  @override
  State<SmashScot> createState() => _SmashScotState();
}

class _SmashScotState extends State<SmashScot> {
  Offset? position;
  bool dragging = false;
  bool chatOpen = false;
  final avatarState = ValueNotifier(BotAvatarState.defaultState);

  @override
  void dispose() {
    avatarState.dispose();
    super.dispose();
  }

  Future<void> openChat() async {
    if (chatOpen) return;
    setState(() => chatOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmashScotChat(avatarState: avatarState),
    );
    if (!mounted) return;
    avatarState.value = BotAvatarState.defaultState;
    setState(() => chatOpen = false);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final maxX = (bounds.maxWidth - 68).clamp(0.0, double.infinity);
      final maxY = (bounds.maxHeight - 68).clamp(0.0, double.infinity);
      final point = position ?? Offset(maxX, (maxY - 14).clamp(0.0, maxY));
      return Stack(
        children: [
          AnimatedPositioned(
            left: point.dx.clamp(0.0, maxX),
            top: point.dy.clamp(0.0, maxY),
            duration: dragging || AppMotion.reduced(context)
                ? Duration.zero
                : AppMotion.duration(context, 220),
            curve: Curves.easeOutCubic,
            child: Semantics(
              label: 'Smash Scot demo assistant',
              button: true,
              child: GestureDetector(
                onPanStart: (_) => setState(() {
                  position = point;
                  dragging = true;
                }),
                onPanUpdate: (d) => setState(
                  () => position = Offset(
                    ((position ?? point).dx + d.delta.dx).clamp(0.0, maxX),
                    ((position ?? point).dy + d.delta.dy).clamp(0.0, maxY),
                  ),
                ),
                onPanEnd: (_) => setState(() {
                  dragging = false;
                  position = Offset(
                    (position ?? point).dx < maxX / 2 ? 0 : maxX,
                    (position ?? point).dy.clamp(0.0, maxY),
                  );
                }),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Center(
                    child: ValueListenableBuilder<BotAvatarState>(
                      valueListenable: avatarState,
                      builder: (_, state, _) => FloatingMascotBubble(
                        avatarState: state,
                        isChatOpen: chatOpen,
                        onTap: openChat,
                        size: 58,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SmashScotChat extends ConsumerStatefulWidget {
  const SmashScotChat({super.key, this.avatarState, this.live = false});
  final ValueNotifier<BotAvatarState>? avatarState;

  /// Opt in to the existing live facilities API; the default remains demo data.
  final bool live;
  @override
  ConsumerState<SmashScotChat> createState() => _SmashScotChatState();
}

class _SmashScotChatState extends ConsumerState<SmashScotChat> {
  late final ValueNotifier<BotAvatarState> state =
      widget.avatarState ?? ValueNotifier(BotAvatarState.defaultState);

  @override
  void dispose() {
    if (widget.avatarState == null) state.dispose();
    super.dispose();
  }

  Future<String> replyFor(String query) async {
    final key = query.toLowerCase();
    if (key.contains('review')) {
      return 'Demo response: No real reviews are available. Reviews will appear when a verified review service is connected.';
    }
    if (key.contains('player') || key.contains('insight')) {
      return 'Demo response: Live player statistics are not available in this assistant. Use the existing Match and Recommendation flows for player information.';
    }
    if (key.contains('court') ||
        key.contains('facilit') ||
        key.contains('price')) {
      if (widget.live) {
        try {
          final courts = await ref.read(nearbyCourtsProvider.future);
          if (courts.isEmpty) {
            return 'Live facilities: no facilities were returned. Explore Courts for more details.';
          }
          final first = courts.first;
          return 'Live facilities: ${courts.length} facilities found. ${first.name}${first.address.isEmpty ? '' : ', ${first.address}'}. Explore Courts for details.';
        } catch (_) {
          return 'Live facilities are unavailable right now. Please try again later.';
        }
      }
      final catalogue = ref.read(demoCatalogProvider);
      if (catalogue.facilities.isEmpty) {
        return 'Demo response: No illustrative facilities are available.';
      }
      final first = catalogue.facilities.first;
      return 'Demo response: ${catalogue.facilities.length} illustrative facilities in Da Nang. ${first.name} has ${first.courtCount} courts, from ${first.hourlyPrice} VND/hour. Explore Courts for details. Availability here is session-only demo data.';
    }
    return 'Demo response: Choose Court Information, Player Insights or Reviews. This helper uses local demo content and cannot make reservations.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.live) ref.watch(nearbyCourtsProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ValueListenableBuilder<BotAvatarState>(
        valueListenable: state,
        builder: (context, avatar, _) => Center(
          heightFactor: 1,
          child: CompactChatPopup(
            avatarState: avatar,
            onStateChanged: (next) => state.value = next,
            onClose: () => Navigator.pop(context),
            replyFor: replyFor,
            live: widget.live,
            maxHeight: (MediaQuery.sizeOf(context).height * .7).clamp(
              0.0,
              500.0,
            ),
          ),
        ),
      ),
    );
  }
}
