import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import 'rating_api.dart';

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
    this.matchTitle,
    this.createdAt,
  });
  final FeedbackPlayer player;
  final int stars;
  final Set<String> tags;
  final String review;
  final String? matchTitle;
  final DateTime? createdAt;
}

/// Explicit session-only design preview; authenticated screens use [active].
class FeedbackRepository extends ChangeNotifier {
  static final instance = FeedbackRepository();
  static ApiFeedbackRepository? _live;
  static FeedbackRepository get active {
    if (ApiClient.instance.token == null) return instance;
    final api = RatingApi.current();
    if (_live?.api.token != api.token || _live?.api.userId != api.userId) {
      _live = ApiFeedbackRepository(api);
    }
    return _live!;
  }

  bool get live => false;
  bool get loading => false;
  String? get error => null;
  RatingSummary? get summary => null;
  List<FeedbackMatch> get pending => const [];
  Future<void> refresh() async {}

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

class FeedbackMatch {
  const FeedbackMatch({
    required this.id,
    required this.title,
    required this.players,
    this.location = '',
    this.time = '',
    this.mode = 'DOUBLES',
  });
  final String id, title, location, time, mode;
  final List<FeedbackPlayer> players;
  factory FeedbackMatch.fromJson(Map<String, dynamic> data, int userId) {
    final raw = data['players'] as List?;
    final roster =
        raw ??
        (data['participants'] as List? ?? [])
            .where((p) => p['status'] == 'ACCEPTED')
            .map((p) => p['user'])
            .toList();
    final start = DateTime.tryParse(data['startTime'] as String? ?? '')
        ?.toLocal();
    final end = DateTime.tryParse(data['endTime'] as String? ?? '')?.toLocal();
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return FeedbackMatch(
      id: '${data['matchId'] ?? data['id']}',
      title: data['title'] as String,
      location: data['location'] as String? ?? '',
      mode: data['mode'] as String? ?? 'DOUBLES',
      time: start == null
          ? ''
          : '${start.day}/${start.month}/${start.year} · ${clock(start)}${end == null ? '' : '–${clock(end)}'}',
      players: roster
          .where((p) => p['id'] != userId)
          .map(
            (p) => FeedbackPlayer(
              '${p['id']}',
              p['fullName'] as String? ?? 'Player',
              '',
            ),
          )
          .toList(),
    );
  }
}

class ApiFeedbackRepository extends FeedbackRepository {
  ApiFeedbackRepository(this.api) : super(withSamples: false);
  final RatingApi api;
  @override
  bool get live => true;
  bool _loading = false, _sending = false;
  String? _error;
  RatingSummary? _summary;
  List<TeammateFeedback> _received = [], _givenRatings = [];
  List<FeedbackMatch> _pending = [];
  final Set<String> _sent = {};
  @override
  bool get loading => _loading;
  @override
  bool get submitting => _sending;
  @override
  String? get error => _error;
  @override
  RatingSummary? get summary => _summary;
  @override
  List<TeammateFeedback> get received => _received;
  @override
  List<TeammateFeedback> get given => _givenRatings;
  @override
  List<FeedbackMatch> get pending => _pending;
  @override
  bool submitted(String matchId) => _sent.contains(matchId);
  TeammateFeedback _entry(Map<String, dynamic> row, bool given) {
    final user = row[given ? 'ratedUser' : 'rater'] as Map;
    return TeammateFeedback(
      player: FeedbackPlayer(
        '${user['id']}',
        user['fullName'] as String? ?? 'Player',
        '',
      ),
      stars: (row['score'] as num).toInt(),
      review: row['comment'] as String? ?? '',
      matchTitle: (row['match'] as Map?)?['title'] as String?,
      createdAt: DateTime.tryParse(row['createdAt'] as String? ?? ''),
    );
  }

  @override
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final summary = await api.summary(api.userId);
      final received = await api.ratings(given: false);
      final given = await api.ratings(given: true);
      final pending = await api.request('/ratings/pending') as List;
      api.checkSession();
      _summary = summary;
      _received = received.map((r) => _entry(r, false)).toList();
      _givenRatings = given.map((r) => _entry(r, true)).toList();
      _pending = pending
          .map(
            (r) => FeedbackMatch.fromJson(
              Map<String, dynamic>.from(r as Map),
              api.userId,
            ),
          )
          .toList();
    } catch (e) {
      _summary = null;
      _received = [];
      _givenRatings = [];
      _pending = [];
      _error = e is RatingFailure
          ? e.message
          : 'Unable to read ratings. Please refresh.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-read the completed match and server history before each attempt. A
  /// partial/ambiguous network failure can then retry only missing recipients.
  @override
  Future<void> submit(String matchId, List<TeammateFeedback> entries) async {
    if (_sending) throw StateError('Feedback is already being sent.');
    final id = int.tryParse(matchId);
    if (id == null || id < 1) {
      throw const RatingFailure(
        'A real match is required. Preview matches cannot be submitted.',
      );
    }
    if (entries.isEmpty ||
        entries.map((e) => e.player.id).toSet().length != entries.length ||
        entries.any(
          (e) => e.stars < 1 || e.stars > 5 || e.review.characters.length > 300,
        )) {
      throw const RatingFailure('Rate every teammate from 1 to 5 stars.');
    }
    _sending = true;
    notifyListeners();
    try {
      final match = Map<String, dynamic>.from(
        await api.request('/matches/$id') as Map,
      );
      if (match['status'] != 'COMPLETED') {
        throw const RatingFailure('The host must complete this match first.');
      }
      final roster = match['participants'] as List? ?? [];
      if (!roster.any(
        (p) => p['userId'] == api.userId && p['status'] == 'ACCEPTED',
      )) {
        throw const RatingFailure(
          'Only accepted match participants can submit feedback.',
        );
      }
      final eligible = roster
          .where((p) => p['status'] == 'ACCEPTED' && p['userId'] != api.userId)
          .map((p) => '${p['userId']}')
          .toSet();
      if (entries.any((e) => !eligible.contains(e.player.id))) {
        throw const RatingFailure('Invalid teammate for this match.');
      }
      final existing = await api.ratings(given: true);
      final sent = existing
          .where((r) => r['matchId'] == id)
          .map((r) => '${r['ratedUserId']}')
          .toSet();
      if (!eligible.every(
        (p) => sent.contains(p) || entries.any((e) => e.player.id == p),
      )) {
        throw const RatingFailure('Rate every remaining teammate.');
      }
      if (entries.every((e) => sent.contains(e.player.id))) {
        throw StateError('Feedback has already been sent.');
      }
      for (final entry in entries) {
        if (sent.contains(entry.player.id)) continue;
        await api.request(
          '/ratings',
          method: 'POST',
          data: {
            'matchId': id,
            'ratedUserId': int.parse(entry.player.id),
            'score': entry.stars,
            if (entry.review.trim().isNotEmpty) 'comment': entry.review.trim(),
          },
        );
        ratingRevision.value++;
      }
      _sent.add(matchId);
      await refresh();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
