import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../widgets/sprint2_presentation.dart';

/// Ordered one-to-one with the server rubric: Smash, Defense, Net Play,
/// Stamina, Footwork and Serve. Each self-reported choice maps to 1–5.
class InitialSkillQuizScreen extends StatefulWidget {
  const InitialSkillQuizScreen({super.key});
  @override
  State<InitialSkillQuizScreen> createState() => _InitialSkillQuizScreenState();
}

class _InitialSkillQuizScreenState extends State<InitialSkillQuizScreen> {
  static const questions = [
    'Smash: How consistently can you hit an attacking smash into the court?',
    'Defense: How consistently can you return an opponent’s attacking shots?',
    'Net Play: How consistently can you control a shot close to the net?',
    'Stamina: How consistently can you maintain your play through long rallies?',
    'Footwork: How consistently can you reach shots and recover your position?',
    'Serve: How consistently can you place a legal serve where you intend?',
  ];
  static const options = [
    'Not yet',
    'Occasionally',
    'About half the time',
    'Usually',
    'Consistently',
  ];
  final answers = List<int?>.filled(6, null);
  final session = ApiClient.instance.sessionVersion;
  bool busy = false;

  Future<void> submit() async {
    if (busy || answers.any((answer) => answer == null)) return;
    final client = ApiClient.instance;
    if (client.token == null || session != client.sessionVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again and reopen the skill quiz.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await client.dio.post(
        '/players/skill-assessment/initial',
        data: {'answers': answers},
        options: Options(extra: {'expectedAuthToken': client.token}),
      );
      if (mounted && client.sessionVersion == session) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted && client.sessionVersion == session) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.statusCode == 409
                  ? 'A skill assessment already exists.'
                  : 'Could not save your estimate. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Sprint2Style.background,
    appBar: AppBar(title: const Text('Initial Skill Estimate')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'This self-assessment is an initial estimate, not a verified ranking.',
        ),
        for (var i = 0; i < questions.length; i++) ...[
          const SizedBox(height: 20),
          Text(questions[i]),
          DropdownButtonFormField<int>(
            initialValue: answers[i],
            hint: const Text('Choose an answer'),
            items: [
              for (var j = 0; j < options.length; j++)
                DropdownMenuItem(value: j, child: Text(options[j])),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() => answers[i] = value),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy || answers.any((a) => a == null) ? null : submit,
          child: Text(busy ? 'Saving…' : 'Save Initial Estimate'),
        ),
      ],
    ),
  );
}
