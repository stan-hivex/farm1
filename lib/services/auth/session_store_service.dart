import 'dart:convert';

import 'package:flutter/foundation.dart';
import '/services/secure_storage_service.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.userId,
    required this.expiresAt,
    required this.loggedInAt,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
  final String userId;
  final String expiresAt;
  final String loggedInAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken:
          (json['accessToken'] ?? json['auth_token'])?.toString() ?? '',
      refreshToken:
          (json['refreshToken'] ?? json['refresh_token'])?.toString() ?? '',
      role: (json['role'] ?? json['user_role'])?.toString() ?? '',
      userId: (json['userId'] ?? json['user_id'])?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString() ?? '',
      loggedInAt:
          json['loggedInAt']?.toString() ?? json['expiresAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'role': role,
        'userId': userId,
        'expiresAt': expiresAt,
        'loggedInAt': loggedInAt,
      };
}

class AuthSessionStore {
  static const _userSessionKey = 'auth_session_user';
  static const _adminSessionKey = 'auth_session_admin';
  static const _superAdminSessionKey = 'auth_session_super_admin';
  static const _activeRoleKey = 'active_auth_role';

  static Future<String?> readActiveRole() async {
    final secureRole = await SecureStorageService.readRole();
    if (secureRole != null && secureRole.isNotEmpty) {
      return secureRole;
    }

    final legacyActiveRole =
        await SecureStorageService.readLegacyPreference(_activeRoleKey);
    if (legacyActiveRole != null && legacyActiveRole.isNotEmpty) {
      await SecureStorageService.writeRole(legacyActiveRole);
      await SecureStorageService.writeValue(_activeRoleKey, legacyActiveRole);
      return legacyActiveRole;
    }

    final legacyRole =
        await SecureStorageService.readLegacyPreference('role');
    if (legacyRole != null && legacyRole.isNotEmpty) {
      await SecureStorageService.writeRole(legacyRole);
      await SecureStorageService.writeValue(_activeRoleKey, legacyRole);
      return legacyRole;
    }

    return null;
  }

  static Future<AuthSession?> readUserSession() =>
      _readSession(_userSessionKey, 'user');

  static Future<AuthSession?> readAdminSession() =>
      _readSession(_adminSessionKey, 'admin');

  static Future<AuthSession?> readSuperAdminSession() =>
      _readSession(_superAdminSessionKey, 'super_admin');

