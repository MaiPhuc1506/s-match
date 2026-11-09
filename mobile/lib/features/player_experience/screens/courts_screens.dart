import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../court_map/screens/find_courts_map_screen.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../../booking/widgets/live_facility_schedule.dart';
import '../../booking/screens/booking_history_screen.dart';
import '../data/demo_catalog.dart';
import '../data/demo_booking_service.dart';
import '../widgets/experience_widgets.dart';
import '../../../core/theme/app_motion.dart';
import 'player_home_screen.dart';

class ExploreCourtsScreen extends ConsumerStatefulWidget {
  const ExploreCourtsScreen({super.key});
  @override
  ConsumerState<ExploreCourtsScreen> createState() =>
      _ExploreCourtsScreenState();
}

class _ExploreCourtsScreenState extends ConsumerState<ExploreCourtsScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final facilities = ref
        .watch(demoCatalogProvider)
        .facilities
        .where(
          (f) => '${f.name} ${f.district}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return ExperienceScaffold(
      title: 'Explore Courts',
      tab: PlayerNavTab.map,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Search courts or area',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const DemoNotice(),
          OutlinedButton.icon(
            onPressed: () =>
                openExperience(context, const DemoCourtsMapScreen()),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Explore Map'),
          ),
          TextButton.icon(
            onPressed: () => openExperience(
              context,
              BookingHistoryScreen(
                demoBookings: ref.read(demoBookingProvider).history,
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Demo Bookings'),
          ),
          const SizedBox(height: 12),
          Text(
            facilities.length == 1
                ? '1 facility'
                : '${facilities.length} facilities',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (facilities.isEmpty)
            const ExperienceCard(
              child: Text('No courts match your search. Try another area.'),
            ),
          ...facilities.map((f) => FacilityTile(facility: f)),
        ],
      ),
    );
  }
}

class FacilityTile extends StatelessWidget {
  const FacilityTile({super.key, required this.facility, this.compact = false});
  final DemoFacility facility;
  final bool compact;
  @override
  Widget build(BuildContext context) => ExperienceCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openExperience(
        context,
        DemoCourtDetailScreen(facilityId: facility.id),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExperiencePhoto(facility.image, height: compact ? 108 : 170),
            const SizedBox(height: 10),
            Text(
              facility.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${facility.district} · ${facility.courtCount} courts',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (!compact)
              Text(
                'From ${facility.hourlyPrice} VND / hour',
                style: const TextStyle(color: mint),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Compatibility entry point; Map discovery now shows registered facilities only.
class DemoCourtsMapScreen extends StatelessWidget {
  const DemoCourtsMapScreen({super.key});
  @override
  Widget build(BuildContext context) => const FindCourtsMapScreen();
}

class DemoCourtDetailScreen extends ConsumerWidget {
  const DemoCourtDetailScreen({super.key, required this.facilityId});
  final int facilityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(demoCatalogProvider).facility(facilityId);
    return DefaultTabController(
      length: 5,
      child: ExperienceScaffold(
        title: 'Court Detail',
        tab: PlayerNavTab.map,
        bottom: ExperienceAction(
          label: 'Select Court & Book',
          onPressed: () =>
              openExperience(context, DemoBookingScreen(facilityId: f.id)),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (_, innerScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExperiencePhoto(f.image, height: 220),
                    const DemoNotice(text: 'BADMINTON · DEMO FACILITY'),
                    Text(
                      f.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(f.address),
                    const SizedBox(height: 8),
                    Text('06:00–22:00 · ${f.courtCount} indoor courts'),
                    const SizedBox(height: 8),
                    const Text(
                      'No reviews yet · Demo listing',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Info'),
                  Tab(text: 'Pricing'),
                  Tab(text: 'Images'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Rules'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _DetailBody(
                children: [
                  const Text(
                    'Court Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Indoor badminton courts for training and casual games in ${f.district}.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Amenities',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(Icons.local_parking, size: 18),
                        label: Text('Parking'),
                      ),
                      Chip(
                        avatar: Icon(Icons.lightbulb_outline, size: 18),
                        label: Text('Lighting'),
                      ),
                      Chip(
                        avatar: Icon(Icons.water_drop_outlined, size: 18),
                        label: Text('Drinking water'),
                      ),
                    ],
                  ),
                  const Text(
                    'Courts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ...f.courts.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.sports_tennis, color: mint),
                      title: Text(c['name'] as String),
                      subtitle: const Text('Indoor · Demo availability'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openExperience(
                        context,
                        DemoBookingScreen(facilityId: f.id),
                      ),
                    ),
                  ),
                ],
              ),
              _DetailBody(
                children: [
                  const DemoNotice(text: 'Illustrative pricing · VND / hour'),
                  ListTile(
                    title: const Text('06:00–17:00'),
                    trailing: Text('${f.hourlyPrice} VND'),
                  ),
                  ListTile(
                    title: const Text('17:00–22:00'),
                    trailing: Text('${f.hourlyPrice + 20000} VND'),
                  ),
                ],
              ),
              _DetailBody(
                children: [
                  ExperiencePhoto(f.image, height: 260),
                  const SizedBox(height: 12),
                  const Text(
                    'Illustrative facility photo from the approved design. Tap to enlarge.',
                  ),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: Stack(
                          children: [
                            InteractiveViewer(child: Image.asset(f.image)),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                tooltip: 'Close image',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('View full image'),
                  ),
                ],
              ),
              const _DetailBody(
                children: [
                  Icon(Icons.rate_review_outlined, size: 40, color: mint),
                  SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No real reviews have been provided for this demo facility.',
                  ),
                ],
              ),
              const _DetailBody(
                children: [
                  Text(
                    'Court Rules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Wear suitable badminton shoes.'),
                  ),
                  ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Arrive on time for your session.'),
                  ),
                  ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Respect other players and court equipment.'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: children);
}

class DemoBookingScreen extends ConsumerWidget {
  const DemoBookingScreen({super.key, required this.facilityId});
  final int facilityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(demoBookingProvider);
    return LiveFacilitySchedule(
      facilityId: facilityId,
      service: service,
      demo: true,
      onBackHome: () => Navigator.of(context).pushAndRemoveUntil(
        AppMotion.route<void>(const PlayerHomeScreen(), name: '/player-home'),
        (route) => route.isFirst,
      ),
      onViewBookings: () => openExperience(
        context,
        BookingHistoryScreen(demoBookings: service.history),
      ),
    );
  }
}
