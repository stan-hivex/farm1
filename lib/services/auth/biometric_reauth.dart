import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/app_state.dart';
import '/core/app_config.dart';
import '/services/auth/device_identity.dart';
import '/services/auth/session_store_service.dart';
import '/services/device_fingerprint_service.dart';
import '/services/secure_storage_service.dart';

/// Asks the backend for a new session after a local biometric unlock.
///
/// `POST /auth/biometric-reauth` is the session-refresh path that replaces an
/// SMS code. A missing route (404/405) leaves the stored session untouched.
class BiometricReauth {
  static http.Client client = http.Client();

  /// Returns a login-shaped map when the server issued tokens, otherwise null.
  static Future<Map<String, dynamic>?> exchange({
    String? pendingLoginId,
    String? refreshToken,
  }) async {
    final refresh = (refreshToken ?? FFAppState().refreshToken).trim();
    final pending = pendingLoginId?.trim() ?? '';
    if (refresh.isEmpty && pending.isEmpty) return null;

    String? deviceId;
    try {
      deviceId = await DeviceIdentity.instance.deviceId();
    } catch (_) {
      deviceId = null;
    }
    String fingerprint = '';
    try {
      fingerprint = await DeviceFingerprintService.getDeviceFingerprint();
    } catch (_) {
      fingerprint = '';
    }
    if (fingerprint.isEmpty) return null;

    http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('${AppConfig.api}/auth/biometric-reauth'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'device_fingerprint': fingerprint,
              if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
              if (refresh.isNotEmpty) 'refresh_token': refresh,
              if (pending.isNotEmpty) 'pending_login_id': pending,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[BiometricReauth] request failed: $e');
      return null;
    }

    if (response.statusCode == 404 || response.statusCode == 405) {
      debugPrint('[BiometricReauth] endpoint not deployed yet');
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[BiometricReauth] rejected ${response.statusCode}');
      return null;
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    final payload = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final access = (payload['access_token'] ?? '').toString();
    final nextRefresh = (payload['refresh_token'] ?? '').toString();
    if (access.isEmpty) return null;

    final effectiveRefresh = nextRefresh.isNotEmpty ? nextRefresh : refresh;
    FFAppState().accessToken = access;
    if (effectiveRefresh.isNotEmpty) {
      FFAppState().refreshToken = effectiveRefresh;
    }
    FFAppState().isLoggedIn = true;
    FFAppState().needsBiometricReauth = false;
    await SecureStorageService.writeAccessToken(access);
    if (effectiveRefresh.isNotEmpty) {
      await SecureStorageService.writeRefreshToken(effectiveRefresh);
    }
    final role = FFAppState().role.trim().isEmpty ? 'user' : FFAppState().role;
    FFAppState().role = role;
    try {
      await AuthSessionStore.saveRoleSession(
        role: role,
        accessToken: access,
        refreshToken: effectiveRefresh,
        userId: FFAppState().userId,
      );
    } catch (e) {
      debugPrint('[BiometricReauth] could not persist session: $e');
    }
    return {
      'success': true,
      'data': {
        'access_token': access,
        'refresh_token': effectiveRefresh,
        'requiresPhoneVerification': false,
        if (payload['user'] != null) 'user': payload['user'],
      },
    };
  }
}
