import '../platform_view/bot_avatar_view.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final BotAvatarState? avatarState;
  final List<Map<String, dynamic>> courtResults;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.avatarState,
    this.courtResults = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  static List<ChatMessage> initialMockMessages() {
    return [
      ChatMessage(
        id: '1',
        text: "Hi! I'm Smash Scot 🏸 Your demo badminton assistant in Da Nang. Ask about courts, players or reviews. No live AI service is connected.",
        isUser: false,
        avatarState: BotAvatarState.defaultState,
      ),
    ];
  }
}
