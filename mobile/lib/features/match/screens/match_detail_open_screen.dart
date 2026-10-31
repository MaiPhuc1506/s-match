import '../../../core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/services/auth_service.dart';
import '../models/match_model.dart';
import '../state/match_ui_store.dart';
import 'match_participant_list_screen.dart';

/// Open match detail, Figma 413:949.
class MatchDetailOpenScreen extends StatelessWidget {
  final MatchItem? match;
  final MatchDraft? draft;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onSeeAllParticipants;
  final VoidCallback? onJoinMatch;

  const MatchDetailOpenScreen({
    super.key,
    this.match,
    this.draft,
    this.onBack,
    this.onShare,
    this.onSeeAllParticipants,
    this.onJoinMatch,
  });

  MatchUiStore get _store => MatchUiStore.instance;

  String get _actionLabel {
    if (match?.isHost == true) {
      return draft?.isPrivate == true
          ? 'Invite Players'
          : 'Manage Participants';
    }
    if (match != null && _store.joined.contains(match!.id)) {
      return 'View Participants';
    }
    if (match != null && _store.pending.contains(match!.id)) {
      return 'Request sent';
    }
    return draft?.isPrivate == true ? 'Invite Players' : 'Join Match';
  }

  Future<void> _action(BuildContext context) async {
    if (onJoinMatch != null) {
      onJoinMatch!();
      return;
    }
    final item = match;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a match from the list first.')),
      );
      return;
    }
    if (item.isHost && draft?.isPrivate == true) {
      final currentUser = AuthService.instance.currentUser;
      final currentEmail = currentUser?['email']?.toString().toLowerCase() ?? 'player@smatch.dev';
      final currentName = currentUser?['fullName'] ?? 'Demo Player';

      final candidates = [
        {'name': 'Demo Player (Player 01)', 'email': 'player@smatch.dev'},
        {'name': 'Demo Player 2 (Player 02)', 'email': 'player2@smatch.dev'},
        {'name': 'Demo Player 3', 'email': 'player3@smatch.dev'},
        {'name': 'Demo Player 4', 'email': 'player4@smatch.dev'},
      ].where((c) => c['email']!.toLowerCase() != currentEmail).toList();

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: MatchColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => ListenableBuilder(
          listenable: _store,
          builder: (sheetCtx, _) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 12, bottom: 12 + MediaQuery.viewInsetsOf(sheetCtx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Mời người chơi tham gia trận',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(),
                  for (final c in candidates) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: MatchColors.primaryGreen.withOpacity(0.12),
                        child: Text(
                          c['name']![0],
                          style: const TextStyle(
                            color: MatchColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(c['name']!),
                      subtitle: Text(c['email']!),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _store.sentInvitations.contains('${item.id}:${c['email']}')
                              ? Colors.grey.shade200
                              : MatchColors.primaryGreen,
                          foregroundColor: _store.sentInvitations.contains('${item.id}:${c['email']}')
                              ? Colors.grey.shade700
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _store.sentInvitations.contains('${item.id}:${c['email']}')
                            ? null
                            : () {
                                _store.sendInvitation(
                                  match: item,
                                  inviterName: currentName,
                                  inviterEmail: currentEmail,
                                  inviteeEmail: c['email']!,
                                );
                              },
                        child: Text(
                          _store.sentInvitations.contains('${item.id}:${c['email']}')
                              ? 'Đã mời'
                              : 'Mời ngay',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
    if (item.isHost || _store.joined.contains(item.id)) {
      _openParticipants(context);
      return;
    }
    final sent = _store.requestJoin(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Join request sent (UI demo).'
              : _store.pending.contains(item.id)
              ? 'Your request is pending.'
              : 'This match is full or unavailable.',
        ),
      ),
    );
    if (sent) Navigator.maybePop(context);
  }

  void _openParticipants(BuildContext context) {
    if (onSeeAllParticipants != null) {
      onSeeAllParticipants!();
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => MatchParticipantListScreen(match: match),
        transitionDuration: AppMotion.duration(context, 200),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  TextStyle _style(double size, FontWeight weight, Color color) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => Scaffold(
      backgroundColor: MatchColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 55,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Text(
                        '‹',
                        style: _style(
                          28,
                          FontWeight.w400,
                          MatchColors.darkText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/match/facility_court.jpg',
                        width: double.infinity,
                        height: 112,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 23,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 30),
                            child: Text(
                              draft?.title ??
                                  match?.title ??
                                  'Weekend Doubles Fun',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _style(
                                18,
                                FontWeight.w700,
                                MatchColors.darkText,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 3,
                            top: 5,
                            child: InkWell(
                              onTap: onShare,
                              child: SvgPicture.asset(
                                'assets/icons/match_share.svg',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 110,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: draft?.isPrivate == true
                            ? MatchColors.lightGreen
                            : MatchColors.blueBadge,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        draft?.isPrivate == true
                            ? 'Private Match'
                            : 'Open Match',
                        style: _style(
                          11,
                          FontWeight.w600,
                          MatchColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      draft?.description ?? 'Casual match, all are welcome! 🏸',
                      style: _style(12, FontWeight.w400, MatchColors.mutedText),
                    ),
                    const SizedBox(height: 12),
                    _divider(),
                    const SizedBox(height: 12),
                    _infoRow(
                      'assets/icons/match_date.svg',
                      match?.time ?? 'Sun, 20 Sep 2026 · 19:00 – 21:00',
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      'assets/icons/match_court.svg',
                      match?.facility ?? 'Sunrise Badminton Club · Da Nang',
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      'assets/icons/match_game.svg',
                      draft == null
                          ? 'Doubles (4 players)'
                          : '${draft!.gameType} (${draft!.requiredPlayers} players)',
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      'assets/icons/match_skill.svg',
                      draft?.skillLevel ?? match?.skillLevel ?? 'Intermediate',
                    ),
                    const SizedBox(height: 12),
                    _divider(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 16,
                      child: Text(
                        'Host',
                        style: _style(
                          13,
                          FontWeight.w700,
                          MatchColors.darkText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _hostRow(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _openParticipants(context),
                            child: Text(
                              match == null
                                  ? 'Participants (3/4)'
                                  : 'Participants (${_store.participantsFor(match!).length}/${draft?.requiredPlayers ?? match!.players.split('/').last.split(' ').first})',
                              style: _style(
                                13,
                                FontWeight.w700,
                                MatchColors.darkText,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _openParticipants(context),
                            child: Text(
                              'See all',
                              style: _style(
                                13,
                                FontWeight.w700,
                                MatchColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _participants(context),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: Material(
                        color: MatchColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => _action(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Center(
                            child: Text(
                              _actionLabel,
                              style: _style(
                                13,
                                FontWeight.w600,
                                MatchColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _divider() => Container(height: 1, color: MatchColors.border);

  Widget _infoRow(String icon, String label) => SizedBox(
    height: 34,
    child: Row(
      children: [
        SvgPicture.asset(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(12, FontWeight.w500, MatchColors.darkText),
          ),
        ),
      ],
    ),
  );

  Widget _hostRow() => Container(
    width: 320,
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: MatchColors.lightGreen,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/match/host_portrait.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match?.isHost == true ? 'You' : 'Nguyễn Văn A',
              style: _style(12, FontWeight.w600, MatchColors.darkText),
            ),
            const SizedBox(height: 2),
            Text(
              'Intermediate · 4.5',
              style: _style(10, FontWeight.w400, MatchColors.mutedText),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          'Host',
          style: _style(10, FontWeight.w600, MatchColors.primaryGreen),
        ),
      ],
    ),
  );

  Widget _participants(BuildContext context) {
    final people = match == null
        ? kVerifiedParticipants.where((p) => !p.isJoinSlot).toList()
        : _store.participantsFor(match!);
    return InkWell(
      onTap: () => _openParticipants(context),
      child: SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: people.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final person = people[index];
            return SizedBox(
              width: 64,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: MatchColors.lightGreen,
                    backgroundImage: person.avatarAsset == null
                        ? null
                        : AssetImage(person.avatarAsset!),
                    child: person.avatarAsset == null
                        ? Text(person.initials)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: _style(8, FontWeight.w700, MatchColors.darkText),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
