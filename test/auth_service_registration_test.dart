import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/services/auth/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers through the backend without requiring Supabase', () async {
    SharedPreferences.setMockInitialValues({});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    await dotenv.load(fileName: '.env');
    late http.Request capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'message': 'Registration successful. OTP sent.'}),
        201,
      );
    });
    ApiService.client = mockClient;

    final response = await AuthService().signUp(
      email: 'han@example.com',
      password: '41324177Stan.',
      firstName: 'Jan',
      lastName: 'Ntaly',
      username: 'jant',
      phone: '+254710103803',
      country: 'Kenya',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/register'));
    expect(jsonDecode(capturedRequest.body), {
      'first_name': 'Jan',
      'last_name': 'Ntaly',
      'username': 'jant',
      'phone': '+254710103803',
      'password': '41324177Stan.',
      'email': 'han@example.com',
      'country': 'Kenya',
    });
    expect(response['message'], contains('Registration successful'));
  });
}