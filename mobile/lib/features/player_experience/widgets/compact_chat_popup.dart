import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

import '../../../core/theme/app_motion.dart';

import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import 'court_chat_card.dart';
import '../platform_view/bot_avatar_view.dart';

/// Compact Messenger-style assistant card.
///
/// Deliberately small and light: a deep-green branded header with the native
/// Smash Scot mascot, a short message area, a 2×2 grid of outlined quick
/// actions and an iOS-style input bar. The mascot itself lives in the native
/// platform view, so every state (idle, thinking, typing, success, sleep) is
/// rendered by the same rig used by the floating bubble.
class CompactChatPopup extends StatefulWidget {
  final BotAvatarState avatarState;
  final ValueChanged<BotAvatarState> onStateChanged;
  final VoidCallback onClose;
  final bool autoFocusInput;
  final double maxHeight;
  final bool live;
  final Future<String> Function(String) replyFor;
  final Future<ChatMessage> Function(String)? richReplyFor;

  const CompactChatPopup({
    super.key,
    required this.avatarState,
    required this.onStateChanged,
    required this.onClose,
    required this.replyFor,
    this.richReplyFor,
    this.live = false,
    this.autoFocusInput = false,
    this.maxHeight = 400.0,
  });

  @override
  State<CompactChatPopup> createState() => _CompactChatPopupState();
}

