import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../data/feedback_repository.dart';
import '../widgets/feedback_widgets.dart';
import 'match_completed_screen.dart';

/// Opens a real pending match. Completion is explicit and authorized by the API;
/// simply viewing the Celebration screen never changes server match state.
class LiveMatchFeedbackScreen extends StatefulWidget {
  const LiveMatchFeedbackScreen({
    super.key,
    required this.matchId,
    required this.repository,
  });
  final String matchId;
  final ApiFeedbackRepository repository;
  @override
  State<LiveMatchFeedbackScreen> createState() =>
      _LiveMatchFeedbackScreenState();
}

class _LiveMatchFeedbackScreenState extends State<LiveMatchFeedbackScreen> {
  Map<String, dynamic>? match;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool complete = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = widget.repository.api;
      if (complete) {
        await api.request(
          '/matches/${widget.matchId}/complete',
          method: 'PATCH',
        );
      }
      final data = Map<String, dynamic>.from(
        await api.request('/matches/${widget.matchId}') as Map,
      );
      if (!mounted) return;
      if (data['status'] == 'COMPLETED') {
        final model = FeedbackMatch.fromJson(data, api.userId);
        final accepted = (data['participants'] as List? ?? []).any(
          (p) => p['userId'] == api.userId && p['status'] == 'ACCEPTED',
        );
        if (!accepted) {
          throw StateError('Only accepted participants can rate this match.');
        }
        Navigator.of(context).pushReplacement(
          AppMotion.route(
            MatchCompletedScreen(repository: widget.repository, match: model),
          ),
        );
      } else {
        setState(() => match = data);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(match?['endTime'] as String? ?? '');
    final canComplete =
        match?['hostId'] == widget.repository.api.userId &&
        end != null &&
        !end.isAfter(DateTime.now()) &&
        ['OPEN', 'FULL', 'IN_PROGRESS'].contains(match?['status']);
    return FeedbackScaffold(
      title: 'Match feedback',
      subtitle: match?['title'] as String? ?? 'Loading match',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const Center(child: CircularProgressIndicator()),
          if (error != null) Text(error!, style: feedbackText(14)),
          if (!busy) ...[
            if (canComplete)
              FeedbackAction(
                'Complete Match',
                onPressed: () => load(complete: true),
              )
            else if (match != null)
              Text(
                'The host must complete this match before feedback can be submitted.',
                style: feedbackText(14),
              ),
            TextButton(onPressed: load, child: const Text('Refresh')),
          ],
        ],
      ),
    );
  }
}
