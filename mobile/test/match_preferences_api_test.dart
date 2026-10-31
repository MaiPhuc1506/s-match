import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/match_preferences_service.dart';

void main() {
  final client = ApiClient.instance;
  final service = MatchPreferencesService.instance;
  late InterceptorsWrapper interceptor;
  final requests = <RequestOptions>[];
  setUp(() {
    requests.clear(); client.setToken('preferences-test');
    interceptor = InterceptorsWrapper(onRequest: (o,h) {
      requests.add(o);
      h.resolve(Response(requestOptions: o, statusCode: 200, data:
        o.path == '/availability/me' && o.method == 'GET' ? [] :
        o.path == '/preferences/me' && o.method == 'GET' ? null : {}));
    });
    client.dio.interceptors.add(interceptor);
  });
  tearDown(() { client.dio.interceptors.remove(interceptor); client.clearToken(); });
  test('load uses existing authenticated preference and availability endpoints', () async {
    final state = await service.load();
    expect(state.preference, isNull); expect(state.availability, isEmpty);
    expect(requests.map((o)=>o.path), ['/preferences/me','/availability/me']);
    expect(requests.first.headers['Authorization'], 'Bearer preferences-test');
  });
  test('save preserves unrepresented purpose and radius and synchronizes days', () async {
    await service.save(mode:'Doubles',minLevel:3,maxLevel:4,days:{1,3},from:'18:00',to:'22:00',
      existingPreference:{'purpose':'TRAINING','maxDistanceKm':12}, existingAvailability:[
        {'id':11,'dayOfWeek':1},{'id':12,'dayOfWeek':5}]);
    expect(requests.map((o)=>'${o.method} ${o.path}'), [
      'PUT /preferences/me','PATCH /availability/me/11','POST /availability/me','DELETE /availability/me/12']);
    expect(requests.first.data, {'preferredMode':'DOUBLES','purpose':'TRAINING',
      'minSkillLevel':3,'maxSkillLevel':4,'maxDistanceKm':12});
    expect((requests.first.data as Map).containsKey('playingStyle'), isFalse);
  });
  test('unsupported Both and multi-window schedules never write', () async {
    Future<void> save(String mode, List<Map<String,dynamic>> slots) => service.save(
      mode:mode,minLevel:1,maxLevel:5,days:{1},from:'18:00',to:'22:00',
      existingPreference:null,existingAvailability:slots);
    await expectLater(save('Both', []), throwsA(isA<MatchPreferencesFailure>()));
    await expectLater(save('Singles', [{'id':1,'dayOfWeek':1},{'id':2,'dayOfWeek':1}]),
      throwsA(isA<MatchPreferencesFailure>()));
    expect(requests,isEmpty);
  });
  test('signed-out save makes no request', () async {
    client.clearToken();
    await expectLater(service.save(mode:'Doubles',minLevel:1,maxLevel:5,days:{1},
      from:'18:00',to:'22:00',existingPreference:null,existingAvailability:[]),
      throwsA(isA<MatchPreferencesFailure>()));
    expect(requests,isEmpty);
  });
}
