import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/auth/screens/create_account_screen.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/screens/player_welcome_screen.dart';
import 'package:mobile/features/auth/screens/court_owner_welcome_screen.dart';
import 'package:mobile/features/auth/screens/admin_welcome_screen.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/auth/screens/edit_profile_screen.dart';
import 'package:mobile/features/auth/screens/skill_assessment_screen.dart';
import 'package:mobile/features/auth/screens/match_preferences_screen.dart';
import 'package:mobile/features/facility/screens/facility_list_screen.dart';
import 'package:mobile/features/facility/screens/facility_detail_screen.dart';
import 'package:mobile/features/facility/screens/add_edit_court_screen.dart';
import 'package:mobile/features/facility/screens/operating_hours_screen.dart';
import 'package:mobile/features/facility/widgets/facility_card.dart';
import 'package:mobile/features/booking/screens/booking_facility_schedule_screen.dart';
import 'package:mobile/features/booking/screens/booking_summary_screen.dart';
import 'package:mobile/features/booking/screens/booking_success_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/booking/screens/booking_detail_screen.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/match/screens/create_match_screen.dart';
import 'package:mobile/features/match/screens/match_detail_open_screen.dart';
import 'package:mobile/features/match/screens/match_invitations_screen.dart';
import 'package:mobile/features/match/screens/match_join_requests_screen.dart';
import 'package:mobile/features/match/screens/match_participant_list_screen.dart';
import 'package:mobile/features/match/models/match_model.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/court_map/screens/court_preview_screen.dart';
import 'package:mobile/features/court_map/screens/find_players_map_screen.dart';
import 'package:mobile/features/recommendation/screens/recommendation_list_screen.dart';
import 'package:mobile/features/recommendation/screens/recommended_player_detail_screen.dart';
import 'package:mobile/features/recommendation/screens/no_recommendations_screen.dart';
import 'package:mobile/features/recommendation/data/recommendation_repository.dart';
import 'package:mobile/features/recommendation/data/recommendation_fixtures.dart';
import 'package:mobile/features/feedback/screens/match_completed_screen.dart';
import 'package:mobile/features/feedback/screens/feedback_form_screen.dart';
import 'package:mobile/features/feedback/screens/rating_history_screen.dart';
import 'package:mobile/features/feedback/screens/community_rating_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final cupertino = FontLoader('CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await Future.wait([material.load(), cupertino.load()]);
  });
  const facility = FacilityCardItem(
    id: 1,
    name: 'Sunrise Badminton Club',
    address: 'Da Nang, Vietnam',
    courtCount: 6,
    operatingHours: '06:00 - 22:00',
  );
  final facilityData = <String, dynamic>{
    'id': 1,
    'name': facility.name,
    'address': facility.address,
    'description': 'A modern badminton facility with high-quality courts and a friendly community.',
    'courts': List.generate(
      6,
      (i) => {
        'id': i + 1,
        'name': 'Sân ${i + 1}',
        'courtType': 'INDOOR',
        'status': 'ACTIVE',
      },
    ),
    'operatingHours': List.generate(
      6,
      (i) => {'dayOfWeek': i + 1, 'openTime': '06:00', 'closeTime': '22:00'},
    ),
  };
  final screens = <String, Widget Function()>{
    's1-login': () => const LoginScreen(),
    's1-register': () => const CreateAccountScreen(),
    's1-forgot': () => const ForgotPasswordScreen(),
    's1-verify': () => const VerifyCodeScreen(),
    's1-reset': () => const CreateNewPasswordScreen(),
    's1-player': () => const PlayerWelcomeScreen(),
    's1-owner': () => const CourtOwnerWelcomeScreen(),
    's1-admin': () => const AdminWelcomeScreen(),
    's2-profile': () => const PlayerProfileScreen(),
    's2-edit': () => const EditProfileScreen(),
    's2-skill': () => const SkillAssessmentScreen(),
    's2-preferences': () => const MatchPreferencesScreen(),
    's3-facilities': () => const FacilityListScreen(),
    's3-detail': () => const FacilityDetailScreen(facility: facility),
    's3-court': () => const AddEditCourtScreen(facilityId: 1),
    's3-hours': () => const OperatingHoursScreen(facilityId: 1),
    's4-schedule': () => const BookingFacilityScheduleScreen(),
    's4-summary': () => const BookingSummaryScreen(),
    's4-success': () => const BookingSuccessScreen(),
    's4-history': () => const BookingHistoryScreen(),
    's4-detail': () => const BookingDetailScreen(),
    's5-list': () => const MatchListScreen(),
    's5-create': () => const CreateMatchScreen(),
    's5-open': () => const MatchDetailOpenScreen(),
    's5-private': () => const MatchDetailOpenScreen(
      draft: MatchDraft(
        title: 'Team Practice',
        description: 'Invite-only practice match.',
        isPrivate: true,
        gameType: 'Doubles',
        requiredPlayers: 4,
        skillLevel: 'Advanced',
      ),
    ),
    's5-invitations': () => const MatchInvitationsScreen(),
    's5-requests': () => const MatchJoinRequestsScreen(),
    's5-participants': () => const MatchParticipantListScreen(),
    's6-courts': () => const FindCourtsMapScreen(),
    's6-preview': () => const CourtPreviewScreen(),
    's6-players': () => const FindPlayersMapScreen(),
    's7-list': () => const RecommendationListScreen(),
    's7-detail': () =>
        RecommendedPlayerDetailScreen(player: referenceRecommendations.first),
    's7-empty': () => const NoRecommendationsScreen(),
    's8-completed': () => const MatchCompletedScreen(),
    's8-form': () => const FeedbackFormScreen(),
    's8-history': () => const RatingHistoryScreen(),
    's8-community': () => const CommunityRatingScreen(),
    's8-submitted': () => const FeedbackSubmittedScreen(),
  };
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('Sprint 1–8 layout audit at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = ApiClient.instance;
      client.setToken('layout-fixture');
      AuthService.instance.currentUser = {
        'fullName': 'Phúc Mai',
        'role': 'PLAYER',
      };
      final interceptor = InterceptorsWrapper(
        onRequest: (o, h) {
          final data = switch (o.path) {
            '/facilities/my' => [
              facilityData,
              {...facilityData, 'id': 2, 'name': 'Rally Point Sports Center'},
              {...facilityData, 'id': 3, 'name': 'Ace Badminton Hall'},
            ],
            '/facilities/1' => facilityData,
            '/players/profile/me' => {
              'id': 1,
              'fullName': 'Phúc Mai',
              'playerProfile': {
                'bio': 'Badminton enthusiast. Always up for a friendly match and improving together!',
              },
            },
            '/preferences/me' => {
              'preferredMode': 'DOUBLES',
              'purpose': 'CASUAL',
              'minSkillLevel': 3,
              'maxSkillLevel': 4,
              'maxDistanceKm': 5,
            },
            '/availability/me' => [
              {
                'id': 1,
                'dayOfWeek': 1,
                'startTime': '18:00',
                'endTime': '22:00',
              },
            ],
            _ => <String, dynamic>{},
          };
          h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
        },
      );
      client.dio.interceptors.add(interceptor);
      addTearDown(() {
        client.clearToken();
        AuthService.instance.currentUser = null;
        client.dio.interceptors.remove(interceptor);
      });
      for (final entry in screens.entries) {
        await tester.pumpWidget(const SizedBox());
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recommendationRepositoryProvider.overrideWithValue(
                const FixtureRecommendationRepository(),
              ),
            ],
            child: MaterialApp(
              theme: SMatchTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 52, bottom: 34),
                  viewPadding: const EdgeInsets.only(top: 52, bottom: 34),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: boundary, child: entry.value()),
              ),
            ),
          ),
        );
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(tester.takeException(), isNull, reason: entry.key);
        if (const bool.fromEnvironment('SMATCH_CAPTURE') && size.width == 393) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('/tmp/smatch-layout-captures')
                .create(recursive: true);
            await File('/tmp/smatch-layout-captures/${entry.key}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
