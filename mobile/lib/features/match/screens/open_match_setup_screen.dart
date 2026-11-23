import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/open_match_service.dart';
import 'live_open_match_screen.dart';

/// Creates a match only after a real booking has been confirmed.
class OpenMatchSetupScreen extends StatefulWidget {
  const OpenMatchSetupScreen({
    super.key,
    required this.bookingId,
    required this.courtLabel,
    required this.timeLabel,
  });
  final int bookingId;
  final String courtLabel, timeLabel;
  @override
  State<OpenMatchSetupScreen> createState() => _OpenMatchSetupScreenState();
}

class _OpenMatchSetupScreenState extends State<OpenMatchSetupScreen> {
  String mode = 'DOUBLES';
  int capacity = 4, minSkill = 1, maxSkill = 5;
  bool loading = false;
  final note = TextEditingController();
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  String? error;
  Future<void> submit() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await OpenMatchService().create(
        bookingId: widget.bookingId,
        mode: mode,
        capacity: capacity,
        minSkill: minSkill,
        maxSkill: maxSkill,
        description: note.text.trim(),
      );
      final id = (result['id'] as num).toInt();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LiveOpenMatchScreen(matchId: id),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Your booking is confirmed, but the match was not created. Retry or check your bookings.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Organize Open Match')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.courtLabel, style: Theme.of(context).textTheme.titleLarge),
        Text(widget.timeLabel),
        const SizedBox(height: 20),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: mode,
          children: const {
            'SINGLES': Text('Singles'),
            'DOUBLES': Text('Doubles'),
          },
          onValueChanged: (value) {
            if (value != null) {
              setState(() {
                mode = value;
                capacity = value == 'SINGLES' ? 2 : 4;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        Text('Total capacity: $capacity players (including you)'),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: minSkill,
          decoration: const InputDecoration(labelText: 'Minimum skill (1–5)'),
          items: [
            for (var i = 1; i <= 5; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                minSkill = v;
                if (maxSkill < v) maxSkill = v;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Preferences (optional)',
          ),
        ),
        DropdownButtonFormField<int>(
          key: ValueKey(minSkill),
          initialValue: maxSkill,
          decoration: const InputDecoration(labelText: 'Maximum skill (1–5)'),
          items: [
            for (var i = minSkill; i <= 5; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => maxSkill = v);
          },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: loading ? null : submit,
          child: Text(loading ? 'Creating…' : 'Create Open Match'),
        ),
      ],
    ),
  );
}
