import 'package:farm/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm/services/biometric_lock_service.dart';

void main() {
  test('does not require unlock when biometrics are disabled', () async {
    FFAppState.reset();
    expect(await BiometricLockService().shouldRequireUnlock(), isFalse);
  });

  group('BiometricLockService.hasLockTimeoutElapsed', () {
    final backgroundedAt = DateTime.utc(2026, 11, 2, 8);

    test('does not lock before the configured timeout', () {
      expect(
        BiometricLockService.hasLockTimeoutElapsed(
          since: backgroundedAt,
          timeoutSeconds: 60,
          now: backgroundedAt.add(const Duration(seconds: 59)),
        ),
        isFalse,
      );
    });

    test('locks when the configured timeout has elapsed', () {
      expect(
        BiometricLockService.hasLockTimeoutElapsed(
          since: backgroundedAt,
          timeoutSeconds: 60,
          now: backgroundedAt.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
    });
  });
}
