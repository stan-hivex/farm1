import 'package:farm/services/biometric_api_service.dart';
import 'package:farm/services/payment_confirm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('turning biometrics on sends the account PIN', () {
    final body = BiometricApiService.enableBiometricsBody(
      deviceFingerprint: 'device-1',
      pin: '1234',
      biometricType: 'fingerprint',
    );
    expect(body['pin'], '1234');
    expect(body['deviceFingerprint'], 'device-1');
    expect(body.containsKey('biometric_auth'), isFalse);
  });

  test('biometric confirmation does not invent a PIN', () {
    final bio = PaymentConfirmation.biometric('fp');
    expect(bio.authFields(), {
      'biometric_auth': true,
      'device_fingerprint': 'fp',
    });
    final pin = PaymentConfirmation.pin('1234');
    expect(pin.biometric, isFalse);
    expect(pin.authFields(), {'pin': '1234'});
  });
}
