import 'package:farm/pages/otppage/otppage_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone verification allows the Firebase SMS retrieval window', () {
    expect(
      OtppageWidget.phoneVerificationTimeout,
      const Duration(seconds: 120),
    );
  });
}