import 'transaction_history_utils.dart';

/// Incoming merchant QR settlements belong on the merchant portal, not in the
/// personal activity list. Outgoing payments the user made stay personal.
bool isBusinessQrSettlement(Map<dynamic, dynamic> tx) {
  if (tx['counts_toward_personal'] == true) return false;
  if (tx['is_outgoing'] == true) return false;
  final direction = (tx['direction'] ?? '').toString().toLowerCase();
  if (direction == 'out' || direction == 'debit' || direction == 'outgoing') {
    return false;
  }
  final type = (tx['transaction_type'] ?? tx['type'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final source = (tx['source'] ?? '').toString().toLowerCase();
  const qrTypes = {
    'merchant_payment',
    'qr_payment',
    'public_qr',
    'qr',
  };
  if (qrTypes.contains(type) || source == 'qr' || source == 'merchant_qr') {
    return true;
  }
  final description = (tx['description'] ?? '').toString().toLowerCase();
  return description.contains('public qr');
}

/// Personal home and history. Merchant sales keep using the unfiltered feed.
bool isPersonalActivity(Object? value) {
  if (!isVisibleTransactionHistoryItem(value)) return false;
  if (value is Map && isBusinessQrSettlement(value)) return false;
  return true;
}
