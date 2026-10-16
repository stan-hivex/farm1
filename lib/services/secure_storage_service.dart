import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  static Future<String?> _readValue(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    return _secureStorage.read(key: key);
  }

  static Future<void> _writeValue(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  static Future<void> _deleteValue(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    await _secureStorage.delete(key: key);
  }

  static Future<DateTime?> readBiometricLastVerified() async {
    final stored = await _readValue('biometric_last_verified');
    return stored == null ? null : DateTime.tryParse(stored);
  }

  static Future<void> writeBiometricLastVerified(String value) async {
    await _writeValue('biometric_last_verified', value);
  }

  static Future<void> deleteBiometricLastVerified() async {
    await _deleteValue('biometric_last_verified');
  }

  static Future<void> writeDeviceFingerprint(String value) async {
    await _writeValue('device_fingerprint', value);
  }

  static Future<void> writeDeviceId(String value) async {
    await _writeValue('device_id', value);
  }

  static Future<String?> readDeviceId() async {
    return _readValue('device_id');
  }

  static Future<String?> readDeviceFingerprint() async {
    return _readValue('device_fingerprint');
  }

  static Future<void> clearBiometricData() async {
    await _deleteValue('biometric_last_verified');
    await _deleteValue('device_fingerprint');
    await _deleteValue('device_id');
  }

  static Future<String?> readAccessToken() async {
    final token = await _readValue('auth_token');
    if (token != null && token.isNotEmpty) return token;

    final legacyToken = await _readValue('accessToken');
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await writeAccessToken(legacyToken);
    }
    return legacyToken;
  }

  static Future<String?> readRefreshToken() async {
    final token = await _readValue('refresh_token');
    if (token != null && token.isNotEmpty) return token;

    final legacyToken = await _readValue('refreshToken');
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await writeRefreshToken(legacyToken);
    }
    return legacyToken;
  }

  static Future<void> writeAccessToken(String token) async {
    await _writeValue('auth_token', token);
  }

  static Future<void> writeRefreshToken(String token) async {
    await _writeValue('refresh_token', token);
  }

  static Future<String?> readUserId() async {
    final userId = await _readValue('user_id');
    if (userId != null && userId.isNotEmpty) return userId;

    final legacyUserId = await _readValue('userId');
    if (legacyUserId != null && legacyUserId.isNotEmpty) {
      await writeUserId(legacyUserId);
    }
    return legacyUserId;
  }

  static Future<void> writeUserId(String userId) async {
    await _writeValue('user_id', userId);
  }

  static Future<String?> readRole() async {
    final role = await _readValue('user_role');
    if (role != null && role.isNotEmpty) return role;

    final legacyRole = await _readValue('role');
    if (legacyRole != null && legacyRole.isNotEmpty) {
      await writeRole(legacyRole);
    }
    return legacyRole;
  }

  static Future<void> writeRole(String role) async {
    await _writeValue('user_role', role);
  }

  static Future<bool> readIsLoggedIn() async {
    final storedValue = await _readValue('isLoggedIn');
    if (storedValue != null) return storedValue.toLowerCase() == 'true';

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<void> writeIsLoggedIn(bool value) async {
    await _writeValue('isLoggedIn', value.toString());
  }

  static Future<String?> readValue(String key) => _readValue(key);

  static Future<void> writeValue(String key, String value) =>
      _writeValue(key, value);

  static Future<void> deleteValue(String key) => _deleteValue(key);

  static Future<String?> readLegacyPreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> removeLegacyAuthPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('accessToken'),
      prefs.remove('refreshToken'),
      prefs.remove('userId'),
      prefs.remove('role'),
      prefs.remove('isLoggedIn'),
      prefs.remove('active_auth_role'),
      prefs.remove('user_session'),
      prefs.remove('admin_session'),
      prefs.remove('super_admin_session'),
      prefs.remove('adminToken'),
      prefs.remove('adminRefreshToken'),
      prefs.remove('adminRole'),
    ]);
  }

  static Future<String?> readLastAuthenticatedRoute() async =>
      _readValue('lastAuthenticatedRoute');

  static Future<void> writeLastAuthenticatedRoute(String route) async {
    await _writeValue('lastAuthenticatedRoute', route);
  }

  static Future<void> clearSessionMetadata() async {
    await _deleteValue('user_id');
    await _deleteValue('user_role');
    await _deleteValue('lastAuthenticatedRoute');
  }

  static Future<void> clearAuthData() async {
    await _deleteValue('auth_token');
    await _deleteValue('refresh_token');
    await _deleteValue('accessToken');
    await _deleteValue('refreshToken');
    await _deleteValue('isLoggedIn');
    await clearSessionMetadata();
    await removeLegacyAuthPreferences();
  }
}
