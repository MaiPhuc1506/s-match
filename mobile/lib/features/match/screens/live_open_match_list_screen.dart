import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../navigation/player_bottom_navigation.dart';
import '../services/open_match_service.dart';
import 'live_open_match_screen.dart';
import 'match_notifications_screen.dart';

class LiveOpenMatchListScreen extends StatefulWidget {
  const LiveOpenMatchListScreen({super.key});
  @override
  State<LiveOpenMatchListScreen> createState() =>
      _LiveOpenMatchListScreenState();
}

class _LiveOpenMatchListScreenState extends State<LiveOpenMatchListScreen> {
  final service = OpenMatchService();
  late Future<List<Map<String, dynamic>>> matches = service.list();
  int section = 0;
  int statusGroup = 0;
  DateTime? date;
  int? skill;
  Position? location;
  double? distanceKm;
  Map<String, dynamic> get filters => {
    if (date != null)
      'date':
          '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
    if (skill != null) 'skill': skill,
    if (location != null && distanceKm != null) 'latitude': location!.latitude,
    if (location != null && distanceKm != null)
      'longitude': location!.longitude,
    if (location != null && distanceKm != null) 'distanceKm': distanceKm,
  };
  void refresh() {
    setState(() {
      matches = section == 0 ? service.list(filters: filters) : service.mine();
    });
  }

  Future<void> nearby() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required for distance filtering.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      location = position;
      distanceKm = 5;
      refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location unavailable. Enable location access and try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Matches'),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const MatchNotificationsScreen(),
            ),
          ),
          tooltip: 'Notifications',
          icon: const Icon(CupertinoIcons.bell),
        ),
        IconButton(
          onPressed: refresh,
          tooltip: 'Refresh',
          icon: const Icon(CupertinoIcons.refresh),
        ),
      ],
    ),
    bottomNavigationBar: const PlayerBottomNavigation(
      currentTab: PlayerNavTab.match,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSegmentedControl<int>(
              groupValue: section,
              children: const {
                0: Text('Discover'),
                1: Text('My Matches'),
                2: Text('Requests'),
              },
              onValueChanged: (value) {
                section = value;
                refresh();
              },
            ),
          ),
        ),
        if (section == 0)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                      initialDate: date ?? now,
                    );
                    if (selected != null && mounted) {
                      date = selected;
                      refresh();
                    }
                  },
                  child: Text(
                    date == null ? 'Date' : '${date!.day}/${date!.month}',
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Skill level',
                  onSelected: (value) {
                    skill = value == 0 ? null : value;
                    refresh();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 0, child: Text('Any skill')),
                    for (var i = 1; i <= 5; i++)
                      PopupMenuItem(value: i, child: Text('Skill $i')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(skill == null ? 'Skill' : 'Skill $skill'),
                  ),
                ),
                TextButton(
                  onPressed: nearby,
                  child: Text(
                    distanceKm == null ? 'Within 5 km' : 'Within 5 km ✓',
                  ),
                ),
                if (filters.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      date = null;
                      skill = null;
                      location = null;
                      distanceKm = null;
                      refresh();
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        if (section == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<int>(
                groupValue: statusGroup,
                children: const {
                  0: Text('Upcoming'),
                  1: Text('Completed'),
                  2: Text('Cancelled'),
                },
                onValueChanged: (value) {
                  setState(() => statusGroup = value);
                },
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: matches,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: refresh,
                    child: const Text('Unable to load matches. Retry'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }
              final data = snapshot.data!
                  .where(
                    (m) =>
                        section == 0 ||
                        (section == 1
                            ? m['myStatus'] == 'ACCEPTED' &&
                                  (statusGroup == 2
                                      ? m['status'] == 'CANCELLED'
                                      : statusGroup == 1
                                      ? m['status'] == 'COMPLETED'
                                      : ![
                                          'CANCELLED',
                                          'COMPLETED',
                                        ].contains(m['status']))
                            : m['myStatus'] != 'ACCEPTED' ||
                                  (m['pendingRequestCount'] as num? ?? 0) > 0),
                  )
                  .toList();
              if (data.isEmpty) {
                return Center(
                  child: Text(
                    section == 0
                        ? 'No open matches yet.'
                        : section == 1
                        ? 'No matches yet.'
                        : 'No requests yet.',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: data.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final match = data[index];
                  final booking = match['booking'] is Map
                      ? match['booking'] as Map
                      : const {};
                  final court = booking['court'] is Map
                      ? booking['court'] as Map
                      : const {};
                  final facility = court['facility'] is Map
                      ? court['facility'] as Map
                      : const {};
                  final start = DateTime.tryParse('${match['startTime'] ?? ''}')
                      ?.toUtc()
                      .add(const Duration(hours: 7));
                  final date = start == null
                      ? 'Schedule unavailable'
                      : '${MaterialLocalizations.of(context).formatMediumDate(start)} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                  final state =
                      section == 2 &&
                          (match['pendingRequestCount'] as num? ?? 0) > 0
                      ? '${match['pendingRequestCount']} pending request(s)'
                      : section == 2
                      ? (match['myStatus'] ?? 'UNKNOWN')
                      : (match['status'] ?? 'OPEN');
                  return Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2ECE7)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      key: ValueKey('open-match-${match['id']}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: Text(
                        '${facility['name'] ?? match['title'] ?? 'Open Match'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${court['name'] ?? ''} · $date\n${match['participantCount'] ?? '—'}/${match['maxPlayers'] ?? '—'} players · $state',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 18,
                        color: Color(0xFF006A4E),
                      ),
                      onTap: () => Navigator.of(context)
                          .push(
                            MaterialPageRoute<void>(
                              builder: (_) => LiveOpenMatchScreen(
                                matchId: (match['id'] as num).toInt(),
                              ),
                            ),
                          )
                          .then((_) {
                            if (mounted) refresh();
                          }),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
