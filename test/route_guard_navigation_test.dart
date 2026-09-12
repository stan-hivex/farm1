import 'package:farm/services/auth/route_guard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exact public paths are public routes', () {
    final guard = RouteGuardService();

    expect(guard.isPublicRoute('/'), isTrue);
    expect(guard.isPublicRoute('/login'), isTrue);
    expect(guard.isPublicRoute('/sendReceive'), isFalse);
    expect(guard.isPublicRoute('/qRScanner'), isFalse);
    expect(guard.isPublicRoute('/allTransactions'), isFalse);
  });
}
