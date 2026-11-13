import 'package:farm/backend/api_requests/business_ops_api.dart';
import 'package:farm/backend/api_requests/payment_request_api_service.dart';
import 'package:farm/core/crypto_coin_limit.dart';
import 'package:farm/pages/business/ops/invoice_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business lists accept wrapped item arrays', () {
    expect(
      BusinessOpsApi.list({
        'data': {
          'escrows': [
            {'id': 'e1', 'title': 'Fence'},
          ],
        },
      }).single['id'],
      'e1',
    );
    expect(
      BusinessOpsApi.list({
        'data': {
          'items': [
            {'id': 'i1'},
          ],
        },
      }).single['id'],
      'i1',
    );
  });

  test('batch approval names the requests that failed', () {
    final text = PaymentRequestApiService.batchResultMessage({
      'message': 'done',
      'data': {
        'results': [
          {'request_id': 'a', 'success': true},
          {'request_id': 'b', 'success': false, 'error': 'insufficient funds'},
        ],
      },
    });
    expect(text, contains('Approved 1'));
    expect(text, contains('b: insufficient funds'));
  });

  test('a zero crypto minimum is not shown as USD 0.00', () {
    expect(parseCoinLimit({'currency': 'usdc', 'minimumUsd': 0, 'maximumUsd': 0}), isNull);
  });

  test('invoice share file is a PDF', () {
    final bytes = invoicePdfBytes({
      'invoice_number': 'INV-1',
      'status': 'sent',
      'total': 12.5,
      'customer': {'name': 'Asha'},
      'items': [
        {'description': 'Seed', 'quantity': 2, 'amount': 12.5},
      ],
    });
    expect(String.fromCharCodes(bytes.take(8)), '%PDF-1.4');
  });
}
