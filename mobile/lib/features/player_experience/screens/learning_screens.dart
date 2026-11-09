import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_catalog.dart';
import '../widgets/experience_widgets.dart';

class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key, this.tips = false});
  final bool tips;
  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  bool coaches = false;
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(demoCatalogProvider);
    final items = widget.tips
        ? catalogue.lessons
              .where(
                (l) =>
                    filter == 'All' ||
                    l.subtitle.toLowerCase().contains(filter.toLowerCase()),
              )
              .toList()
        : coaches
        ? catalogue.coaches
        : catalogue.courses;
    return ExperienceScaffold(
      title: widget.tips ? 'Tips & Tricks' : 'Coaching & Courses',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!widget.tips)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Courses')),
                ButtonSegment(value: true, label: Text('Coaches')),
              ],
              selected: {coaches},
              onSelectionChanged: (s) => setState(() => coaches = s.first),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in [
                    'All',
                    'Beginner',
                    'Footwork',
                    'Smash',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: filter == category,
                        onSelected: (_) => setState(() => filter = category),
                      ),
                    ),
                ],
              ),
            ),
          DemoNotice(
            text: widget.tips
                ? 'Practice guides · Videos coming soon'
                : 'Demo coaching catalogue · No enrolment or payment',
          ),
          for (final item in items)
            LearningTile(
              item: item,
              kind: widget.tips
                  ? 'lesson'
                  : coaches
                  ? 'coach'
                  : 'course',
            ),
        ],
      ),
    );
  }
}

class LearningTile extends StatelessWidget {
  const LearningTile({super.key, required this.item, required this.kind});
  final LearningItem item;
  final String kind;
  @override
  Widget build(BuildContext context) => ExperienceCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openExperience(
        context,
        LearningDetailScreen(itemId: item.id, kind: kind),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExperiencePhoto(item.image),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(item.subtitle),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    kind == 'lesson'
                        ? 'Read lesson · Video coming soon'
                        : 'View details',
                    style: const TextStyle(color: mint),
                  ),
                ),
                const Icon(Icons.chevron_right, color: mint),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class LearningDetailScreen extends ConsumerWidget {
  const LearningDetailScreen({
    super.key,
    required this.itemId,
    required this.kind,
  });
  final String itemId, kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(demoCatalogProvider);
    final item =
        (kind == 'lesson'
                ? catalogue.lessons
                : kind == 'coach'
                ? catalogue.coaches
                : catalogue.courses)
            .firstWhere((l) => l.id == itemId);
    return ExperienceScaffold(
      title: kind == 'coach'
          ? 'Coach Profile'
          : kind == 'lesson'
          ? 'Lesson Detail'
          : 'Course Detail',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ExperiencePhoto(item.image, height: 230),
          const DemoNotice(),
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(item.subtitle, style: const TextStyle(color: mint)),
          const SizedBox(height: 20),
          ExperienceCard(child: Text(item.description)),
          if (kind == 'lesson')
            const ExperienceCard(
              child: Row(
                children: [
                  Icon(Icons.ondemand_video, color: mint),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video coming soon\nRead the practice steps below.',
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < item.steps.length; i++)
            ExperienceCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                title: Text('Step ${i + 1}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(item.steps[i]),
                  ),
                ],
              ),
            ),
          if (kind == 'coach') ...[
            const Text(
              'Available Courses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...catalogue.courses
                .where((l) => l.coachId == item.id)
                .map((l) => LearningTile(item: l, kind: 'course')),
          ],
          if (kind == 'course' && item.coachId != null)
            ExperienceAction(
              label: 'View Coach',
              onPressed: () => openExperience(
                context,
                LearningDetailScreen(itemId: item.coachId!, kind: 'coach'),
              ),
            ),
        ],
      ),
    );
  }
}
