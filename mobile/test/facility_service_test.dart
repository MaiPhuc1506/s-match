import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/facility/services/facility_service.dart';

void main() {
  test(
    'facility requests use owner token and backend payload formats',
    () async {
      final requests = <RequestOptions>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = switch (options.path) {
            '/auth/login' => {'accessToken': 'test-token'},
            '/facilities/my' => [
              {
                'id': 42,
                'name': 'Owner facility',
                'courts': [],
                'operatingHours': [],
              },
            ],
            _ => <String, dynamic>{},
          };
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: options.method == 'POST' ? 201 : 200,
              data: data,
            ),
          );
        },
      );
      ApiClient.instance.dio.interceptors.add(interceptor);
      addTearDown(
        () => ApiClient.instance.dio.interceptors.remove(interceptor),
      );

      final facilities = await FacilityService.instance.getMyFacilities();
      expect(facilities?.single['id'], 42);

      final added = await FacilityService.instance.addCourt(
        facilityId: 42,
        name: 'Court 1',
        courtType: 'Indoor',
        status: 'Active',
      );
      expect(added, isTrue);

      final days = [
        {'dayOfWeek': 0, 'openTime': '06:00', 'closeTime': '22:00'},
      ];
      expect(
        await FacilityService.instance.updateOperatingHours(
          facilityId: 42,
          days: days,
        ),
        isTrue,
      );

      expect(requests.map((request) => request.path), [
        '/auth/login',
        '/facilities/my',
        '/facilities/42/courts',
        '/facilities/42/operating-hours/bulk',
      ]);
      for (final request in requests.skip(1)) {
        expect(request.headers['Authorization'], 'Bearer test-token');
      }
      expect(requests[2].data, {
        'name': 'Court 1',
        'courtType': 'INDOOR',
        'status': 'ACTIVE',
      });
      expect(requests[3].data, {'days': days});
    },
  );
}
