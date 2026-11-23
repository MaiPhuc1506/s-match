import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../recommendation/data/recommendation_repository.dart';
import '../../recommendation/models/recommended_player.dart';

class OpenMatchNearbyScreen extends StatefulWidget {
  const OpenMatchNearbyScreen({
    super.key,
    required this.matchId,
    required this.excludedIds,
  });
  final int matchId;
  final Set<int> excludedIds;
  @override
  State<OpenMatchNearbyScreen> createState() => _OpenMatchNearbyScreenState();
}

class _OpenMatchNearbyScreenState extends State<OpenMatchNearbyScreen> {
  late final sessionToken = ApiClient.instance.token;
  late Future<List<RecommendedPlayer>> players = loadPlayers();

  Future<List<RecommendedPlayer>> loadPlayers() async {
    final client = ApiClient.instance;
    final token = sessionToken;
    if (token == null || token != client.token) {
      throw const RecommendationFailure('Please sign in again.');
    }
    final response = await client.dio.get<Map<String, dynamic>>(
      '/players/profile/me',
      options: Options(extra: {'expectedAuthToken': token}),
    );
    final profile = response.data?['playerProfile'];
    if (profile is! Map || profile['locationSharingEnabled'] != true) {
      throw const RecommendationFailure(
        'Enable location sharing in your player profile to find nearby players.',
      );
    }
    return ApiRecommendationRepository(client.dio).search(
      const RecommendationQuery(),
      matchId: widget.matchId,
      expectedToken: token,
    );
  }

  final sending = <int>{};
  final invited = <int>{};

  Future<void> locationSettings() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Location sharing'),
        content: const Text(
          'Allow other players to discover you using your saved location. You can turn this off later.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable sharing'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        sessionToken == null ||
        ApiClient.instance.token != sessionToken) {
      return;
    }
    try {
      await ApiClient.instance.dio.put(
        '/candidates/me/location-sharing',
        data: {'enabled': true},
        options: Options(extra: {'expectedAuthToken': sessionToken}),
      );
      if (mounted) {
        setState(() {
          players = loadPlayers();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update location settings.')),
        );
      }
    }
  }

  Future<void> invite(int id) async {
    if (sending.contains(id)) return;
    setState(() => sending.add(id));
    try {
      final client = ApiClient.instance;
      final token = sessionToken;
      if (token == null || token != client.token) {
        throw StateError('Session changed');
      }
      await client.dio.post(
        '/matches/${widget.matchId}/invite',
        data: {'targetUserId': id},
        options: Options(extra: {'expectedAuthToken': token}),
      );
      if (mounted) setState(() => invited.add(id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send invitation. Please refresh and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find Nearby Players')),
    body: FutureBuilder<List<RecommendedPlayer>>(
      future: players,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is RecommendationFailure
                        ? '${snapshot.error}'
                        : 'Unable to load players. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  if (snapshot.error is RecommendationFailure &&
                      '${snapshot.error}'.contains('Enable location sharing'))
                    TextButton(
                      onPressed: locationSettings,
                      child: const Text('Location sharing settings'),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      players = loadPlayers();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final data = snapshot.data!.where((p) {
          final id = int.tryParse(p.id);
          return id != null && !widget.excludedIds.contains(id);
        }).toList();
        if (data.isEmpty) {
          return const Center(child: Text('No eligible players found nearby.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final player = data[index], id = int.parse(player.id);
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE7F5EE),
                child: Icon(CupertinoIcons.person, color: Color(0xFF006A4E)),
              ),
              title: Text(player.displayName),
              subtitle: Text(
                [
                  if (player.level != null) player.level!,
                  if (player.distanceKm != null)
                    '${player.distanceKm!.toStringAsFixed(1)} km',
                ].join(' · '),
              ),
              trailing: TextButton(
                onPressed: sending.contains(id) || invited.contains(id)
                    ? null
                    : () => invite(id),
                child: Text(
                  invited.contains(id)
                      ? 'Invited'
                      : sending.contains(id)
                      ? 'Sending…'
                      : 'Invite',
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
