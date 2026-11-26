import 'package:flutter/material.dart';

const playingAreas = <String>[
  'Hải Châu',
  'Thanh Khê',
  'Sơn Trà',
  'Ngũ Hành Sơn',
  'Cẩm Lệ',
  'Liên Chiểu',
  'Hòa Vang',
  'Hòa Khánh',
  'Hòa Xuân',
  'An Hải',
];

/// Returns null on cancellation, retaining existing legacy/custom values.
Future<String?> pickPlayingArea(BuildContext context, String current) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Playing Area')),
          for (final area in playingAreas)
            ListTile(
              title: Text(area),
              trailing: current == area
                  ? const Icon(Icons.check, color: Color(0xFF05644F))
                  : null,
              onTap: () => Navigator.pop(context, area),
            ),
          ListTile(
            title: const Text('Other / Custom area'),
            onTap: () => Navigator.pop(context, '__custom__'),
          ),
        ],
      ),
    ),
  );
  if (choice != '__custom__' || !context.mounted) return choice;
  final controller = TextEditingController(
    text: playingAreas.contains(current) ? '' : current,
  );
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Custom playing area'),
      content: TextField(
        controller: controller,
        maxLength: 120,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
