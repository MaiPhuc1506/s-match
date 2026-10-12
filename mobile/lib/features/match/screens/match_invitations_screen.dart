import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_model.dart';
import '../state/match_ui_store.dart';
import 'match_join_requests_screen.dart';

/// Figma 413:1031 — Invitations tab of Match Requests.
class MatchInvitationsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onJoinRequests;
  final ValueChanged<int>? onDecline;
  final ValueChanged<int>? onAccept;

  const MatchInvitationsScreen({
    super.key,
    this.onBack,
    this.onJoinRequests,
    this.onDecline,
    this.onAccept,
  });

  void _respond(BuildContext context, int index, bool accept) {
    final callback = accept ? onAccept : onDecline;
    if (callback != null) {
      callback(index);
      return;
    }
    MatchUiStore.instance.respondInvitation(index, accept: accept);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(accept ? 'Accepted (UI demo).' : 'Declined (UI demo).'),
      ),
    );
  }

  static const _red = Color(0xFFFA635E);

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
                      'Match Requests',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(17, FontWeight.w700, MatchColors.darkText),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: InkWell(
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Text(
                            '‹',
                            style: _text(
                              28,
                              FontWeight.w400,
                              MatchColors.darkText,
                            ),
                          ),
                        ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: MatchColors.primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Invitations',
                                style: _text(
                                  12,
                                  FontWeight.w600,
                                  MatchColors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap:
                                  onJoinRequests ??
                                  () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const MatchJoinRequestsScreen(),
                                    ),
                                  ),
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 34,
                                child: Center(
                                  child: Text(
                                    'Join Requests ${2 - MatchUiStore.instance.resolvedRequests.length}',
                                    style: _text(
                                      12,
                                      FontWeight.w600,
                                      MatchColors.mutedText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 16,
                      child: Text(
                        'Invitations (${2 - MatchUiStore.instance.resolvedInvitations.length})',
                        style: _text(13, FontWeight.w700, MatchColors.darkText),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!MatchUiStore.instance.resolvedInvitations.contains(0))
                      _invitationCard(
                        context: context,
                        index: 0,
                        inviter: 'Lê Thị D',
                        initials: 'LD',
                        portrait: 'assets/images/match/invitation_le_thi_d.png',
                        title: 'Team Practice',
                      ),
                    const SizedBox(height: 12),
                    if (!MatchUiStore.instance.resolvedInvitations.contains(1))
                      _invitationCard(
                        context: context,
                        index: 1,
                        inviter: 'Phạm Hoàng',
                        initials: 'PH',
                        title: 'Evening Doubles',
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

  Widget _invitationCard({
    required BuildContext context,
    required int index,
    required String inviter,
    required String initials,
    required String title,
    String? portrait,
  }) => Container(
    width: double.infinity,
    height: 164,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: MatchColors.white,
      border: Border.all(color: MatchColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 34,
                  height: 34,
                  color: MatchColors.lightGreen,
                  child: portrait == null
                      ? Center(
                          child: Text(
                            initials,
                            style: _text(
                              13,
                              FontWeight.w700,
                              MatchColors.primaryGreen,
                            ),
                          ),
                        )
                      : Image.asset(portrait, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$inviter · invited you to join',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(12, FontWeight.w600, MatchColors.darkText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/match/facility_court.jpg',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(13, FontWeight.w700, MatchColors.darkText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tue, 23 Sep · 18:00 – 20:00',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(11, FontWeight.w400, MatchColors.mutedText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ace Badminton Hall',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(11, FontWeight.w400, MatchColors.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 152,
                height: 40,
                child: InkWell(
                  onTap: () => _respond(context, index, false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: _red),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Decline',
                      style: _text(13, FontWeight.w600, _red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 152,
                height: 40,
                child: InkWell(
                  onTap: () => _respond(context, index, true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MatchColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Accept',
                      style: _text(13, FontWeight.w600, MatchColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
