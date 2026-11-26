import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import 'live_open_match_screen.dart';

class MatchNotificationsScreen extends StatefulWidget {
  const MatchNotificationsScreen({super.key});
  @override
  State<MatchNotificationsScreen> createState() =>
      _MatchNotificationsScreenState();
}

class _MatchNotificationsScreenState extends State<MatchNotificationsScreen> {
  late Future<List<dynamic>> data = load();
  Future<List<dynamic>> load() async =>
      (await ApiClient.instance.dio.get<List<dynamic>>(
        '/matches/notifications',
      )).data ??
      [];
  String label(String kind) => switch (kind) {
    'MATCH_COMPLETED' => 'Your match has finished',
    'INVITATION' => 'You have a match invitation',
    'JOIN_REQUEST' => 'A player requested to join your match',
    'REQUEST_APPROVED' => 'Your join request was approved',
    'REQUEST_REJECTED' => 'Your join request was declined',
    _ => 'Match update',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<List<dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() {
                data = load();
              }),
              child: const Text('Unable to load notifications. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No notifications yet.'));
        }
        return ListView.separated(
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = snapshot.data![index] as Map;
            return ListTile(
              leading: Icon(
                item['isRead'] == true
                    ? CupertinoIcons.bell
                    : CupertinoIcons.bell_fill,
                color: const Color(0xFF006A4E),
              ),
              title: Text(label('${item['kind']}')),
              trailing: const Icon(CupertinoIcons.chevron_right),
              onTap: () async {
                try {
                  await ApiClient.instance.dio.patch(
                    '/matches/notifications/${item['id']}/read',
                  );
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveOpenMatchScreen(
                        matchId: (item['matchId'] as num).toInt(),
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      data = load();
                    });
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to open notification. Try again.',
                        ),
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    ),
  );
}
