import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/app_state.dart';
import '/services/biometric_lock_service.dart';
import '/services/transaction_authorization_service.dart';
import '/utils/user_error_message.dart';

/// Result of the shared payment confirm. Biometrics is only set when the
/// caller says the endpoint accepts `biometric_auth`.
class PaymentConfirmation {
  const PaymentConfirmation.pin(this.pin)
      : biometric = false,
        deviceFingerprint = null;

  const PaymentConfirmation.biometric(this.deviceFingerprint)
      : biometric = true,
        pin = null;

  final bool biometric;
  final String? pin;
  final String? deviceFingerprint;

  /// Body fields the existing wallet, withdraw, QR, escrow, and payment-request
  /// routes already accept. Do not send this to a PIN-only route.
  Map<String, dynamic> authFields() {
    if (biometric) {
      return {
        'biometric_auth': true,
        'device_fingerprint': deviceFingerprint,
        'pin': null,
      };
    }
    return {'pin': pin};
  }
}

/// One confirm step. When [biometricSupported] is true and biometrics are on,
/// the device prompt comes first and the PIN is the fallback. PIN-only
/// endpoints must pass false so the app does not pretend the server accepted
/// a fingerprint.
Future<PaymentConfirmation?> confirmPayment(
  BuildContext context, {
  required String title,
  required String message,
  bool biometricSupported = false,
  String localizedReason = 'Confirm with biometrics',
}) async {
  if (biometricSupported && FFAppState().biometricsEnabled) {
    final auth = await TransactionAuthorizationService().authorizeTransaction(
      localizedReason: localizedReason,
    );
    if (auth.biometricUsed) {
      return PaymentConfirmation.biometric(auth.deviceFingerprint);
    }
    if (!context.mounted) return null;
  }
  final pin = await _askPin(
    context,
    title: title,
    message: message,
    explainPin: biometricSupported && FFAppState().biometricsEnabled,
  );
  if (pin == null) return null;
  return PaymentConfirmation.pin(pin);
}

/// Asks for the account PIN once, then registers this device for payment biometrics.
Future<bool> turnOnPaymentBiometrics(BuildContext context) async {
  final confirmed = await confirmPayment(
    context,
    title: 'Turn on biometrics',
    message: 'Enter your PIN once. After this, payments can use biometrics.',
    biometricSupported: false,
  );
  final pin = confirmed?.pin;
  if (pin == null || !context.mounted) return false;
  try {
    return await BiometricLockService().enableBiometrics(pin: pin);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(e))),
      );
    }
    return false;
  }
}

Future<String?> _askPin(
  BuildContext context, {
  required String title,
  required String message,
  required bool explainPin,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (explainPin) ...[
            const SizedBox(height: 8),
            const Text('Biometrics did not confirm. Enter your PIN.'),
          ] else if (!explainPin && FFAppState().biometricsEnabled) ...[
            const SizedBox(height: 8),
            const Text('This action still needs your PIN.'),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Transaction PIN'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final pin = ctrl.text.trim();
            if (pin.length >= 4 && pin.length <= 6) Navigator.pop(ctx, pin);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
