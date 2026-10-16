import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm/app_state.dart';
import 'package:farm/admin/services/admin_api_service.dart';
import 'package:farm/services/auth/session_store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FFAppState.reset();
  });

  group('AdminApiService token refresh logic', () {
    test('returns true for tokens that are near expiry', () {
      final exp = DateTime.now().add(const Duration(minutes: 1)).toUtc();
      final token = _buildJwt(exp);

      expect(AdminApiService.tokenNeedsRefresh(token), isTrue);
    });

    test('returns false for tokens with plenty of life left', () {
      final exp = DateTime.now().add(const Duration(hours: 2)).toUtc();
      final token = _buildJwt(exp);

      expect(AdminApiService.tokenNeedsRefresh(token), isFalse);
    });
  });

  test('restores the active superadmin session into app state for API calls',
      () async {
    final accessToken = _buildJwt(
      DateTime.now().add(const Duration(hours: 2)).toUtc(),
    );
    await AuthSessionStore.saveRoleSession(
      role: 'super_admin',
      accessToken: accessToken,
      refreshToken: 'superadmin-refresh-token',
      userId: 'superadmin-id',
    );

    final token = await AdminApiService.getValidAccessToken();

    expect(token, accessToken);
    expect(FFAppState().accessToken, accessToken);
    expect(FFAppState().refreshToken, 'superadmin-refresh-token');
    expect(FFAppState().role, 'super_admin');
    expect(FFAppState().userId, 'superadmin-id');
    expect(FFAppState().isLoggedIn, isTrue);
  });

  test('resolves a superadmin token when the persisted role marker is missing',
      () async {
    final accessToken = _buildJwt(
      DateTime.now().add(const Duration(hours: 2)).toUtc(),
    );
    FFAppState().role = 'super_admin';
    FFAppState().accessToken = accessToken;
    FFAppState().refreshToken = 'superadmin-refresh-token';
    FFAppState().userId = 'superadmin-id';

    final token = await AdminApiService.getValidAccessToken();

    expect(token, accessToken);
    expect(await AuthSessionStore.readActiveRole(), 'super_admin');
  });

  test(
      'resolves the logged-in admin session when a stale superadmin marker exists',
      () async {
    final adminToken = _buildJwt(
      DateTime.now().add(const Duration(hours: 2)).toUtc(),
    );
    final staleSuperadminToken = _buildJwt(
      DateTime.now().add(const Duration(hours: 3)).toUtc(),
    );
    await AuthSessionStore.saveRoleSession(
      role: 'admin',
      accessToken: adminToken,
      refreshToken: 'admin-refresh-token',
      userId: 'admin-id',
    );
    await AuthSessionStore.saveRoleSession(
      role: 'super_admin',
      accessToken: staleSuperadminToken,
      refreshToken: 'superadmin-refresh-token',
      userId: 'superadmin-id',
    );
    FFAppState().role = 'admin';

    final token = await AdminApiService.getValidAccessToken();

    expect(token, adminToken);
    expect(FFAppState().accessToken, adminToken);
    expect(FFAppState().refreshToken, 'admin-refresh-token');
    expect(FFAppState().role, 'admin');
    expect(await AuthSessionStore.readActiveRole(), 'admin');
  });
}

String _buildJwt(DateTime expiry) {
  final payload = {
    'exp': expiry.millisecondsSinceEpoch ~/ 1000,
  };
  final header = {'alg': 'none', 'typ': 'JWT'};
  final encodedHeader = base64Url.encode(utf8.encode(jsonEncode(header)));
  final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$encodedHeader.$encodedPayload.signature';
}
