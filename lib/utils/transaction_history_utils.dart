bool isVisibleTransactionHistoryItem(Object? value) {
  if (value is! Map) return false;

  final status = (value['status'] ?? value['state'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  const hiddenStatuses = {
    'pending',
    'processing',
    'failed',
    'cancelled',
    'canceled',
    'reversed',
  };
  return !hiddenStatuses.contains(status);
}
