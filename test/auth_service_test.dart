import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/core/network/api_exception.dart';
class MemoryStore implements SessionStore {
 String? value;
 @override Future<String?> read() async => value;
 @override Future<void> write(String text) async {value=text;}
 @override Future<void> clear() async {value=null;}
}
String session(String access,String refresh)=>jsonEncode({'accessToken':access,'refreshToken':refresh,'user':{'email':'test@example.com','onboardingCompleted':true}});
void main() {
 test('Sai mật khẩu không lưu phiên',() async {
  final store=MemoryStore();
  final auth=AuthService(store:store,baseUrl:'http://localhost/api/v1',client:MockClient((_) async=>http.Response('{"code":"INVALID_CREDENTIALS"}',401)));
  await expectLater(auth.login(email:'test@example.com',password:'wrong',remember:true),throwsA(isA<ApiException>()));
  expect(auth.signedIn,false);expect(store.value,null);
 });
 test('401 đổi refresh một lần, logout xóa phiên',() async {
  final store=MemoryStore();var rotations=0;
  final auth=AuthService(store:store,baseUrl:'http://localhost/api/v1',client:MockClient((request) async {
   if(request.url.path.endsWith('/login')) return http.Response(session('old','refresh1'),200);
   if(request.url.path.endsWith('/refresh')) {rotations++;expect(jsonDecode(request.body)['refreshToken'],'refresh1');return http.Response(session('new','refresh2'),200);}
   if(request.url.path.endsWith('/logout')) return http.Response('',204);
   if(request.headers['Authorization']=='Bearer old') return http.Response('{}',401);
   return http.Response('{"email":"test@example.com","onboardingCompleted":true}',200);
  }));
  await auth.login(email:'test@example.com',password:'TestPass123',remember:true);
  await auth.loadProfile();expect(rotations,1);expect(store.value,contains('refresh2'));
  await auth.logout();expect(auth.signedIn,false);expect(store.value,null);
 });
}
