import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/auth/screens/edit_profile_screen.dart';
import 'package:mobile/features/auth/screens/skill_assessment_screen.dart';
import 'package:mobile/features/auth/screens/match_preferences_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Profile retains edit, assessment, preferences and logout navigation',
    (tester) async {
      ApiClient.instance.setToken('profile-ui-regression');
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.data;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'fullName': data is Map ? data['fullName'] : 'Phúc Mai',
                'playerProfile': {
                  'bio': data is Map ? data['bio'] : 'Badminton enthusiast.',
                },
              },
            ),
          );
        },
      );
      ApiClient.instance.dio.interceptors.add(interceptor);
      addTearDown(() {
        ApiClient.instance.clearToken();
        ApiClient.instance.dio.interceptors.remove(interceptor);
      });
      await pump(tester, const PlayerProfileScreen());
      await tester.tap(find.text('Phúc Mai'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Tên thử nghiệm');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerProfileScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingHistoryScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(BookingHistoryScreen))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillAssessmentScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Retake Assessment'));
      await tester.tap(find.text('Retake Assessment'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillAssessmentScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(SkillAssessmentScreen))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Playing Style'));
      await tester.tap(find.text('Playing Style'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchPreferencesScreen), findsOneWidget);
      await tester.tap(find.text('Tue'));
      await tester.tap(find.text('Singles'));
      await tester.tap(find.text('Advanced'));
      await tester.tap(find.text('Defensive'));
      await tester.ensureVisible(find.text('Save Preferences'));
      await tester.tap(find.text('Save Preferences'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerProfileScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Edit keeps bio length limit, hand and mode selection', (
    tester,
  ) async {
    await pump(tester, const EditProfileScreen());
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(2), 'a' * 180);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(2)).controller!.text.length, 150);
    await tester.ensureVisible(find.text('Left'));
    await tester.tap(find.text('Left'));
    await tester.tap(find.text('Both'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Preferences preserves time choices and local state', (
    tester,
  ) async {
    await pump(tester, const MatchPreferencesScreen());
    final dropdown = find.byType(DropdownButton<String>);
    expect(
      tester.widget<DropdownButton<String>>(dropdown.first).value,
      '18:00',
    );
    expect(tester.widget<DropdownButton<String>>(dropdown.last).value, '22:00');
    await tester.tap(dropdown.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('08:00').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<DropdownButton<String>>(dropdown.first).value,
      '08:00',
    );
    expect(tester.takeException(), isNull);
  });

  for (final screen in const [
    PlayerProfileScreen(),
    EditProfileScreen(),
    SkillAssessmentScreen(),
    MatchPreferencesScreen(),
  ]) {
    testWidgets(
      '${screen.runtimeType} remains scrollable on compact displays',
      (tester) async {
        await pump(tester, screen, size: const Size(320, 568));
        final button = screen is PlayerProfileScreen
            ? find.text('Đăng xuất')
            : find.byType(ElevatedButton).last;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(568));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