  static Future<void> saveUserSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String userId,
    String? expiresAt,
    String? loggedInAt,
  }) =>
      _saveSession(
        _userSessionKey,
        role: role,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        expiresAt: expiresAt,
        loggedInAt: loggedInAt,
      );

  static Future<void> saveAdminSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String userId,
    String? expiresAt,
    String? loggedInAt,
  }) =>
      _saveSession(
        _adminSessionKey,
        role: role,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        expiresAt: expiresAt,
        loggedInAt: loggedInAt,
      );

  static Future<void> saveSuperAdminSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String userId,
    String? expiresAt,
    String? loggedInAt,
  }) =>
      _saveSession(
        _superAdminSessionKey,
        role: role,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        expiresAt: expiresAt,
        loggedInAt: loggedInAt,
      );

  static Future<void> saveRoleSession({
    required String role,
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? expiresAt,
    String? loggedInAt,
  }) async {
    final normalizedRole = role.toLowerCase();
    final sessionKey = _sessionKeyForRole(normalizedRole);
    await _saveSession(
      sessionKey,
      role: normalizedRole.isEmpty ? 'user' : normalizedRole,
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: expiresAt,
      loggedInAt: loggedInAt,
    );
  }

  static Future<void> clearUserSession() =>
      _clearSession(_userSessionKey);

  static Future<void> clearAdminSession() =>
      _clearSession(_adminSessionKey);

  static Future<void> clearSuperAdminSession() =>
      _clearSession(_superAdminSessionKey);

  static Future<void> clearRoleSession(String role) async {
    final normalizedRole = role.toLowerCase();
    await _clearSession(_sessionKeyForRole(normalizedRole));
    if ((await readActiveRole()) == normalizedRole) {
      await SecureStorageService.deleteValue(_activeRoleKey);
      await SecureStorageService.clearAuthData();
    }
  }

  static Future<void> clearAllSessions() async {
    await Future.wait([
      SecureStorageService.deleteValue(_userSessionKey),
      SecureStorageService.deleteValue(_adminSessionKey),
      SecureStorageService.deleteValue(_superAdminSessionKey),
      SecureStorageService.deleteValue(_activeRoleKey),
    ]);
    await SecureStorageService.clearAuthData();
  }

  static Future<AuthSession?> readRoleSession(String role) async {
    final normalizedRole = role.toLowerCase();
    final session = await _readSession(
      _sessionKeyForRole(normalizedRole),
      normalizedRole,
    );
    if (session != null) return session;

    if ((await readActiveRole()) != normalizedRole) return null;
    var accessToken = await SecureStorageService.readAccessToken() ?? '';
    var refreshToken = await SecureStorageService.readRefreshToken() ?? '';
    if ((normalizedRole == 'admin' || normalizedRole == 'super_admin') &&
        accessToken.isEmpty &&
        refreshToken.isEmpty) {
      accessToken =
          await SecureStorageService.readLegacyPreference('adminToken') ?? '';
      refreshToken =
          await SecureStorageService.readLegacyPreference('adminRefreshToken') ??
              '';
    }
    final userId = await SecureStorageService.readUserId() ?? '';
    if (accessToken.isEmpty && refreshToken.isEmpty) return null;

    final migrated = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: normalizedRole,
      userId: userId,
      expiresAt: _defaultExpiry,
      loggedInAt: _defaultTimestamp,
    );
    await SecureStorageService.writeValue(
      _sessionKeyForRole(normalizedRole),
      jsonEncode(migrated.toJson()),
    );
    return migrated;
  }

  static Future<String> getTokenForRole(String role) async {
    final session = await readRoleSession(role);
    return session?.accessToken ?? '';
  }

  static Future<void> _saveSession(
    String key, {
    required String role,
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? expiresAt,
    String? loggedInAt,
  }) async {
    final normalizedRole = role.toLowerCase();
    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: normalizedRole,
      userId: userId,
      expiresAt: expiresAt ?? _defaultExpiry,
      loggedInAt: loggedInAt ?? _defaultTimestamp,
    );
    await SecureStorageService.writeValue(key, jsonEncode(session.toJson()));
    await SecureStorageService.writeAccessToken(accessToken);
    await SecureStorageService.writeRefreshToken(refreshToken);
    await SecureStorageService.writeRole(normalizedRole);
    await SecureStorageService.writeUserId(userId);
    await SecureStorageService.writeIsLoggedIn(true);
    await SecureStorageService.writeValue(_activeRoleKey, normalizedRole);
    await SecureStorageService.removeLegacyAuthPreferences();
    debugPrint(
      '[AuthSessionStore] Persisted secure session role=$normalizedRole '
      'accessTokenPresent=${accessToken.isNotEmpty} '
      'refreshTokenPresent=${refreshToken.isNotEmpty}',
    );
  }

  static Future<AuthSession?> _readSession(
    String key,
    String role,
  ) async {
    var raw = await SecureStorageService.readValue(key);
    if (raw == null || raw.isEmpty) {
      raw = await SecureStorageService.readLegacyPreference(
        _legacySessionKeyForRole(role),
      );
      if (raw != null && raw.isNotEmpty) {
        await SecureStorageService.writeValue(key, raw);
      }
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      final session = decoded is Map
          ? AuthSession.fromJson(Map<String, dynamic>.from(decoded))
          : null;
      if (session == null) return null;
      return AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        role: session.role.isEmpty ? role : session.role,
        userId: session.userId,
        expiresAt:
            session.expiresAt.isEmpty ? _defaultExpiry : session.expiresAt,
        loggedInAt:
            session.loggedInAt.isEmpty ? _defaultTimestamp : session.loggedInAt,
      );
    } catch (error) {
      debugPrint('[AuthSessionStore] Could not decode stored $role session: $error');
      return null;
    }
  }

  static Future<void> _clearSession(String key) async {
    await SecureStorageService.deleteValue(key);
    final legacyKey = switch (key) {
      _userSessionKey => 'user_session',
      _adminSessionKey => 'admin_session',
      _superAdminSessionKey => 'super_admin_session',
      _ => '',
    };
    if (legacyKey.isNotEmpty) {
      await SecureStorageService.deleteValue(legacyKey);
    }
  }

  static String _sessionKeyForRole(String role) {
    if (role == 'admin') return _adminSessionKey;
    if (role == 'super_admin') return _superAdminSessionKey;
    return _userSessionKey;
  }

  static String _legacySessionKeyForRole(String role) {
    if (role == 'admin') return 'admin_session';
    if (role == 'super_admin') return 'super_admin_session';
    return 'user_session';
  }

  static String get _defaultTimestamp =>
      DateTime.now().toUtc().toIso8601String();

  static String get _defaultExpiry => DateTime.now()
      .toUtc()
      .add(const Duration(days: 365))
      .toIso8601String();
}
