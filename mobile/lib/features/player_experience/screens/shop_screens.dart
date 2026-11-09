import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/demo_catalog.dart';
import '../widgets/experience_widgets.dart';

class ShopDirectoryScreen extends ConsumerWidget {
  const ShopDirectoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ExperienceScaffold(
    title: 'Badminton Shops',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DemoNotice(
          text:
              'Demo shop directory · Browse and contact · No online purchases',
        ),
        for (final shop in ref.watch(demoCatalogProvider).shops)
          ExperienceCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  openExperience(context, ShopDetailScreen(shopId: shop.id)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExperiencePhoto(shop.image),
                    const SizedBox(height: 12),
                    Text(
                      shop.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('${shop.district}, Da Nang'),
                    const SizedBox(height: 6),
                    Text(shop.specialty),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.chevron_right, color: mint),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({super.key, required this.shopId});
  final String shopId;
  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Show a real launch failure, without pretending success. */
    }
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Unable to open link'),
          content: Text(uri.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref
        .watch(demoCatalogProvider)
        .shops
        .firstWhere((s) => s.id == shopId);
    return ExperienceScaffold(
      title: 'Shop Detail',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ExperiencePhoto(s.image, height: 240),
          const DemoNotice(
            text: 'DEMO DIRECTORY LISTING · Illustrative location and imagery',
          ),
          Text(
            s.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${s.district}, Da Nang'),
          const SizedBox(height: 20),
          ExperienceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Specialities',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(s.specialty),
                const SizedBox(height: 14),
                const Text(
                  'Browse the directory and contact shops directly. S-Match does not process purchases or payments.',
                ),
              ],
            ),
          ),
          ExperienceAction(
            label: 'Contact',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.phone ?? 'No verified phone number supplied for this demo listing.',
                      ),
                      Text(
                        s.email ??
                            'No verified email supplied for this demo listing.',
                      ),
                      if (s.email != null)
                        TextButton(
                          onPressed: () => _launch(
                            context,
                            Uri(scheme: 'mailto', path: s.email),
                          ),
                          child: const Text('Send email'),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: s.phone == null
                ? null
                : () => _launch(context, Uri(scheme: 'tel', path: s.phone)),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call'),
          ),
          const Text(
            'Calling becomes available when verified contact details are provided.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _launch(
              context,
              Uri.https('maps.apple.com', '/', {
                'll': '${s.latitude},${s.longitude}',
                'q': '${s.name} (Demo location)',
              }),
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('View on Map'),
          ),
        ],
      ),
    );
  }
}
