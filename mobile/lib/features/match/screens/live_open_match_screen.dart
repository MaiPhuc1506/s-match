import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../auth/services/auth_service.dart';
import '../../feedback/data/feedback_repository.dart';
import '../../feedback/screens/live_match_feedback_screen.dart';
import '../services/open_match_service.dart';
import 'open_match_nearby_screen.dart';

/// Uses authenticated match details, including organizer-only request data.
class LiveOpenMatchScreen extends StatefulWidget {
  const LiveOpenMatchScreen({super.key, required this.matchId});
  final int matchId;
  @override
  State<LiveOpenMatchScreen> createState() => _LiveOpenMatchScreenState();
}

class _LiveOpenMatchScreenState extends State<LiveOpenMatchScreen> {
  final service = OpenMatchService();
  late Future<Map<String, dynamic>> match = service.detail(widget.matchId);
  bool busy = false;
  void refresh() => setState(() {
    match = service.detail(widget.matchId);
  });
  Future<void> act(
    Future<void> Function() action, {
    String successMessage = 'Request updated.',
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      refresh();
    } catch (error) {
      if (mounted) {
        final data = error is DioException ? error.response?.data : null;
        final message = data is Map ? data['message'] : null;
        final text = message is String ? message.toLowerCase() : '';
        final explanation =
            text.contains('already started') || text.contains('đã bắt đầu')
            ? 'This match has started. Pending requests can no longer be approved.'
            : text.contains('skill level')
            ? message as String
            : text.contains('full') || text.contains('đủ')
            ? 'This match is already full.'
            : text.contains('no longer exists') ||
                  text.contains('không tìm thấy yêu cầu')
            ? 'That request was already handled. The list has been refreshed.'
            : 'Unable to update request. Refresh and try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(explanation)));
        // Drop stale request/participant state after a rejected mutation.
        refresh();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Open Match')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: match,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: refresh,
              child: const Text('Unable to load match. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final m = snapshot.data!;
        final booking = m['booking'] is Map ? m['booking'] as Map : const {};
        final court = booking['court'] is Map
            ? booking['court'] as Map
            : const {};
        final facility = court['facility'] is Map
            ? court['facility'] as Map
            : const {};
        final host =
            (m['hostId'] as num?)?.toInt() ==
            (AuthService.instance.currentUser?['id'] as num?)?.toInt();
        final start = DateTime.tryParse('${m['startTime'] ?? ''}')
            ?.toUtc()
            .add(const Duration(hours: 7));
        final end = DateTime.tryParse('${m['endTime'] ?? ''}')
            ?.toUtc()
            .add(const Duration(hours: 7));
        final schedule = start == null || end == null
            ? 'Schedule unavailable'
            : '${'${MaterialLocalizations.of(context).formatMediumDate(start)} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'}–${'${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'}';
        final startsAt = DateTime.tryParse('${m['startTime'] ?? ''}');
        final started = startsAt != null && !startsAt.isAfter(DateTime.now());
        final status = '${m['status'] ?? ''}';
        final participantCount = (m['participantCount'] as num? ?? 0).toInt();
        final maxPlayers = (m['maxPlayers'] as num? ?? 0).toInt();
        final admissionOpen =
            status == 'OPEN' && !started && participantCount < maxPlayers;
        final canReviewRequests =
            host &&
            !started &&
            (status == 'OPEN' || status == 'FULL') &&
            participantCount < maxPlayers;
        final requests = (m['participants'] as List? ?? [])
            .whereType<Map>()
            .where((p) => p['status'] == 'REQUESTED');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${m['title'] ?? 'Open Match'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('${facility['name'] ?? ''} · ${court['name'] ?? ''}'),
            Text(schedule),
            if (m['description'] is String &&
                (m['description'] as String).isNotEmpty)
              Text(m['description'] as String),
            Text(
              '${m['mode'] ?? ''} · Skill ${m['minSkillLevel'] ?? '—'}–${m['maxSkillLevel'] ?? '—'}',
            ),
            Text(
              '${m['participantCount'] ?? '—'} / ${m['maxPlayers'] ?? '—'} players',
            ),
            if (!host && m['myStatus'] != null)
              Text('Your status: ${m['myStatus']}'),
            const SizedBox(height: 16),
            if (startsAt != null && started)
              const Text(
                'This match has started. New participants cannot join.',
              ),
            if (!host && m['myStatus'] == 'INVITED') ...[
              FilledButton(
                onPressed: busy || !admissionOpen
                    ? null
                    : () => act(() => service.invitation(widget.matchId, true)),
                child: const Text('Accept invitation'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () =>
                          act(() => service.invitation(widget.matchId, false)),
                child: const Text('Decline'),
              ),
            ] else if (!host && m['myStatus'] == 'ACCEPTED')
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => act(() => service.leave(widget.matchId)),
                child: const Text('Leave match'),
              )
            else if (!host)
              FilledButton(
                onPressed:
                    busy ||
                        !admissionOpen ||
                        m['myStatus'] == 'REQUESTED' ||
                        m['myStatus'] == 'ACCEPTED'
                    ? null
                    : () => act(() => service.request(widget.matchId)),
                child: const Text('Request to Join'),
              ),
            if (m['status'] == 'COMPLETED' &&
                (m['myStatus'] == 'ACCEPTED' ||
                    (m['participants'] as List? ?? []).whereType<Map>().any(
                      (p) =>
                          p['userId'] ==
                              AuthService.instance.currentUser?['id'] &&
                          p['status'] == 'ACCEPTED',
                    ))) ...[
              OutlinedButton(
                onPressed: () {
                  final repository = FeedbackRepository.active;
                  if (repository is! ApiFeedbackRepository) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveMatchFeedbackScreen(
                        matchId: '${widget.matchId}',
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: const Text('Give feedback'),
              ),
            ],
            if (host) ...[
              if (startsAt != null &&
                  !startsAt.isAfter(DateTime.now()) &&
                  ['OPEN', 'FULL', 'IN_PROGRESS'].contains(m['status']))
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await showCupertinoDialog<bool>(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text('Finish this match?'),
                              content: const Text(
                                'This will complete the match and notify participants. '
                                'Your court booking will remain unchanged. '
                                'Eligible participants can give feedback immediately.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep playing'),
                                ),
                                CupertinoDialogAction(
                                  isDefaultAction: true,
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Finish Match'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted && !busy) {
                            await act(
                              () => service.complete(widget.matchId),
                              successMessage: 'Match completed.',
                            );
                          }
                        },
                  child: const Text('Finish Match'),
                ),
              if (admissionOpen)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OpenMatchNearbyScreen(
                        matchId: widget.matchId,
                        excludedIds: (m['participants'] as List? ?? [])
                            .whereType<Map>()
                            .where(
                              (p) => [
                                'ACCEPTED',
                                'INVITED',
                                'REQUESTED',
                              ].contains(p['status']),
                            )
                            .map((p) => (p['userId'] as num).toInt())
                            .toSet(),
                      ),
                    ),
                  ),
                  child: const Text('Find Nearby Players'),
                ),
              if (m['status'] == 'OPEN' || m['status'] == 'FULL')
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await showCupertinoDialog<bool>(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text('Cancel this match?'),
                              content: const Text(
                                'Your court booking will remain confirmed.',
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep match'),
                                ),
                                CupertinoDialogAction(
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Cancel match'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await act(() => service.cancel(widget.matchId));
                          }
                        },
                  child: const Text('Cancel match'),
                ),
              Text(
                'Join requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (requests.isEmpty) const Text('No pending requests.'),
              if (requests.isNotEmpty && !canReviewRequests)
                Text(
                  started
                      ? 'This match has started. Pending requests can no longer be approved.'
                      : status == 'FULL' || participantCount >= maxPlayers
                      ? 'This match is full. Pending requests can no longer be approved.'
                      : 'This match is no longer accepting participants.',
                ),
              for (final p in requests)
                ListTile(
                  title: Text(
                    '${(p['user'] is Map ? p['user']['fullName'] : null) ?? 'Player'}',
                  ),
                  trailing: canReviewRequests
                      ? Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: busy
                                  ? null
                                  : () => act(
                                      () => service.respond(
                                        widget.matchId,
                                        (p['id'] as num).toInt(),
                                        false,
                                      ),
                                    ),
                              icon: const Icon(Icons.close),
                            ),
                            IconButton(
                              tooltip: 'Accept',
                              onPressed: busy
                                  ? null
                                  : () => act(
                                      () => service.respond(
                                        widget.matchId,
                                        (p['id'] as num).toInt(),
                                        true,
                                      ),
                                    ),
                              icon: const Icon(Icons.check),
                            ),
                          ],
                        )
                      : Text('${p['status'] ?? ''}'),
                ),
            ],
          ],
        );
      },
    ),
  );
}
