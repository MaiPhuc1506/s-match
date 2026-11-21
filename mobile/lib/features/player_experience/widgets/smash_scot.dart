import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../court_map/exploration_data.dart';
import '../data/demo_catalog.dart';
import '../models/chat_message.dart';
import '../platform_view/bot_avatar_view.dart';
import '../services/smash_scot_chat_service.dart';
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
  final List<ChatMessage> _conversationHistory = [];

  @override
  void dispose() {
    if (widget.avatarState == null) state.dispose();
    super.dispose();
  }

  Future<ChatMessage> richReplyFor(String query) async {
    final service = ref.read(smashScotChatServiceProvider);
    if (service.hasActiveSession) {
      try {
        final reply = await service.sendRichMessage(
          query,
          history: List.unmodifiable(_conversationHistory),
        );
        _conversationHistory.add(
          ChatMessage(id: 'u', text: query, isUser: true),
        );
        _conversationHistory.add(reply);
        return reply;
      } on DioException catch (e) {
        final message = switch (e.response?.statusCode) {
          401 => 'Your session has expired. Please sign in again to use live Smash Scot AI.',
          403 => 'Access denied: your account role does not have permission for that request.',
          429 => 'You are sending messages too quickly. Please wait a moment and try again.',
          _ => 'Smash Scot could not reach the S-Match AI service right now. Please try again.',
        };
        return ChatMessage(id: 'error', text: message, isUser: false);
      } catch (_) {
        return ChatMessage(
          id: 'error',
          text: 'Smash Scot could not reach the S-Match AI service right now. Please try again.',
          isUser: false,
        );
      }
    }
    if (RegExp(
      r'\d+(?:[.,]\d+)?\s*(km|kilometers?|kilometres?)\b',
      caseSensitive: false,
    ).hasMatch(query)) {
      return ChatMessage(
        id: 'location',
        text:
            'Please sign in and allow location access to find courts near you.',
        isUser: false,
      );
    }
    return ChatMessage(id: 'demo', text: await replyFor(query), isUser: false);
  }

  Future<String> replyFor(String query) async {
    final chatService = ref.read(smashScotChatServiceProvider);
    final useLiveBackend = widget.live || chatService.hasActiveSession;

    if (useLiveBackend) {
      try {
        final reply = await chatService.sendMessage(
          query,
          history: List.unmodifiable(_conversationHistory),
        );
        _conversationHistory.add(
          ChatMessage(
            id: 'u_${DateTime.now().microsecondsSinceEpoch}',
            text: query,
            isUser: true,
          ),
        );
        _conversationHistory.add(
          ChatMessage(
            id: 'a_${DateTime.now().microsecondsSinceEpoch}',
            text: reply,
            isUser: false,
          ),
        );
        return reply;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          return 'Your session has expired. Please sign in again to use live Smash Scot AI.';
        }
        if (e.response?.statusCode == 403) {
          return 'Access denied: your account role does not have permission for that request.';
        }
        if (e.response?.statusCode == 429) {
          return 'You are sending messages too quickly. Please wait a moment and try again.';
        }
        if (!widget.live) {
          return 'Smash Scot could not reach the S-Match AI service right now. Please try again in a moment.';
        }
      } catch (_) {
        if (!widget.live) {
          return 'Smash Scot could not reach the S-Match AI service right now. Please try again in a moment.';
        }
      }
    }

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
    final chatService = ref.watch(smashScotChatServiceProvider);
    final isLive = widget.live || chatService.hasActiveSession;
    if (widget.live) ref.watch(nearbyCourtsProvider);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final topSafe = media.padding.top;
    final bottomSafe = media.padding.bottom;
    final availableHeight =
        media.size.height -
        topSafe -
        bottomInset -
        (bottomInset > 0 ? 16 : bottomSafe + 24);
    final popupHeight = availableHeight.clamp(220.0, 500.0);

    return SafeArea(
      bottom: bottomInset == 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          bottomInset > 0 ? bottomInset + 8 : 12,
        ),
        child: ValueListenableBuilder<BotAvatarState>(
          valueListenable: state,
          builder: (context, avatar, _) => Align(
            alignment: bottomInset > 0
                ? Alignment.bottomCenter
                : Alignment.center,
            heightFactor: 1,
            child: CompactChatPopup(
              avatarState: avatar,
              onStateChanged: (next) => state.value = next,
              onClose: () => Navigator.pop(context),
              replyFor: replyFor,
              richReplyFor: richReplyFor,
              live: isLive,
              maxHeight: popupHeight,
            ),
          ),
        ),
      ),
    );
  }
}
