import 'dart:convert';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:mobile/features/court_map/widgets/native_court_layers.dart';
import 'package:mobile/features/court_map/widgets/native_player_layers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'support/fake_court_map_platform.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/widgets/court_maplibre_map.dart';

void main() {
  final originalPlatform = MapLibrePlatform.createInstance;
  setUp(() => MapLibrePlatform.createInstance = FakeCourtMapPlatform.new);
  tearDown(() => MapLibrePlatform.createInstance = originalPlatform);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Missing API fields do not create ratings or coordinates', () {
    final c = CourtLocation.fromJson({'id': 99, 'name': 'Facility'});
    expect(c.hasCoordinates, isFalse);
    expect(c.rating, isNull);
    expect(c.reviewCount, isNull);
    expect(c.isOpen, isNull);
    expect(c.distanceKm, isNull);
    expect(c.photos, isEmpty);
    expect(
      CourtLocation.fromJson({'id': 1, 'latitude': 95, 'longitude': 108})
          .hasCoordinates,
      isFalse,
    );
  });
  test(
    'CourtLocation fromJson parses NestJS facility API response correctly',
    () {
      final json = {
        'id': 10,
        'name': 'Da Nang Badminton Hub',
        'latitude': 16.0700,
        'longitude': 108.2200,
        'distanceKm': 2.5,
        'rating': 4.9,
        'reviewCount': 350,
        'priceRange': r'$$',
        'isOpen': true,
        'address': '500 Nguyen Tat Thanh, Da Nang',
        'photos': ['assets/images/match/facility_court.jpg'],
      };

      final court = CourtLocation.fromJson(json);
      expect(court.id, 10);
      expect(court.name, 'Da Nang Badminton Hub');
      expect(court.latitude, 16.0700);
      expect(court.longitude, 108.2200);
      expect(court.distanceKm, 2.5);
      expect(court.rating, 4.9);
      expect(court.reviewCount, 350);
      expect(court.priceRange, r'$$');
      expect(court.isOpen, isTrue);
      expect(court.address, '500 Nguyen Tat Thanh, Da Nang');
      expect(court.photos, hasLength(1));
    },
  );

  test('smatch_mint_style.json is bundled and valid in rootBundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final jsonStr = await rootBundle.loadString(
      CourtMapLibreMap.smatchMintStyleAsset,
    );
    expect(jsonStr, isNotEmpty);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    expect(map['version'], 8);
    expect(map['name'], 'S-Match Mint');
    expect(map['layers'], hasLength(111));
    expect(map['sources'], isNotNull);
    expect(map['glyphs'], startsWith('https://'));
    expect(map['sprite'], startsWith('https://'));
  });

  testWidgets(
    'Native player feature taps select the matching permitted player',
    (tester) async {
      final platform = FakeCourtMapPlatform();
      MapLibrePlatform.createInstance = () => platform;
      NearbyPlayer? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: CourtMapLibreMap(
            courts: const [],
            players: demoPlayers,
            showPlayers: true,
            onPlayerSelected: (player) => selected = player,
          ),
        ),
      );
      await tester.pumpAndSettle();
      platform.onFeatureTappedPlatform.call({
        'id': 'player:thao',
        'layerId': NativePlayerLayers.layer,
        'point': const Point(100.0, 100.0),
        'latLng': const LatLng(16.065, 108.238),
      });
      expect(selected?.id, 'thao');
      selected = null;
      platform.onFeatureTappedPlatform.call({
        'id': 'player:missing',
        'layerId': NativePlayerLayers.layer,
        'point': const Point(100.0, 100.0),
        'latLng': const LatLng(16.065, 108.238),
      });
      expect(selected, isNull);
    },
  );

  testWidgets('CourtMapLibreMap renders MapLibreMap with S-Match Mint style', (
    tester,
  ) async {
    CourtMapController? controller;
    bool previewOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourtMapLibreMap(
            courts: mockCourts,
            selectedCourt: mockCourts.first,
            showPins: true,
            showAccuracy: true,
            showSelection: true,
            onMapReady: (c) => controller = c,
            onCourtPreview: () => previewOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MapLibreMap is rendered with S-Match Mint style
    final mapLibreFinder = find.byType(MapLibreMap);
    expect(mapLibreFinder, findsOneWidget);
    final mapLibre = tester.widget<MapLibreMap>(mapLibreFinder);
    expect(mapLibre.styleString, CourtMapLibreMap.smatchMintStyleAsset);

    // Verify controller was registered
    expect(controller, isNotNull);
    expect(controller!.center, isNotNull);

    // Verify Selected Sky Badminton bubble is visible
    expect(find.text('Sky Badminton'), findsOneWidget);
    expect(find.text('1.3 km · \$'), findsOneWidget);

    // Tapping the bubble invokes preview
    await tester.tap(find.text('Sky Badminton'));
    await tester.pumpAndSettle();
    expect(previewOpened, isTrue);

    // Controller moveToCourt updates target without error
    await controller!.moveToCourt(mockCourts[1]);
    await tester.pumpAndSettle();
    expect(
      controller!.center!.latitude,
      closeTo(mockCourts[1].latitude!, 0.0001),
    );
    expect(
      controller!.center!.longitude,
      closeTo(mockCourts[1].longitude!, 0.0001),
    );

    // Controller recenter moves back to Da Nang center
    await controller!.recenter();
    await tester.pumpAndSettle();
    expect(
      controller!.center!.latitude,
      closeTo(CourtMapLibreMap.userLocation.latitude, 0.0001),
    );
    expect(
      controller!.center!.longitude,
      closeTo(CourtMapLibreMap.userLocation.longitude, 0.0001),
    );
  });

  testWidgets(
    'Native layers use geographic clusters and bottom-anchored pins',
    (tester) async {
      MapLibreMapController? controller;
      final platform = FakeCourtMapPlatform();
      MapLibrePlatform.createInstance = () => platform;
      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            annotationOrder: const [],
            onMapCreated: (c) => controller = c,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final layers = NativeCourtLayers(
        controller!,
        loadPin: () async => Uint8List.fromList([1]),
      );
      await layers.sync(
        mockCourts,
        showPins: true,
        showCluster: true,
        showAccuracy: true,
        referenceLocation: CourtMapLibreMap.userLocation,
      );
      expect(
        platform.sources[NativeCourtLayers.clusteredSource]!['cluster'],
        true,
      );
      expect(
        (platform.sources[NativeCourtLayers.source]!['data']
            as Map)['features'],
        hasLength(3),
      );
      expect(platform.layers[NativeCourtLayers.pins]!['icon-anchor'], 'bottom');
      expect(
        platform.layers[NativeCourtLayers.pins]!['icon-pitch-alignment'],
        'viewport',
      );
      expect(platform.visibility[NativeCourtLayers.pins], false);
      expect(platform.visibility[NativeCourtLayers.clusteredPins], true);
      await layers.expandCluster(const Point(100, 200));
      expect(platform.zoom, 16.5);
      expect(platform.projectionRequests, 0);
      await layers.sync(
        mockCourts,
        showPins: false,
        showCluster: false,
        showAccuracy: false,
        referenceLocation: CourtMapLibreMap.userLocation,
      );
      expect(platform.visibility.values.every((v) => !v), true);
      layers.disposed = true;
    },
  );
  testWidgets(
    'Camera movement does not reproject markers; callout returns only at idle',
    (tester) async {
      final platform = FakeCourtMapPlatform();
      MapLibrePlatform.createInstance = () => platform;
      await tester.pumpWidget(
        MaterialApp(
          home: CourtMapLibreMap(
            courts: mockCourts,
            selectedCourt: mockCourts.first,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final requests = platform.projectionRequests;
      final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
      for (var i = 0; i < 30; i++) {
        map.onCameraMove!(
          CameraPosition(
            target: const LatLng(16, 108),
            zoom: 15,
            bearing: i * 4,
            tilt: 45,
          ),
        );
      }
      await tester.pump();
      expect(platform.projectionRequests, requests);
      expect(find.text('Sky Badminton'), findsNothing);
      map.onCameraIdle!();
      await tester.pumpAndSettle();
      expect(find.text('Sky Badminton'), findsOneWidget);
      expect(platform.projectionRequests, requests + 1);
      expect(map.zoomGesturesEnabled, isTrue);
    },
  );
  testWidgets('Trackpad scale events update zoom when forwarded by the host', (
    tester,
  ) async {
    final platform = FakeCourtMapPlatform();
    MapLibrePlatform.createInstance = () => platform;
    await tester.pumpWidget(
      MaterialApp(home: CourtMapLibreMap(courts: mockCourts)),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(const Offset(120, 200));
    await gesture.panZoomUpdate(const Offset(120, 200), scale: 2);
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(platform.zoom, closeTo(15, .001));
  });

  testWidgets(
    'iOS debug map installs Simulator pinch adapter through the native channel',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const channel = MethodChannel('smatch/simulator_map_pinch');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'install');
            calls++;
            return 1;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        MaterialApp(home: CourtMapLibreMap(courts: mockCourts)),
      );
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CourtMapLibreMap preserves OpenFreeMap Liberty style as fallback option',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CourtMapLibreMap(
              courts: mockCourts,
              styleString: CourtMapLibreMap.openFreeMapLibertyStyle,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapLibreFinder = find.byType(MapLibreMap);
      expect(mapLibreFinder, findsOneWidget);
      final mapLibre = tester.widget<MapLibreMap>(mapLibreFinder);
      expect(mapLibre.styleString, CourtMapLibreMap.openFreeMapLibertyStyle);
    },
  );
}
