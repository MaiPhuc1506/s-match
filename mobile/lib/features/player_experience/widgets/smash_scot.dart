import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../data/demo_catalog.dart';

/// Floating overlay; does not take space in the dashboard layout.
class SmashScot extends StatefulWidget {
  const SmashScot({super.key});
  @override
  State<SmashScot> createState() => _SmashScotState();
}

class _SmashScotState extends State<SmashScot> {
  Offset? position;
  bool dragging = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final maxX = (bounds.maxWidth - 68).clamp(0.0, double.infinity);
      final maxY = (bounds.maxHeight - 68).clamp(0.0, double.infinity);
      final point = position ?? Offset(maxX, (maxY - 14).clamp(0.0, maxY));
      return Stack(
        children: [
          AnimatedPositioned(
            left: point.dx.clamp(0.0, maxX),
            top: point.dy.clamp(0.0, maxY),
            duration: dragging || AppMotion.reduced(context)
                ? Duration.zero
                : AppMotion.duration(context, 220),
            curve: Curves.easeOutCubic,
            child: Semantics(
              label: 'Smash Scot demo assistant',
              button: true,
              child: GestureDetector(
                onPanStart: (_) => setState(() {
                  position = point;
                  dragging = true;
                }),
                onPanUpdate: (d) => setState(
                  () => position = Offset(
                    ((position ?? point).dx + d.delta.dx).clamp(0.0, maxX),
                    ((position ?? point).dy + d.delta.dy).clamp(0.0, maxY),
                  ),
                ),
                onPanEnd: (_) => setState(() {
                  dragging = false;
                  position = Offset(
                    (position ?? point).dx < maxX / 2 ? 0 : maxX,
                    (position ?? point).dy.clamp(0.0, maxY),
                  );
                }),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const SmashScotChat(),
                ),
                child: Container(
                  width: 58,
                  height: 58,
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2205644F),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      '$experienceAssets/icons/shuttle.svg',
                      width: 30,
                      height: 30,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SmashScotChat extends ConsumerStatefulWidget {
  const SmashScotChat({super.key});
  @override
  ConsumerState<SmashScotChat> createState() => _SmashScotChatState();
}

class _SmashScotChatState extends ConsumerState<SmashScotChat> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <String>[
    'Demo assistant · I can help you explore this local court catalogue. No live AI service is connected.',
  ];
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send(String query) {
    if (query.trim().isEmpty) return;
    final catalogue = ref.read(demoCatalogProvider);
    final key = query.toLowerCase();
    final reply = key.contains('review')
        ? 'Demo response: No real reviews are available. Reviews will appear when a verified review service is connected.'
        : key.contains('player') || key.contains('insight')
        ? 'Demo response: Live player statistics are not available in this assistant. Use the existing Match and Recommendation flows for player information.'
        : key.contains('court') ||
              key.contains('facilit') ||
              key.contains('price')
        ? 'Demo response: ${catalogue.facilities.length} illustrative facilities in Da Nang. ${catalogue.facilities.first.name} has ${catalogue.facilities.first.courtCount} courts, from ${catalogue.facilities.first.hourlyPrice} VND/hour. Explore Courts for details. Availability here is session-only demo data.'
        : 'Demo response: Choose Court Information, Player Insights or Reviews. This helper uses local demo content and cannot make reservations.';
    setState(() {
      messages.add('You: $query');
      messages.add(reply);
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: AppMotion.duration(context, 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.sports_tennis),
            title: const Text('Smash Scot'),
            subtitle: const Text('Demo assistant'),
            trailing: IconButton(
              tooltip: 'Close chat',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                for (final topic in [
                  'Court Information',
                  'Player Insights',
                  'Reviews',
                ])
                  ActionChip(label: Text(topic), onPressed: () => send(topic)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F2EC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(messages[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: input,
              textInputAction: TextInputAction.send,
              onSubmitted: send,
              decoration: InputDecoration(
                hintText: 'Ask Smash Scot',
                suffixIcon: IconButton(
                  tooltip: 'Send message',
                  onPressed: () => send(input.text),
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
