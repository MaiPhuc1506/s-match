/// Approved Figma imagery keyed by catalogue identity, never database IDs.
/// Server-uploaded photos always take precedence over illustrative assets.
abstract final class FacilityImages {
  static const keys = <String>[
    'hai_chau',
    'hoa_cuong',
    'thanh_khe',
    'an_khe',
    'an_hai',
    'son_tra',
    'ngu_hanh_son',
    'hoa_xuan',
    'cam_le',
    'hoa_khanh',
  ];

  static String? keyFor(String name, String address) {
    final normalized = name.trim().toLowerCase();
    for (final key in keys) {
      final district = key.replaceAll('_', ' ');
      if (normalized == '$district badminton' &&
          address.trim().toLowerCase() == '$district, da nang, vietnam') {
        return key;
      }
    }
    return null;
  }

  static List<String> resolve({
    required String name,
    required String address,
    required List<String> photos,
  }) {
    final uploaded = photos.where((p) => p.trim().isNotEmpty).toSet().toList();
    if (uploaded.isNotEmpty) return uploaded;
    final key = keyFor(name, address);
    if (key == null) return const [];
    return [
      'assets/sprint10/courts/$key.png',
      if (key != 'hai_chau') 'assets/sprint10/courts/${key}_interior.jpg',
    ];
  }
}
