import 'package:flutter_test/flutter_test.dart';
import 'package:farm/services/transaction_receipt_service.dart';

void main() {
  group('TransactionReceiptService.transactionLookupId', () {
    test('uses the transaction database id when available', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'id': 'transaction-row-id',
          'transaction_reference': 'display-reference',
        }),
        'transaction-row-id',
      );
    });

    test('falls back to the available transaction reference', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'transaction_reference': 'transaction-reference',
        }),
        'transaction-reference',
      );
    });
  });
}
