import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/core/app_config.dart';
import '/app_state.dart';

class BiometricApiService {
  static final http.Client _client = http.Client();

  /// POST /api/v1/security/biometrics. `pin` is required to turn biometrics on.
  static Map<String, dynamic> enableBiometricsBody({
    required String deviceFingerprint,
    required String pin,
    String biometricType = 'fingerprint',
  }) =>
      {
        'deviceFingerprint': deviceFingerprint,
        'biometricType': biometricType,
        'pin': pin,
      };

  /// Register a device for biometrics. Returns backend device id on success.
  static Future<String> enableBiometrics({
    required String deviceFingerprint,
    required String pin,
    String biometricType = 'fingerprint',
  }) async {
    final uri = Uri.parse('${AppConfig.api}/security/biometrics');
    final token = FFAppState().accessToken;

    debugPrint('===== BIOMETRIC API REQUEST: enableBiometrics =====');
    debugPrint('POST $uri');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    debugPrint('deviceFingerprint length: ${deviceFingerprint.length}');

    final bodyMap = enableBiometricsBody(
      deviceFingerprint: deviceFingerprint,
      pin: pin,
      biometricType: biometricType,
    );

    final body = jsonEncode(bodyMap);

    final res = await _client.post(uri, headers: headers, body: body);

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response: ${res.body}');
    debugPrint('headers: ${res.headers}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_errorMessage(res.body, res.statusCode));
    }

    final decoded = jsonDecode(res.body);
    final root = decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
    final id = root['device_id'] ?? root['deviceId'];
    if (id == null || '$id'.isEmpty) {
      throw Exception('Biometrics could not be turned on.');
    }
    return id.toString();
  }

  static String _errorMessage(String body, int status) {
    try {
      final decoded = jsonDecode(body);
      final message = decoded is Map ? decoded['message'] : null;
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) {
        return message.map((e) => '$e').join(' ');
      }
    } catch (_) {}
    if (status == 400 || status == 401 || status == 403) {
      return 'That PIN is not correct.';
    }
    return 'Biometrics could not be turned on.';
  }

  /// Disable biometrics for the current device id.
  static Future<void> disableBiometrics({required String deviceId}) async {
    final uri = Uri.parse('${AppConfig.api}/security/biometrics');
    final token = FFAppState().accessToken;

    debugPrint('===== BIOMETRIC API REQUEST: disableBiometrics =====');
    debugPrint('DELETE $uri');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    // Backend DELETE ignores body and uses authenticated user; send no body to avoid validation issues
    final res = await _client.delete(
      uri,
      headers: headers,
    );

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response: ${res.body}');
    debugPrint('headers: ${res.headers}');

    if (res.statusCode != 200 && res.statusCode != 204) {
      String message = res.body;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'];
        }
      } catch (_) {}
      throw Exception('HTTP ${res.statusCode}: $message\n${res.body}');
    }
  }

  /// Verify a fingerprint against backend (optional flow).
  static Future<bool> verifyBiometrics({
    required String deviceFingerprint,
  }) async {
    final uri = Uri.parse('${AppConfig.api}/security/verify-device');
    final token = FFAppState().accessToken;

    debugPrint('===== BIOMETRIC API REQUEST: verifyBiometrics =====');
    debugPrint('POST $uri');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    debugPrint('deviceFingerprint: $deviceFingerprint');
    debugPrint('deviceFingerprint.runtimeType: ${deviceFingerprint.runtimeType}');
    final bodyMap = {'deviceFingerprint': deviceFingerprint};
    debugPrint('request body: $bodyMap');

    final body = jsonEncode(bodyMap);

    final res = await _client.post(uri, headers: headers, body: body);

    debugPrint('statusCode: ${res.statusCode}');
    debugPrint('response: ${res.body}');
    debugPrint('headers: ${res.headers}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      String message = res.body;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] is String) {
          message = decoded['message'];
        }
      } catch (_) {}
      throw Exception('HTTP ${res.statusCode}: $message\n${res.body}');
    }

    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['verified'] == true || decoded['success'] == true;
    } catch (e) {
      rethrow;
    }
  }
}
