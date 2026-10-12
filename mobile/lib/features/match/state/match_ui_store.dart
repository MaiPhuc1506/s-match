import 'package:flutter/foundation.dart';

import '../models/match_model.dart';

/// Session-only UI demo state. No requests are sent to a server.
class MatchUiStore extends ChangeNotifier {
  static final instance = MatchUiStore();
  final List<MatchItem> _matches = [];
  final Set<String> pending = {};
  final Set<String> joined = {};
  final Set<int> resolvedInvitations = {};
  final Set<int> resolvedRequests = {};
  final Set<String> sentInvitations = {};
  int _sequence = 0;
  final Map<String, List<ParticipantItem>> _participants = {};

  List<ParticipantItem> participantsFor(MatchItem item) => List.unmodifiable(
    _participants.putIfAbsent(
      item.id,
      () => item.isHost
          ? [
              const ParticipantItem(
                id: 'self',
                name: 'You',
                initials: 'You',
                role: 'Host',
              ),
            ]
          : kVerifiedParticipants
                .where((p) => !p.isJoinSlot)
                .take(int.parse(item.players.split('/').first))
                .toList(),
    ),
  );

  void removeParticipant(MatchItem item, String id) {
    if (!item.isHost || id == 'self') return;
    participantsFor(item);
    _participants[item.id]!.removeWhere((person) => person.id == id);
    notifyListeners();
  }

  MatchUiStore({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    for (var i = 0; i < kVerifiedMatches.length; i++) {
      final item = kVerifiedMatches[i];
      final date = today.add(Duration(days: i == 3 ? 2 : 0));
      _matches.add(
        MatchItem(
          id: item.id,
          title: item.title,
          skillLevel: item.skillLevel,
          badgeBg: item.badgeBg,
          badgeTextColor: item.badgeTextColor,
          badgeWidth: item.badgeWidth,
          time: '${dateLabel(date)} · ${item.time.split(' · ').last}',
          facility: item.facility,
          players: item.players,
          distance: item.distance,
          date: date,
        ),
      );
    }
    _matches.add(
      MatchItem(
        id: 'request_demo',
        title: 'Weekend Doubles Fun',
        skillLevel: 'Intermediate',
        badgeBg: MatchColors.badgeIntermediate,
        badgeTextColor: MatchColors.textIntermediate,
        badgeWidth: 88,
        time: '${dateLabel(today)} · 19:00 – 21:00',
        facility: 'Sunrise Badminton Club',
        players: '1/4 players',
        distance: '',
        date: today,
        isHost: true,
      ),
    );
  }

  static String dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  List<MatchItem> get matches => List.unmodifiable(_matches);
  MatchItem? find(String id) {
    for (final item in _matches) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isMine(MatchItem item) =>
      item.isHost || joined.contains(item.id) || pending.contains(item.id);

  List<MatchItem> visible({
    required bool mine,
    required bool todayOnly,
    String? level,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final end = today.add(Duration(days: todayOnly ? 1 : 7));
    return _matches.where((item) {
      final date = item.date ?? today;
      return (mine
              ? isMine(item)
              : item.draft?.isPrivate != true && !item.isHost) &&
          !date.isBefore(today) &&
          date.isBefore(end) &&
          (level == null || item.skillLevel == level);
    }).toList();
  }

  MatchItem create(MatchDraft draft) {
    final item = MatchItem(
      id: 'local_${++_sequence}',
      title: draft.title,
      skillLevel: draft.skillLevel,
      badgeBg: draft.skillLevel == 'Advanced'
          ? MatchColors.badgeAdvanced
          : draft.skillLevel == 'Beginner'
          ? MatchColors.badgeBeginner
          : MatchColors.badgeIntermediate,
      badgeTextColor: draft.skillLevel == 'Advanced'
          ? MatchColors.textAdvanced
          : draft.skillLevel == 'Beginner'
          ? MatchColors.textBeginner
          : MatchColors.textIntermediate,
      badgeWidth: 88,
      time: '${dateLabel(DateTime.now())} · 19:00 – 21:00',
      facility: 'Sunrise Badminton Club',
      players: '1/${draft.requiredPlayers} players',
      distance: '',
      date: DateTime.now(),
      draft: draft,
      isHost: true,
    );
    _matches.insert(0, item);
    notifyListeners();
    return item;
  }

  bool requestJoin(MatchItem item) {
    if (item.isHost ||
        item.draft?.isPrivate == true ||
        joined.contains(item.id) ||
        pending.contains(item.id)) {
      return false;
    }
    final counts = item.players.split(' ').first.split('/');
    if (counts.length == 2 && int.parse(counts[0]) >= int.parse(counts[1])) {
      return false;
    }
    pending.add(item.id);
    notifyListeners();
    return true;
  }

  void respondInvitation(int index, {required bool accept}) {
    if (!resolvedInvitations.add(index)) return;
    if (accept) {
      final item = create(
        MatchDraft(
          title: index == 0 ? 'Team Practice' : 'Evening Doubles',
          description: 'Invitation accepted in UI demo.',
          isPrivate: true,
          gameType: 'Doubles',
          requiredPlayers: 4,
          skillLevel: 'Intermediate',
        ),
      );
      final replacement = MatchItem(
        id: item.id,
        title: item.title,
        skillLevel: item.skillLevel,
        badgeBg: item.badgeBg,
        badgeTextColor: item.badgeTextColor,
        badgeWidth: item.badgeWidth,
        time: item.time,
        facility: item.facility,
        players: '2/4 players',
        distance: '',
        date: item.date,
        draft: item.draft,
      );
      _matches[_matches.indexOf(item)] = replacement;
      joined.add(item.id);
      _participants[item.id] = [
        kVerifiedParticipants.first,
        const ParticipantItem(id: 'self', name: 'You', initials: 'You'),
      ];
    }
    notifyListeners();
  }

  void respondRequest(int index, {required bool accept}) {
    if (resolvedRequests.contains(index)) return;
    if (accept) {
      final item = find('request_demo')!;
      participantsFor(item);
      _participants[item.id]!.add(
        ParticipantItem(
          id: 'request_$index',
          name: index == 0 ? 'Trần Minh' : 'Nguyễn Thảo',
          initials: index == 0 ? 'TM' : 'NT',
        ),
      );
    }
    resolvedRequests.add(index);
    notifyListeners();
  }

  void invite(String matchId, String player) {
    sentInvitations.add('$matchId:$player');
    notifyListeners();
  }
}
