import 'package:flutter/material.dart';

/// Bảng màu chuẩn từ Figma Node 413:884
class MatchColors {
  MatchColors._();

  static const Color background = Color(0xFFF7F8F5);
  static const Color primaryGreen = Color(0xFF05644F);
  static const Color lightGreen = Color(0xFFDDF1E9);
  static const Color darkText = Color(0xFF0D2630);
  static const Color mutedText = Color(0xFF66706E);
  static const Color border = Color(0xFFD7DFDB);
  static const Color white = Color(0xFFFFFFFF);
  static const Color statusText = Color(0xFF0D1414);

  // Skill badge background colors
  static const Color badgeIntermediate = Color(0xFFEEE3FA);
  static const Color badgeAdvanced = Color(0xFFFFE2E0);
  static const Color badgeBeginner = Color(0xFFDDF1E9);
  static const Color badgeAllLevels = Color(0xFFDDEFFF);
  static const Color blueBadge = Color(0xFFDDEFFF);

  // Skill badge text colors
  static const Color textIntermediate = Color(0xFF6B46C1);
  static const Color textAdvanced = Color(0xFFE2544B);
  static const Color textBeginner = Color(0xFF05644F);
  static const Color textAllLevels = Color(0xFF2674A8);
}

/// Model đại diện cho một thẻ trận đấu (Match Card)
class MatchItem {
  final String id;
  final String title;
  final String skillLevel;
  final Color badgeBg;
  final Color badgeTextColor;
  final double badgeWidth;
  final String time;
  final String facility;
  final String players;
  final String distance;
  final DateTime? date;
  final MatchDraft? draft;
  final bool isHost;

  const MatchItem({
    required this.id,
    required this.title,
    required this.skillLevel,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.badgeWidth,
    required this.time,
    required this.facility,
    required this.players,
    required this.distance,
    this.date,
    this.draft,
    this.isHost = false,
  });
}

/// Local form values for the Sprint 5 UI preview; not a persisted match.
class MatchDraft {
  final String title;
  final String description;
  final bool isPrivate;
  final String gameType;
  final int requiredPlayers;
  final String skillLevel;

  const MatchDraft({
    required this.title,
    required this.description,
    required this.isPrivate,
    required this.gameType,
    required this.requiredPlayers,
    required this.skillLevel,
  });
}

/// Dữ liệu 4 trận đấu chuẩn xác từ Figma Section 1.6
const List<MatchItem> kVerifiedMatches = [
  MatchItem(
    id: 'match_1',
    title: 'Friendly Doubles',
    skillLevel: 'Intermediate',
    badgeBg: MatchColors.badgeIntermediate,
    badgeTextColor: MatchColors.textIntermediate,
    badgeWidth: 88,
    time: 'Sun, 20 Sep · 19:00 – 20:00',
    facility: 'Sunrise Badminton Club',
    players: '3/4 players · 2.5 km',
    distance: '2.5 km',
  ),
  MatchItem(
    id: 'match_2',
    title: 'Men’s Doubles',
    skillLevel: 'Advanced',
    badgeBg: MatchColors.badgeAdvanced,
    badgeTextColor: MatchColors.textAdvanced,
    badgeWidth: 76,
    time: 'Sun, 20 Sep · 18:00 – 19:30',
    facility: 'Ace Badminton Hall',
    players: '1/4 players · 3.1 km',
    distance: '3.1 km',
  ),
  MatchItem(
    id: 'match_3',
    title: 'Casual Singles',
    skillLevel: 'Beginner',
    badgeBg: MatchColors.badgeBeginner,
    badgeTextColor: MatchColors.textBeginner,
    badgeWidth: 74,
    time: 'Sun, 20 Sep · 20:00 – 21:00',
    facility: 'Rally Point Sports Center',
    players: '2/2 players · 4.0 km',
    distance: '4.0 km',
  ),
  MatchItem(
    id: 'match_4',
    title: 'Weekend Fun Match',
    skillLevel: 'All Levels',
    badgeBg: MatchColors.badgeAllLevels,
    badgeTextColor: MatchColors.textAllLevels,
    badgeWidth: 74,
    time: 'Sat, 21 Sep · 16:00 – 18:00',
    facility: 'Skyline Badminton',
    players: '1/8 players · 5.2 km',
    distance: '5.2 km',
  ),
];

/// Model đại diện cho người tham gia trận đấu (Participant)
class ParticipantItem {
  final String id;
  final String name;
  final String? rating;
  final String role; // 'Host' hoặc 'Player'
  final String? avatarAsset;
  final String initials;
  final bool isJoinSlot;

  const ParticipantItem({
    required this.id,
    required this.name,
    this.rating,
    this.role = 'Player',
    this.avatarAsset,
    required this.initials,
    this.isJoinSlot = false,
  });

  String get caption {
    if (isJoinSlot) return 'Join';
    if (role == 'Host') return '$name\nHost · ${rating ?? ""}';
    if (rating != null && rating!.isNotEmpty) return '$name\n$rating';
    return name;
  }
}

/// Dữ liệu người tham gia chuẩn từ Figma Node 413:949
const List<ParticipantItem> kVerifiedParticipants = [
  ParticipantItem(
    id: 'p_1',
    name: 'Nguyễn Văn A',
    rating: '4.5',
    role: 'Host',
    avatarAsset: 'assets/images/match/participant_nguyen.png',
    initials: 'NA',
  ),
  ParticipantItem(
    id: 'p_2',
    name: 'Trần Thị B',
    rating: '4.0',
    role: 'Player',
    avatarAsset: 'assets/images/match/participant_tran.png',
    initials: 'TB',
  ),
  ParticipantItem(
    id: 'p_3',
    name: 'Lê Minh C',
    rating: '3.8',
    role: 'Player',
    avatarAsset: 'assets/images/match/participant_le.png',
    initials: 'MC',
  ),
  ParticipantItem(id: 'p_4', name: 'Join', initials: '+', isJoinSlot: true),
];
