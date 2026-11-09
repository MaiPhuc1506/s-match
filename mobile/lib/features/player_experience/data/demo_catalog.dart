import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../court_map/exploration_data.dart';

const experienceAssets = 'assets/sprint10';

/// Illustrative listings, not verified businesses or live availability.
class DemoFacility {
  const DemoFacility(
    this.id,
    this.name,
    this.district,
    this.imageKey,
    this.latitude,
    this.longitude,
    this.courtCount,
    this.hourlyPrice,
  );
  final int id, courtCount, hourlyPrice;
  final String name, district, imageKey;
  final double latitude, longitude;
  String get image => '$experienceAssets/courts/$imageKey.png';
  String get address => '$district, Da Nang, Vietnam';
  int courtId(int index) => id * 10 - index - 1;
  List<Map<String, dynamic>> get courts => List.generate(
    courtCount,
    (i) => {
      'id': courtId(i),
      'name': 'Court ${i + 1}',
      'status': 'ACTIVE',
      'courtType': 'INDOOR',
    },
  );
  CourtLocation get location => CourtLocation(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    address: address,
    photos: [image],
    courts: courts,
    priceRange: '${hourlyPrice ~/ 1000}k VND/h',
    demo: true,
  );
}

class LearningItem {
  const LearningItem(
    this.id,
    this.title,
    this.subtitle,
    this.imageKey,
    this.description, {
    this.coachId,
    this.steps = const [],
  });
  final String id, title, subtitle, imageKey, description;
  final String? coachId;
  final List<String> steps;
  String get image => '$experienceAssets/learning/$imageKey.png';
}

class DemoShop {
  const DemoShop(
    this.id,
    this.name,
    this.district,
    this.imageKey,
    this.latitude,
    this.longitude,
    this.specialty, {
    this.phone,
    this.email,
  });
  final String id, name, district, imageKey, specialty;
  final double latitude, longitude;
  final String? phone, email;
  String get image => '$experienceAssets/learning/$imageKey.png';
}

class DemoCatalog {
  const DemoCatalog();
  final facilities = const [
    DemoFacility(
      -1001,
      'Hai Chau Badminton',
      'Hai Chau',
      'hai_chau',
      16.061,
      108.2165,
      4,
      80000,
    ),
    DemoFacility(
      -1002,
      'Hoa Cuong Badminton',
      'Hoa Cuong',
      'hoa_cuong',
      16.034,
      108.215,
      6,
      90000,
    ),
    DemoFacility(
      -1003,
      'Thanh Khe Badminton',
      'Thanh Khe',
      'thanh_khe',
      16.064,
      108.185,
      4,
      70000,
    ),
    DemoFacility(
      -1004,
      'An Khe Badminton',
      'An Khe',
      'an_khe',
      16.045,
      108.178,
      3,
      70000,
    ),
    DemoFacility(
      -1005,
      'An Hai Badminton',
      'An Hai',
      'an_hai',
      16.065,
      108.241,
      4,
      80000,
    ),
    DemoFacility(
      -1006,
      'Son Tra Badminton',
      'Son Tra',
      'son_tra',
      16.093,
      108.246,
      6,
      100000,
    ),
    DemoFacility(
      -1007,
      'Ngu Hanh Son Badminton',
      'Ngu Hanh Son',
      'ngu_hanh_son',
      16.012,
      108.258,
      4,
      90000,
    ),
    DemoFacility(
      -1008,
      'Hoa Xuan Badminton',
      'Hoa Xuan',
      'hoa_xuan',
      15.999,
      108.22,
      5,
      80000,
    ),
    DemoFacility(
      -1009,
      'Cam Le Badminton',
      'Cam Le',
      'cam_le',
      16.012,
      108.192,
      4,
      70000,
    ),
    DemoFacility(
      -1010,
      'Hoa Khanh Badminton',
      'Hoa Khanh',
      'hoa_khanh',
      16.073,
      108.152,
      6,
      80000,
    ),
  ];
  final coaches = const [
    LearningItem(
      'minh',
      'Coach Minh',
      'Technique · 5 years of coaching',
      'coach_minh',
      'Build a confident foundation with structured technique and movement practice.',
    ),
    LearningItem(
      'lan',
      'Coach Lan',
      'Footwork · Competitive training',
      'coach_lan',
      'Develop balanced movement, efficient recovery and confident court coverage.',
    ),
  ];
  final courses = const [
    LearningItem(
      'fundamentals',
      'Badminton Fundamentals',
      'Beginner · 4-week programme',
      'training_course',
      'Learn grip, control, movement and key shots through a structured practice programme.',
      coachId: 'minh',
      steps: [
        'Grip and racket control',
        'Basic footwork',
        'Serves and returns',
        'Practice rallies',
      ],
    ),
    LearningItem(
      'footwork',
      'Footwork Masterclass',
      'Intermediate · Movement',
      'footwork_training',
      'Build efficient movement and recover to the centre after each shot.',
      coachId: 'lan',
      steps: ['Split step', 'Corner movement', 'Recovery', 'Movement drills'],
    ),
    LearningItem(
      'private',
      'Private Coaching',
      'One-to-one · Personal training',
      'training_racket',
      'A focused practice plan adapted to your technique and playing goals.',
      coachId: 'minh',
      steps: ['Technique review', 'Targeted practice', 'Progress review'],
    ),
  ];
  final lessons = const [
    LearningItem(
      'smash',
      'Improve Your Smash',
      'Smash · Technique',
      'smash_technique',
      'Practise a balanced preparation, a high contact point and a controlled recovery.',
      steps: [
        'Starting position: stay balanced behind the shuttle.',
        'Racket preparation: raise the racket and turn your shoulders.',
        'Contact point: reach high and slightly in front.',
        'Follow-through: relax and recover to the centre.',
      ],
    ),
    LearningItem(
      'movement',
      'Footwork Basics',
      'Beginner · Footwork',
      'footwork_training',
      'Move efficiently while maintaining balance before and after every shot.',
      steps: [
        'Start in a ready position.',
        'Use a small split step.',
        'Move to the shuttle with controlled steps.',
        'Recover to the centre.',
      ],
    ),
    LearningItem(
      'net',
      'Net Play Essentials',
      'Beginner · Net play',
      'net_play',
      'Develop a relaxed grip and controlled touch near the net.',
      steps: [
        'Approach with the racket raised.',
        'Keep the grip relaxed.',
        'Contact the shuttle gently in front.',
        'Recover after the shot.',
      ],
    ),
  ];
  final shops = const [
    DemoShop(
      'racket',
      'S-Match Racket Directory',
      'Hai Chau',
      'training_racket',
      16.061,
      108.2165,
      'Rackets, strings and accessories',
    ),
    DemoShop(
      'shoes',
      'Court Gear Directory',
      'Thanh Khe',
      'badminton_shoes',
      16.064,
      108.185,
      'Badminton shoes and court essentials',
    ),
    DemoShop(
      'shuttle',
      'Shuttle & Grip Directory',
      'Son Tra',
      'shuttlecocks',
      16.093,
      108.246,
      'Shuttlecocks, replacement grips and accessories',
    ),
  ];
  DemoFacility facility(int id) => facilities.firstWhere((f) => f.id == id);
}

final demoCatalogProvider = Provider<DemoCatalog>((ref) => const DemoCatalog());
