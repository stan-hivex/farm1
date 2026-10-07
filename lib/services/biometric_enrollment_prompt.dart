import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/app_state.dart';
import '/services/biometric_lock_service.dart';

class BiometricEnrollmentPrompt {
  static Future<void> showAfterLogin(BuildContext context) async {
    final appState = FFAppState();
    if (!appState.isLoggedIn || !appState.isUser) {
      return;
    }

    final biometricService = BiometricLockService();
    var canEnrollBiometrics = false;
    try {
      canEnrollBiometrics = !appState.biometricsEnabled &&
          await biometricService.canUseBiometrics() &&
          (await biometricService.getAvailableBiometrics()).isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('Unable to check biometric enrollment: $error');
      debugPrint(stackTrace.toString());
    }

    final canOfferDarkMode = appState.themeMode != ThemeMode.dark;
    if (!canOfferDarkMode && !canEnrollBiometrics) return;
    if (!context.mounted) return;

    var enableDarkMode = false;
    var enableBiometrics = false;
    final preferences = await showDialog<Map<String, bool>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Personalize your FARM app'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canOfferDarkMode)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enableDarkMode,
                  onChanged: (value) =>
                      setDialogState(() => enableDarkMode = value),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use a dark appearance'),
                ),
              if (canEnrollBiometrics)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enableBiometrics,
                  onChanged: (value) =>
                      setDialogState(() => enableBiometrics = value),
                  title: const Text('Biometric login'),
                  subtitle: const Text(
                    'Use your fingerprint or face to sign in securely',
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'You can change these options later in Profile settings.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'darkMode': enableDarkMode,
                'biometrics': enableBiometrics,
              }),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );

    if (preferences == null || !context.mounted) return;

    if (canOfferDarkMode) {
      appState.themeMode =
          preferences['darkMode'] == true ? ThemeMode.dark : ThemeMode.light;
    }

    if (preferences['biometrics'] == true) {
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
    }
  }
}
