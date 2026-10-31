import 'package:flutter/material.dart';

class FeedbackPlayer {
  const FeedbackPlayer(this.id, this.name, this.avatar);
  final String id, name, avatar;
}

const feedbackTeammates = [
  FeedbackPlayer('minh', 'Minh', 'assets/sprint8/feedback_minh.png'),
  FeedbackPlayer('an', 'An', 'assets/sprint8/feedback_an.png'),
  FeedbackPlayer('huy', 'Huy', 'assets/sprint8/feedback_huy.png'),
];

class TeammateFeedback {
  const TeammateFeedback({
    required this.player,
    required this.stars,
    this.tags = const {},
    this.review = '',
  });
  final FeedbackPlayer player;
  final int stars;
  final Set<String> tags;
  final String review;
}

/// Explicit session-only preview adapter. There is no Feedback API in the
/// checked-in backend. Never writes ratings or completion into a real match.
class FeedbackRepository extends ChangeNotifier {
  static final instance = FeedbackRepository();
  FeedbackRepository({
    this.delay = const Duration(milliseconds: 350),
    this.withSamples = true,
  });
  final Duration delay;
  final bool withSamples;
  bool _submitting = false;
  bool get submitting => _submitting;
  final Map<String, List<TeammateFeedback>> _given = {};
  bool submitted(String matchId) => _given.containsKey(matchId);
  List<TeammateFeedback> get given => _given.isNotEmpty
      ? _given.values.expand((v) => v).toList()
      : withSamples
      ? feedbackTeammates
            .map(
              (p) => TeammateFeedback(
                player: p,
                stars: 5,
                review: 'Great teamwork and positive energy. Would play together again!',
              ),
            )
            .toList()
      : [];
  List<TeammateFeedback> get received => !withSamples
      ? []
      : [
          TeammateFeedback(
            player: feedbackTeammates[0],
            stars: 5,
            review: 'A thoughtful teammate. Great communication and fair play!',
          ),
          TeammateFeedback(
            player: feedbackTeammates[1],
            stars: 5,
            review: 'Fun rallies and always encouraging the team.',
          ),
          TeammateFeedback(
            player: feedbackTeammates[2],
            stars: 5,
            review: 'On time, friendly and a great doubles partner.',
          ),
        ];
  Future<void> submit(String matchId, List<TeammateFeedback> entries) async {
    if (_submitting) throw StateError('Feedback is already being sent.');
    if (submitted(matchId)) throw StateError('Feedback has already been sent.');
    if (entries.length != feedbackTeammates.length ||
        entries.map((e) => e.player.id).toSet().length != entries.length ||
        entries.any(
          (e) =>
              !feedbackTeammates.any((p) => p.id == e.player.id) ||
              e.stars < 1 ||
              e.stars > 5 ||
              e.review.characters.length > 300,
        )) {
      throw ArgumentError('Rate every teammate from 1 to 5 stars.');
    }
    _submitting = true;
    notifyListeners();
    try {
      await Future<void>.delayed(delay);
      _given[matchId] = List.unmodifiable(
        entries.map(
          (e) => TeammateFeedback(
            player: e.player,
            stars: e.stars,
            tags: Set.unmodifiable(e.tags),
            review: e.review.trim(),
          ),
        ),
      );
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
