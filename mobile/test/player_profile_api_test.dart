import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/services/player_profile_service.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/auth/screens/edit_profile_screen.dart';

void main() {
  final client = ApiClient.instance;
  final service = PlayerProfileService.instance;
  final requests = <RequestOptions>[];
  late Interceptor interceptor;
  late Map<String, dynamic> stored;
  int? patchError;
  bool delayPatch = false;
  RequestInterceptorHandler? pendingPatch;
  RequestOptions? pendingOptions;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    client.setToken('profile-test-token');
    AuthService.instance.currentUser = {
      'id': 9,
      'fullName': 'Tên đăng nhập',
      'role': 'PLAYER',
    };
    requests.clear();
    patchError = null;
    delayPatch = false;
    pendingPatch = null;
    stored = {
      'id': 9,
      'fullName': 'Nguyễn Văn An',
      'role': {'name': 'PLAYER'},
      'playerProfile': {'bio': 'Bio từ máy chủ'},
    };
    interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        if (options.method == 'PATCH') {
          if (delayPatch) {
            pendingPatch = handler;
            pendingOptions = options;
            return;
          }
          if (patchError != null) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: patchError,
                  data: {'message': 'Không lưu được hồ sơ'},
                ),
              ),
            );
            return;
          }
          final data = options.data as Map;
          stored = {
            ...stored,
            'fullName': data['fullName'],
            'playerProfile': {'bio': data['bio']},
          };
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: stored),
          true,
        );
      },
    );
    client.dio.interceptors.add(interceptor);
  });
  tearDown(() {
    client.dio.interceptors.remove(interceptor);
    client.clearToken();
    AuthService.instance.currentUser = null;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  test('GET reads the current user and PATCH only sends supported fields with bearer token', () async {
    final before = await service.getMyProfile();
    expect(before.fullName, 'Nguyễn Văn An');
    final saved = await service.updateMyProfile(
      fullName: '  Trần Thị Bình  ',
      bio: 'Tiểu sử mới',
    );
    expect(saved.fullName, 'Trần Thị Bình');
    expect(saved.bio, 'Tiểu sử mới');
    final patch = requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/players/profile/me');
    expect(patch.data, {'fullName': 'Trần Thị Bình', 'bio': 'Tiểu sử mới'});
    expect(patch.headers['Authorization'], 'Bearer profile-test-token');
    expect(AuthService.instance.currentUser?['role'], 'PLAYER');
    expect(AuthService.instance.currentUser?['fullName'], 'Trần Thị Bình');
  });

  test(
    'no session never sends a request or silently logs in as another account',
    () async {
      client.clearToken();
      await expectLater(
        service.updateMyProfile(fullName: 'A', bio: ''),
        throwsA(isA<PlayerProfileException>()),
      );
      expect(requests, isEmpty);
    },
  );

  test(
    'session change rejects an old response without changing the next account',
    () async {
      final other = InterceptorsWrapper(
        onResponse: (response, handler) {
          client.setToken('new-session');
          AuthService.instance.currentUser = {
            'id': 11,
            'fullName': 'Tài khoản khác',
            'role': 'PLAYER',
          };
          handler.next(response);
        },
      );
      client.dio.interceptors.add(other);
      addTearDown(() => client.dio.interceptors.remove(other));
      await expectLater(
        service.updateMyProfile(fullName: 'Tên cũ', bio: ''),
        throwsA(isA<PlayerProfileException>()),
      );
      expect(AuthService.instance.currentUser?['fullName'], 'Tài khoản khác');
    },
  );

  testWidgets(
    'save prefilled real fields, update Profile and reopen with saved values',
    (tester) async {
      await pump(tester, const PlayerProfileScreen());
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      await tester.tap(find.text('Nguyễn Văn An'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'Nguyễn Văn An',
      );
      expect(
        tester.widget<TextField>(fields.at(2)).controller!.text,
        'Bio từ máy chủ',
      );
      await tester.enterText(fields.first, 'Trần Thị Bình');
      await tester.enterText(fields.at(2), 'Tiểu sử đã cập nhật');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Trần Thị Bình'), findsOneWidget);
      expect(
        find.textContaining('Tiểu sử đã cập nhật', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Trần Thị Bình'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Trần Thị Bình',
      );
    },
  );

  testWidgets('401 keeps the draft, stays in Edit and offers a useful error', (
    tester,
  ) async {
    patchError = 401;
    await pump(tester, const EditProfileScreen());
    await tester.enterText(find.byType(TextField).first, 'Tên chưa lưu');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Tên chưa lưu',
    );
    expect(find.textContaining('hết hạn'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(AuthService.instance.currentUser?['fullName'], 'Tên đăng nhập');
  });

  testWidgets('pending save disables duplicate submits until server confirms', (
    tester,
  ) async {
    delayPatch = true;
    await pump(tester, const PlayerProfileScreen());
    await tester.tap(find.text('Nguyễn Văn An'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    for (var i = 0; i < 20 && pendingPatch == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(requests.where((r) => r.method == 'PATCH'), hasLength(1));
    pendingPatch!.resolve(
      Response(requestOptions: pendingOptions!, statusCode: 200, data: stored),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('empty full name is rejected before PATCH', (tester) async {
    await pump(tester, const EditProfileScreen());
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    expect(find.text('Vui lòng nhập họ và tên.'), findsOneWidget);
  });

  testWidgets(
    'local-only fields are explicitly reported and never sent to profile API',
    (tester) async {
      await pump(tester, const PlayerProfileScreen());
      await tester.tap(find.text('Nguyễn Văn An'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Left'));
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa được API hỗ trợ lưu'), findsOneWidget);
      final patch = requests.singleWhere((r) => r.method == 'PATCH');
      expect((patch.data as Map).keys.toSet(), {'fullName', 'bio'});
    },
  );
}
