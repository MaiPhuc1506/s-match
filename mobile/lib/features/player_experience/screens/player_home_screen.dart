import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../court_map/exploration_data.dart';
import '../../court_map/screens/court_preview_screen.dart';
import '../../court_map/screens/find_courts_map_screen.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../../match/screens/match_list_screen.dart';
import '../data/demo_catalog.dart';
import '../widgets/experience_widgets.dart';
import '../widgets/smash_scot.dart';
import 'courts_screens.dart';
import 'learning_screens.dart';
import 'shop_screens.dart';

class PlayerHomeScreen extends ConsumerWidget {
  const PlayerHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilitiesAsync = ref.watch(nearbyCourtsProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: experienceBackground,
        bottomNavigationBar: const PlayerBottomNavigation(
          currentTab: PlayerNavTab.home,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 18,
                      20,
                      22,
                    ),
                    decoration: const BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GOOD AFTERNOON',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ready to Play?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.search, color: mint),
                            title: const Text(
                              'Search courts, coaches & more',
                              style: TextStyle(fontSize: 13),
                            ),
                            onTap: () => openExperience(
                              context,
                              const ExperienceSearchScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _shortcut(
                              context,
                              'Courts',
                              'pin',
                              const ExploreCourtsScreen(),
                            ),
                            _shortcut(
                              context,
                              'Courses',
                              'cap',
                              const LearningScreen(),
                            ),
                            _shortcut(
                              context,
                              'Tips',
                              'book',
                              const LearningScreen(tips: true),
                            ),
                            _shortcut(
                              context,
                              'Shop',
                              'bag',
                              const ShopDirectoryScreen(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ExperienceCard(
                          child: InkWell(
                            onTap: () => openExperience(
                              context,
                              const FindCourtsMapScreen(),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'EXPLORE DA NANG',
                                        style: TextStyle(
                                          color: mint,
                                          fontSize: 11,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Find your perfect court.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Explore Map',
                                        style: TextStyle(color: mint),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.map_outlined, color: mint, size: 40),
                                Icon(Icons.chevron_right, color: mint),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final mapAction = TextButton(
                                key: const Key('home-view-courts-map'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                onPressed: () => openExperience(
                                  context,
                                  const FindCourtsMapScreen(),
                                ),
                                child: const Text(
                                  'View on Map  ›',
                                  style: TextStyle(color: mint, fontSize: 12),
                                ),
                              );
                              final allAction = TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                onPressed: () => openExperience(
                                  context,
                                  const ExploreCourtsScreen(),
                                ),
                                child: const Text('See all'),
                              );
                              const title = Text(
                                'Explore Courts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                              if (constraints.maxWidth < 340 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.1) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    Wrap(children: [mapAction, allAction]),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  const Expanded(child: title),
                                  mapAction,
                                  allAction,
                                ],
                              );
                            },
                          ),
                        ),
                        facilitiesAsync.when(
                          loading: () => const ExperienceCard(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                          error: (_, _) => ExperienceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Unable to load courts. Please try again.',
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  key: const Key('home_courts_retry'),
                                  onPressed: () =>
                                      ref.invalidate(nearbyCourtsProvider),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                          data: (allFacilities) {
                            final facilities = allFacilities
                                .where((f) => !f.demo && f.id > 0)
                                .toList();
                            if (facilities.isEmpty) {
                              return ExperienceCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'No registered facilities available yet.',
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      key: const Key(
                                        'home_courts_empty_refresh',
                                      ),
                                      onPressed: () =>
                                          ref.invalidate(nearbyCourtsProvider),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return LayoutBuilder(
                              builder: (_, bounds) => Wrap(
                                spacing: 12,
                                runSpacing: 0,
                                children: [
                                  for (final f in facilities)
                                    SizedBox(
                                      width: (bounds.maxWidth - 12) / 2,
                                      child: FacilityTile(
                                        facility: f,
                                        compact: true,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        _heading(
                          context,
                          'Open Matches',
                          const MatchListScreen(),
                        ),
                        _entry(
                          context,
                          Icons.groups_outlined,
                          'Find your next game',
                          'Explore the existing Match flow',
                          const MatchListScreen(),
                        ),
                        _heading(
                          context,
                          'Coaching & Courses',
                          const LearningScreen(),
                        ),
                        _entry(
                          context,
                          Icons.school_outlined,
                          'Build your badminton skills',
                          'Courses and coach profiles',
                          const LearningScreen(),
                        ),
                        _heading(
                          context,
                          'Tips & Tricks',
                          const LearningScreen(tips: true),
                        ),
                        _entry(
                          context,
                          Icons.menu_book_outlined,
                          'Learn a new technique',
                          'Practice guides · Videos coming soon',
                          const LearningScreen(tips: true),
                        ),
                        _heading(
                          context,
                          'Badminton Shop',
                          const ShopDirectoryScreen(),
                        ),
                        _entry(
                          context,
                          Icons.storefront_outlined,
                          'Discover badminton shops',
                          'Directory · Contact shops directly',
                          const ShopDirectoryScreen(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SmashScot(),
          ],
        ),
      ),
    );
  }

  Widget _shortcut(
    BuildContext context,
    String label,
    String icon,
    Widget page,
  ) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openExperience(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              children: [
                SvgPicture.asset(
                  '$experienceAssets/icons/$icon.svg',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _heading(BuildContext context, String title, Widget page) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: () => openExperience(context, page),
          child: const Text('See all'),
        ),
      ],
    ),
  );
  Widget _entry(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => ExperienceCard(
    padding: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: Icon(icon, color: mint),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openExperience(context, page),
    ),
  );
}

class ExperienceSearchScreen extends ConsumerStatefulWidget {
  const ExperienceSearchScreen({super.key});
  @override
  ConsumerState<ExperienceSearchScreen> createState() =>
      _ExperienceSearchScreenState();
}

class _ExperienceSearchScreenState
    extends ConsumerState<ExperienceSearchScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(nearbyCourtsProvider);
    final c = ref.watch(demoCatalogProvider);
    bool matches(String text) =>
        text.toLowerCase().contains(query.trim().toLowerCase());
    final registeredFacilities =
        (facilitiesAsync.asData?.value ?? const <CourtLocation>[]).where(
          (f) => !f.demo && f.id > 0,
        );
    final facilities = registeredFacilities
        .where((f) => matches('${f.name} ${f.address}'))
        .toList();
    final courses = c.courses.where((l) => matches(l.title));
    final coaches = c.coaches.where((l) => matches(l.title));
    final shops = c.shops.where((s) => matches(s.name));
    return ExperienceScaffold(
      title: 'Search',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Courts, coaches, courses or shops',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (facilitiesAsync.isLoading)
            const ExperienceCard(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (facilitiesAsync.hasError)
            ExperienceCard(
              child: Row(
                children: [
                  const Expanded(child: Text('Unable to load courts.')),
                  TextButton.icon(
                    key: const Key('search_courts_retry'),
                    onPressed: () => ref.invalidate(nearbyCourtsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (!facilitiesAsync.isLoading &&
              facilities.isEmpty &&
              courses.isEmpty &&
              coaches.isEmpty &&
              shops.isEmpty)
            const ExperienceCard(
              child: Text('No results. Try a different search.'),
            ),
          for (final f in facilities)
            ListTile(
              title: Text(f.name),
              subtitle: Text(
                f.address.trim().isEmpty
                    ? 'Court'
                    : 'Court · ${f.address.trim()}',
              ),
              onTap: () =>
                  openExperience(context, CourtPreviewScreen(location: f)),
            ),
          for (final l in courses)
            ListTile(
              title: Text(l.title),
              subtitle: const Text('Course'),
              onTap: () => openExperience(
                context,
                LearningDetailScreen(itemId: l.id, kind: 'course'),
              ),
            ),
          for (final l in coaches)
            ListTile(
              title: Text(l.title),
              subtitle: const Text('Coach'),
              onTap: () => openExperience(
                context,
                LearningDetailScreen(itemId: l.id, kind: 'coach'),
              ),
            ),
          for (final s in shops)
            ListTile(
              title: Text(s.name),
              subtitle: const Text('Shop directory'),
              onTap: () =>
                  openExperience(context, ShopDetailScreen(shopId: s.id)),
            ),
        ],
      ),
    );
  }
}
