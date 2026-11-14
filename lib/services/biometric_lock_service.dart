import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '/app_state.dart';
import '/services/secure_storage_service.dart';
import '/services/biometric_api_service.dart';
import '/services/device_fingerprint_service.dart';

class BiometricLockService {
  static final BiometricLockService _instance =
      BiometricLockService._internal();
  factory BiometricLockService() => _instance;
  BiometricLockService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  DateTime? _appBackgroundedAt;

  bool get _isMobileBiometricSupported {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  bool get isAuthenticating => _isAuthenticating;

  Future<bool> isBiometricEnabled() async {
    return FFAppState().biometricsEnabled;
  }

  Future<bool> canUseBiometrics() async {
    if (!_isMobileBiometricSupported) return false;
    try {
      final can = await _localAuth.canCheckBiometrics;
      debugPrint('Biometric available: $can');
      return can;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final list = await _localAuth.getAvailableBiometrics();
      debugPrint('Available biometrics: $list');
      return list;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Confirm your identity',
  }) async {
    if (!await canUseBiometrics()) {
      throw Exception('Biometrics not available on this device');
    }

    final available = await getAvailableBiometrics();
    if (available.isEmpty) {
      throw Exception('No biometric methods enrolled on this device');
    }

    _isAuthenticating = true;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      debugPrint('Authentication result: $authenticated');
      return authenticated;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> markVerified() async {
    final now = DateTime.now();
    await SecureStorageService.writeBiometricLastVerified(
      now.toIso8601String(),
    );
    await SecureStorageService.clearBiometricBackgroundedAt();
    _appBackgroundedAt = null;
    FFAppState().biometricLastVerified = now;
    debugPrint('Stored biometric last verified: ${now.toIso8601String()}');
  }

  Future<void> markAppBackgrounded() async {
    if (_isAuthenticating ||
        !FFAppState().isLoggedIn ||
        !FFAppState().isBiometricAllowed ||
        !_isMobileBiometricSupported) {
      return;
    }

    final now = DateTime.now();
    await SecureStorageService.writeBiometricBackgroundedAt(
      now.toIso8601String(),
    );
    _appBackgroundedAt = now;
    debugPrint('Stored biometric background time: ${now.toIso8601String()}');
  }

  Future<bool> enableBiometrics({required String pin}) async {
    try {
      if (!await canUseBiometrics()) {
        throw Exception('Biometrics not available');
      }

      final authenticated = await authenticate(
        localizedReason: 'Confirm your identity to enable biometric unlock.',
      );

      if (!authenticated) {
        throw Exception('Biometric authentication failed during enrollment');
      }

      final fingerprint = await DeviceFingerprintService.getDeviceFingerprint();
      if (fingerprint.isEmpty) {
        throw Exception('Device fingerprint generation failed');
      }

      final available = await getAvailableBiometrics();

      // Register with backend (deviceFingerprint key expected)
      final deviceId = await BiometricApiService.enableBiometrics(
        deviceFingerprint: fingerprint,
        pin: pin,
        biometricType: available.contains(BiometricType.face)
            ? 'faceID'
            : 'fingerprint',
      );

      // Persist only after backend success
      await SecureStorageService.writeDeviceFingerprint(fingerprint);
      await SecureStorageService.writeDeviceId(deviceId);
      await SecureStorageService.writeBiometricLastVerified(
        DateTime.now().toIso8601String(),
      );
      await SecureStorageService.clearBiometricBackgroundedAt();
      _appBackgroundedAt = null;

      // Update app state
      FFAppState().update(() {
        FFAppState().biometricsEnabled = true;
        FFAppState().biometricLastVerified = DateTime.now();
      });

      debugPrint(
        'Stored fingerprint and deviceId: $deviceId (fingerprint_len=${fingerprint.length})',
      );
      return true;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<bool> disableBiometrics() async {
    try {
      final deviceId = await SecureStorageService.readDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        await BiometricApiService.disableBiometrics(deviceId: deviceId);
      }

      await clearBiometricData();

      FFAppState().update(() {
        FFAppState().biometricsEnabled = false;
        FFAppState().biometricLastVerified = null;
      });

      return true;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<bool> authenticateAndMarkVerified({
    String localizedReason =
        'Confirm your identity to unlock your FARM session.',
  }) async {
    try {
      final ok = await authenticate(localizedReason: localizedReason);
      if (!ok) return false;
      await markVerified();
      return true;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      return false;
    }
  }

  Future<void> clearBiometricData() async {
    await SecureStorageService.clearBiometricData();
    _appBackgroundedAt = null;
    debugPrint('Cleared biometric secure storage');
  }

  Future<DateTime?> getLastVerified() async {
    if (FFAppState().biometricLastVerified != null) {
      return FFAppState().biometricLastVerified;
    }
    final stored = await SecureStorageService.readBiometricLastVerified();
    if (stored != null) {
      FFAppState().biometricLastVerified = stored;
    }
    return stored;
  }

  Future<DateTime?> getAppBackgroundedAt() async {
    if (_appBackgroundedAt != null) return _appBackgroundedAt;
    _appBackgroundedAt =
        await SecureStorageService.readBiometricBackgroundedAt();
    return _appBackgroundedAt;
  }

  @visibleForTesting
  static bool hasLockTimeoutElapsed({
    required DateTime since,
    required int timeoutSeconds,
    required DateTime now,
  }) => now.difference(since).inSeconds >= timeoutSeconds;

  Future<bool> shouldRequireUnlock() async {
    try {
      if (!await isBiometricEnabled()) return false;
      if (!FFAppState().isLoggedIn) return false;
      if (!_isMobileBiometricSupported) return false;

      final backgroundedAt = await getAppBackgroundedAt();
      final lastActivity = backgroundedAt ?? await getLastVerified();
      if (lastActivity == null) return true;

      final lockTimeoutSeconds = FFAppState().biometricLockTimeoutSeconds;
      final now = DateTime.now();
      final elapsed = now.difference(lastActivity).inSeconds;
      debugPrint(
        'Unlock required check: elapsed=$elapsed timeout=$lockTimeoutSeconds',
      );
      final shouldLock = hasLockTimeoutElapsed(
        since: lastActivity,
        timeoutSeconds: lockTimeoutSeconds,
        now: now,
      );
      if (!shouldLock && backgroundedAt != null) {
        await SecureStorageService.clearBiometricBackgroundedAt();
        _appBackgroundedAt = null;
      }
      return shouldLock;
    } catch (e, stack) {
      debugPrint('===== BIOMETRIC ERROR =====');
      debugPrint(e.toString());
      debugPrint(stack.toString());
      rethrow;
    }
  }
}
