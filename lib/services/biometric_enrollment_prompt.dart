import 'package:flutter/material.dart';

import '/app_state.dart';
import '/services/biometric_lock_service.dart';

class BiometricEnrollmentPrompt {
  static bool _isShowing = false;

  static Future<void> showAfterLogin(BuildContext context) async {
    if (_isShowing || !context.mounted) return;

    _isShowing = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;

      final appState = FFAppState();
      if (appState.themeMode != ThemeMode.dark) {
        final enableDarkMode = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _DarkModePromptScreen(),
        );

        if (!context.mounted) return;
        appState.themeMode =
            enableDarkMode == true ? ThemeMode.dark : ThemeMode.light;
      }

      if (!context.mounted || appState.biometricsEnabled) return;

      final biometricService = BiometricLockService();
      final canEnroll = await _canEnrollBiometrics(biometricService);
      if (!context.mounted) return;

      final enableBiometrics = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BiometricPromptScreen(canEnroll: canEnroll),
      );

      if (enableBiometrics != true || !context.mounted) return;

      try {
        final enabled = await biometricService.enableBiometrics();
        if (enabled && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometrics enabled')),
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Unable to enable biometrics after login: $error');
        debugPrint(stackTrace.toString());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometrics were not enabled. You can try again in Profile settings.',
              ),
            ),
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to show login preferences: $error');
      debugPrint(stackTrace.toString());
    } finally {
      _isShowing = false;
    }
  }

  static Future<bool> _canEnrollBiometrics(
    BiometricLockService biometricService,
  ) async {
    try {
      return await biometricService.canUseBiometrics() &&
          (await biometricService.getAvailableBiometrics()).isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('Unable to check biometric enrollment: $error');
      debugPrint(stackTrace.toString());
      return false;
    }
  }
}

class _DarkModePromptScreen extends StatelessWidget {
  const _DarkModePromptScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
              ),
              const Spacer(),
              Icon(Icons.dark_mode_outlined, size: 88, color: colors.primary),
              const SizedBox(height: 32),
              Text(
                'Make FARM easier on your eyes',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Turn on dark mode for a darker appearance. You can change this anytime in Profile settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Turn on dark mode'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep light mode'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricPromptScreen extends StatelessWidget {
  const _BiometricPromptScreen({required this.canEnroll});

  final bool canEnroll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Not now'),
                ),
              ),
              const Spacer(),
              Icon(Icons.fingerprint, size: 88, color: colors.primary),
              const SizedBox(height: 32),
              Text(
                'Sign in with biometrics',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                canEnroll
                    ? 'Use your fingerprint or face to sign in securely. Your device will ask you to confirm your biometrics.'
                    : 'Biometric authentication is not available on this device. You can enable it later in Profile settings when it is available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              FilledButton(
                onPressed:
                    canEnroll ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Set up biometrics'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue without biometrics'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
