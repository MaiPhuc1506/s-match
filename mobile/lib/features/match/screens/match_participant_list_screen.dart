import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_model.dart';
import '../state/match_ui_store.dart';

/// Participant list shown in Figma frame 413:1055.
class MatchParticipantListScreen extends StatelessWidget {
  final MatchItem? match;
  final VoidCallback? onBack;
  final ValueChanged<int>? onParticipantAction;

  const MatchParticipantListScreen({
    super.key,
    this.match,
    this.onBack,
    this.onParticipantAction,
  });

  static const _ratingOrange = Color(0xFFFFEDCE);

  static const _sampleParticipants = [
    _ParticipantEntry(
      name: 'Nguyễn Văn A',
      level: 'Advanced',
      rating: '4.5',
      avatar: 'assets/images/match/host_portrait.png',
      isHost: true,
    ),
    _ParticipantEntry(
      name: 'Trần Thị B',
      level: 'Intermediate',
      rating: '4.0',
      avatar: 'assets/images/match/participant_list_tran.png',
    ),
    _ParticipantEntry(
      name: 'Lê Minh C',
      level: 'Intermediate',
      rating: '3.8',
      avatar: 'assets/images/match/participant_list_le.png',
    ),
    _ParticipantEntry(
      name: 'Phạm Hoàng',
      level: 'Intermediate',
      rating: '3.9',
      initials: 'PH',
    ),
  ];

  List<_ParticipantEntry> get _participants => match == null
      ? _sampleParticipants
      : MatchUiStore.instance
            .participantsFor(match!)
            .map(
              (p) => _ParticipantEntry(
                name: p.name,
                level: match!.skillLevel,
                rating: p.rating ?? '—',
                avatar: p.avatarAsset,
                initials: p.initials,
                isHost: p.role == 'Host',
              ),
            )
            .toList();

  Future<void> _remove(BuildContext context, int index) async {
    if (onParticipantAction != null) {
      onParticipantAction!(index);
      return;
    }
    if (match?.isHost != true) return;
    final person = MatchUiStore.instance.participantsFor(match!)[index];
    if (person.role == 'Host') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove participant?'),
        content: Text(person.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      MatchUiStore.instance.removeParticipant(match!, person.id);
    }
  }

  TextStyle _text(double size, FontWeight weight, Color color) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: MatchUiStore.instance,
    builder: (context, _) => Scaffold(
      backgroundColor: MatchColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      match == null
                          ? 'Participants (4/4)'
                          : 'Participants (${_participants.length}/${match!.draft?.requiredPlayers ?? match!.players.split('/').last.split(' ').first})',
                      style: _text(17, FontWeight.w700, MatchColors.darkText),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: IconButton(
                      tooltip: 'Back',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: MatchColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    for (var i = 0; i < _participants.length; i++) ...[
                      _participantRow(context, _participants[i], i),
                      if (i < _participants.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _participantRow(
    BuildContext context,
    _ParticipantEntry person,
    int index,
  ) => Container(
    height: 52,
    width: double.infinity,
    decoration: BoxDecoration(
      color: person.isHost ? MatchColors.lightGreen : MatchColors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 12,
          top: 9,
          child: ClipOval(
            child: Container(
              width: 34,
              height: 34,
              color: MatchColors.lightGreen,
              child: person.avatar == null
                  ? Center(
                      child: Text(
                        person.initials!,
                        style: _text(
                          13,
                          FontWeight.w700,
                          MatchColors.primaryGreen,
                        ),
                      ),
                    )
                  : Image.asset(person.avatar!, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          left: 54,
          right: 105,
          top: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(12, FontWeight.w600, MatchColors.darkText),
              ),
              const SizedBox(height: 2),
              Text(
                person.level,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(10, FontWeight.w400, MatchColors.mutedText),
              ),
            ],
          ),
        ),
        if (person.isHost)
          Positioned(
            left: 142,
            top: 19,
            child: Text(
              'Host',
              style: _text(10, FontWeight.w600, MatchColors.primaryGreen),
            ),
          ),
        Positioned(
          right: 49,
          top: 16,
          child: Container(
            width: 40,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: person.isHost ? MatchColors.lightGreen : _ratingOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              person.rating,
              style: _text(10, FontWeight.w600, MatchColors.darkText),
            ),
          ),
        ),
        if (!person.isHost &&
            (match?.isHost == true || onParticipantAction != null))
          Positioned(
            right: 15,
            top: 6,
            child: InkWell(
              onTap: () => _remove(context, index),
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 24,
                height: 40,
                child: Center(
                  child: Text(
                    '⋮',
                    style: _text(10, FontWeight.w600, MatchColors.darkText),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ParticipantEntry {
  final String name;
  final String level;
  final String rating;
  final String? avatar;
  final String? initials;
  final bool isHost;

  const _ParticipantEntry({
    required this.name,
    required this.level,
    required this.rating,
    this.avatar,
    this.initials,
    this.isHost = false,
  });
}