class _CompactChatPopupState extends State<CompactChatPopup>
    with TickerProviderStateMixin {
  static const Color _deepGreen = Color(0xFF17553F);
  static const Color _deepGreenDark = Color(0xFF0C3D2C);
  static const Color _accentGreen = Color(0xFF1B7A55);
  static const Color _botBubble = Color(0xFFF1F2F6);
  static const Color _hairline = Color(0xFFE4E8EB);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final AnimationController _typingController;
  late final AnimationController _phaseController;
  bool _reducedMotion = false;
  late List<ChatMessage> _messages;
  bool _isBotTyping = false;
  bool _quickActionsExpanded = true;
  double _lastBottomInset = 0;

  static const List<_QuickAction> _quickActions = [
    _QuickAction('Court Information', CupertinoIcons.search),
    _QuickAction('Player Insights', CupertinoIcons.person_2),
    _QuickAction('Reviews', CupertinoIcons.star),
    _QuickAction('Find a court', CupertinoIcons.location),
  ];

  @override
  void initState() {
    super.initState();
    _messages = widget.live
        ? [
            ChatMessage(
              id: '1',
              text: 'Hi! I can look up live badminton facilities in Da Nang. Other answers use demo information.',
              isUser: false,
            ),
          ]
        : ChatMessage.initialMockMessages();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _phaseController = AnimationController(vsync: this);

    if (widget.autoFocusInput) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = AppMotion.reduced(context);
    _syncTypingAnimation();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (bottomInset > _lastBottomInset && _messages.length > 1) {
      _scrollToBottom();
    }
    _lastBottomInset = bottomInset;
  }

  void _syncTypingAnimation() {
    if (_isBotTyping && !_reducedMotion) {
      if (!_typingController.isAnimating) _typingController.repeat();
    } else {
      _typingController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CompactChatPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoFocusInput && !oldWidget.autoFocusInput) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _typingController.dispose();
    _phaseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    void jumpOrAnimate() {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpOrAnimate();
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpOrAnimate());
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isBotTyping) return;

    _textController.clear();
    HapticFeedback.selectionClick();

    final userMsg = ChatMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: query,
      isUser: true,
    );

    setState(() {
      _messages.add(userMsg);
      _isBotTyping = true;
      _quickActionsExpanded = false;
    });
    _syncTypingAnimation();
    _scrollToBottom();

    try {
      widget.onStateChanged(BotAvatarState.thinking);
      _phaseController.duration = Duration(
        milliseconds: _reducedMotion ? 1 : 350,
      );
      await _phaseController.forward(from: 0).orCancel;
      widget.onStateChanged(BotAvatarState.working);
      final richReply = widget.richReplyFor != null
          ? await widget.richReplyFor!(query)
          : null;
      final reply = richReply?.text ?? await widget.replyFor(query);
      _phaseController.duration = Duration(
        milliseconds: _reducedMotion ? 1 : 350,
      );
      await _phaseController.forward(from: 0).orCancel;
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: '${DateTime.now().microsecondsSinceEpoch}',
            text: reply,
            isUser: false,
            avatarState: BotAvatarState.defaultState,
            courtResults: richReply?.courtResults ?? const [],
          ),
        );
        _isBotTyping = false;
      });
      _syncTypingAnimation();
      _scrollToBottom();
      widget.onStateChanged(BotAvatarState.success);
      _phaseController.duration = Duration(
        milliseconds: _reducedMotion ? 1 : 500,
      );
      await _phaseController.forward(from: 0).orCancel;
      if (mounted && !_isBotTyping) {
        widget.onStateChanged(BotAvatarState.defaultState);
      }
    } on TickerCanceled {
      // The popup was closed while an animation was in progress.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 344,
        height: widget.maxHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFC),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF07271C).withValues(alpha: 0.28),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ClipRect(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    itemCount: _messages.length + (_isBotTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isBotTyping) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      final showAvatar =
                          !msg.isUser &&
                          (index == 0 || _messages[index - 1].isUser);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMessageRow(
                            msg.courtResults.isNotEmpty
                                ? ChatMessage(
                                    id: msg.id,
                                    text:
                                        'Found ${msg.courtResults.length} matching facilities:',
                                    isUser: false,
                                  )
                                : msg,
                            showAvatar: showAvatar,
                          ),
                          for (final court in msg.courtResults)
                            CourtChatCard(data: court),
                        ],
                      );
                    },
                  ),
                ),
              ),
              _buildQuickActions(),
              _buildInputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 10, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_deepGreen, _deepGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Native mascot, not an emoji.
          BotAvatarWidget(
            state: widget.avatarState,
            colorHex: '#35B96C',
            size: 54,
            interactive: false,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Smash Scot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8CE9B0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.live ? 'LIVE' : 'DEMO',
                        style: const TextStyle(
                          color: Color(0xFF0E4A35),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Your badminton assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: widget.onClose,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.white.withValues(alpha: 0.14),
              ),
              child: const Icon(
                CupertinoIcons.chevron_down,
                size: 16,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, {required bool showAvatar}) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 44),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: const BoxDecoration(
            color: _deepGreen,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(17),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ),
      );
    }

    final bubble = Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: const BoxDecoration(
          color: _botBubble,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(17),
            topRight: Radius.circular(17),
            bottomLeft: Radius.circular(5),
            bottomRight: Radius.circular(17),
          ),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: Color(0xFF1B1C1E),
            fontSize: 13.5,
            height: 1.32,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar) ...[_buildMessageAvatar(), const SizedBox(width: 6)],
          bubble,
        ],
      ),
    );
  }

  Widget _buildMessageAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.22, -0.38),
          radius: 0.95,
          colors: [Color(0xFF35B96C), Color(0xFF17553F)],
        ),
        border: Border.all(
          color: const Color(0xFF8CE9B0).withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 7,
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(
              color: Color(0xFFD62828),
              fontSize: 6.5,
              height: 1.0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildMessageAvatar(),
          const SizedBox(width: 6),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: _botBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(17),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingController,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_typingController.value + i * 0.18) % 1.0;
                    final lift = t < 0.5
                        ? -2.2 * (t / 0.5)
                        : -2.2 * (1 - (t - 0.5) / 0.5);
                    final opacity = t < 0.5
                        ? 0.45 + 0.55 * (t / 0.5)
                        : 1.0 - 0.55 * ((t - 0.5) / 0.5);
                    return Padding(
                      padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                      child: Transform.translate(
                        offset: Offset(0, lift),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6B7A75)
                                .withValues(alpha: opacity),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final hasStartedConversation = _messages.any((m) => m.isUser);
    final showFullGrid = !hasStartedConversation && _quickActionsExpanded;

    if (!showFullGrid) {
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _quickActions.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final action = _quickActions[index];
            return GestureDetector(
              onTap: () => _handleSendMessage(action.label),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _hairline, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 13.5, color: _accentGreen),
                    const SizedBox(width: 5),
                    Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        color: Color(0xFF1B1C1E),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: EdgeInsets.only(bottom: row == 0 ? 7 : 0),
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col == 1) const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionPill(
                        action: _quickActions[row * 2 + col],
                        accent: _accentGreen,
                        border: _hairline,
                        onTap: () => _handleSendMessage(
                          _quickActions[row * 2 + col].label,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(top: BorderSide(color: _hairline, width: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F5),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Center(
                child: CupertinoTextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: widget.autoFocusInput,
                  placeholder: 'Ask Smash Scot…',
                  placeholderStyle: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF9AA3A0),
                  ),
                  padding: EdgeInsets.zero,
                  decoration: null,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF1B1C1E),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _handleSendMessage,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            pressedOpacity: 0.7,
            onPressed: () => _handleSendMessage(_textController.text),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_accentGreen, _deepGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                CupertinoIcons.paperplane_fill,
                size: 16,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  const _QuickAction(this.label, this.icon);
}

class _QuickActionPill extends StatelessWidget {
  final _QuickAction action;
  final Color accent;
  final Color border;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.action,
    required this.accent,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          children: [
            Icon(action.icon, size: 17, color: accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                  color: Color(0xFF1B1C1E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
