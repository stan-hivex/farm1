import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/farm_mark.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/app_state.dart';
import '/admin/services/admin_api_service.dart';
import '/pages/biometric_unlock_page/biometric_unlock_page_widget.dart';
import '/pages/dashboard/dashboard_widget.dart';
import '/pages/onboarding/onboarding_widget.dart';
import '/pages/superadmin/superadmin_dashboard_page.dart';
import '/services/auth/auth_service.dart';
import '/services/auth/refresh_manager.dart';
import '/services/auth/session_store_service.dart';
import '/services/biometric_lock_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static String routeName = 'SplashPage';
  static String routePath = '/splash';

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkLoginStatus());
  }

  Future<void> checkLoginStatus() async {
    try {
      final session = await AuthService().getSession();
      if (!mounted) return;
      if (session == null ||
          (session.accessToken.isEmpty && session.refreshToken.isEmpty)) {
        _showOnboarding();
        return;
      }

      final role = AuthSessionStore.normalizeRole(session.role);
      if (!const {'user', 'admin', 'super_admin'}.contains(role)) {
        _showOnboarding();
        return;
      }

      final state = FFAppState();
      state.accessToken = session.accessToken;
      state.refreshToken = session.refreshToken;
      state.userId = session.userId;
      state.role = role;
      state.userData = session.userData;
      state.isLoggedIn = true;

      if (!_isJwtUnexpired(session.accessToken)) {
        var refreshed = false;
        try {
          refreshed = role == 'admin' || role == 'super_admin'
              ? await AdminApiService.ensureValidSession(force: true)
              : await RefreshManager().refreshIfNeeded(force: true);
        } catch (error, stackTrace) {
          debugPrint('[SplashPage] Silent token refresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        if (!refreshed) {
          debugPrint(
            '[SplashPage] Keeping restored login after refresh failure.',
          );
        }
      }

      await _routeAuthenticatedSession(role);
    } catch (error, stackTrace) {
      debugPrint('[SplashPage] Could not restore login session: $error');
      debugPrintStack(stackTrace: stackTrace);
      final state = FFAppState();
      final role = AuthSessionStore.normalizeRole(state.role);
      final hasRestoredSession =
          state.accessToken.isNotEmpty || state.refreshToken.isNotEmpty;
      if (hasRestoredSession &&
          const {'user', 'admin', 'super_admin'}.contains(role)) {
        state.isLoggedIn = true;
        await _routeAuthenticatedSession(role);
        return;
      }
      if (mounted) _showOnboarding();
    }
  }

  Future<void> _routeAuthenticatedSession(String role) async {
    final state = FFAppState();
    state.setAuthStartupState(AuthStartupState.authenticated);
    if (state.isBiometricAllowed) {
      try {
        if (await BiometricLockService().shouldRequireUnlock()) {
          if (mounted) {
            context.go(BiometricUnlockPageWidget.routePath);
          }
          return;
        }
      } catch (error, stackTrace) {
        debugPrint('[SplashPage] Biometric startup check failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          context.go(BiometricUnlockPageWidget.routePath);
        }
        return;
      }
    }

    if (!mounted) return;
    switch (role) {
      case 'admin':
        context.go('/admin');
        return;
      case 'super_admin':
        context.go(SuperadminDashboardPage.routePath);
        return;
      default:
        context.go(DashboardWidget.routePath);
        return;
    }
  }

  bool _isJwtUnexpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return false;
      final expiry = decoded['exp'];
      final expirySeconds = expiry is int ? expiry : int.tryParse('$expiry');
      if (expirySeconds == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(
        expirySeconds * 1000,
        isUtc: true,
      ).isAfter(DateTime.now().toUtc());
    } catch (error) {
      debugPrint('[SplashPage] Could not parse saved JWT expiry: $error');
      return false;
    }
  }

  void _showOnboarding() {
    FFAppState().isLoggedIn = false;
    FFAppState().setAuthStartupState(AuthStartupState.unauthenticated);
    if (mounted) context.go(OnboardingWidget.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FarmMark(size: 72),
            const SizedBox(height: 16),
            Text(
              'FARM',
              style: theme.titleLarge.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Loading your experience…', style: theme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
