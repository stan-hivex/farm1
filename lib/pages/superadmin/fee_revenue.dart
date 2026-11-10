/// Collected platform fees from `GET /api/v1/superadmin/dashboard` and
/// `GET /api/v1/admin/wallet`.
///
/// The backend sends the same list on `data.fees` and `data.revenue_streams`.
/// Each item is `{type, label, source, note?, total, count, periods}`.
/// `periods.day` starts at UTC midnight, `week` is 7 days, and `month` is 30 days.
/// Each period is `{total, count}`.
///
/// Older payloads only have `escrow_creation_earnings`, `withdrawal_revenue`,
/// and `merchant_sales_revenue` (plus the release fee). Those still display.
library;

class FeeBucket {
  const FeeBucket({required this.total, required this.count});

  final double total;
  final int count;
}

class CollectedFee {
  const CollectedFee({
    required this.type,
    required this.label,
    required this.total,
    required this.count,
    this.source,
    this.note,
    this.periods = const {},
  });

  final String type;
  final String label;
  final String? source;
  final String? note;
  final double total;
  final int count;
  final Map<String, FeeBucket> periods;

  double amountFor(String period) {
    final bucket = periods[period];
    if (bucket != null) return bucket.total;
    if (period == 'all') return total;
    return 0;
  }

  int countFor(String period) {
    final bucket = periods[period];
    if (bucket != null) return bucket.count;
    if (period == 'all') return count;
    return 0;
  }
}

class FeeRevenueReport {
  const FeeRevenueReport({required this.fees, required this.fromList});

  final List<CollectedFee> fees;

  /// True when the rows came from `fees` or `revenue_streams`.
  final bool fromList;

  bool get hasPeriods => fees.any(
    (fee) =>
        fee.periods.containsKey('day') ||
        fee.periods.containsKey('week') ||
        fee.periods.containsKey('month'),
  );

  double totalFor(String period) {
    var sum = 0.0;
    for (final fee in fees) {
      sum += fee.amountFor(period);
    }
    return sum;
  }
}

const feePeriodKeys = ['all', 'day', 'week', 'month'];

const feePeriodLabels = {
  'all': 'All time',
  'day': 'Today',
  'week': '7 days',
  'month': '30 days',
};

/// Dashboard payload first, then the wallet payload, then the legacy fields.
FeeRevenueReport feeReportFor(
  Map<String, dynamic>? dashboard,
  Map<String, dynamic>? wallet,
) {
  if (dashboard != null) {
    final parsed = parseFeeRevenue(dashboard);
    if (parsed.fromList) return parsed;
  }
  if (wallet != null) {
    final parsed = parseFeeRevenue(wallet);
    if (parsed.fromList || parsed.fees.isNotEmpty) return parsed;
  }
  if (dashboard != null) return parseFeeRevenue(dashboard);
  return const FeeRevenueReport(fees: [], fromList: false);
}

FeeRevenueReport parseFeeRevenue(Map<String, dynamic> data) {
  final listed = _collectedList(data);
  if (listed != null) {
    return FeeRevenueReport(
      fromList: true,
      fees: [
        for (final item in listed)
          if (item is Map) _feeFromMap(Map<String, dynamic>.from(item)),
      ],
    );
  }
  return FeeRevenueReport(fromList: false, fees: _legacyFees(data));
}

List<dynamic>? _collectedList(Map<String, dynamic> data) {
  for (final key in ['fees', 'revenue_streams']) {
    final value = data[key];
    if (value is! List || value.isEmpty) continue;
    final collected = value.whereType<Map>().any(
      (item) =>
          item.containsKey('total') ||
          item.containsKey('periods') ||
          item.containsKey('count'),
    );
    if (collected) return value;
  }
  return null;
}

CollectedFee _feeFromMap(Map<String, dynamic> item) {
  final type = _text(item['type']).isEmpty ? 'other' : _text(item['type']);
  final total = _asDouble(item['total']);
  final count = _asInt(item['count']);
  final periods = _periods(item['periods'], total, count);
  final note = _text(item['note']);
  final source = _text(item['source']);
  return CollectedFee(
    type: type,
    label: _label(item['label'], type),
    source: source.isEmpty ? null : source,
    note: note.isEmpty ? null : note,
    total: periods['all']?.total ?? total,
    count: periods['all']?.count ?? count,
    periods: periods,
  );
}

Map<String, FeeBucket> _periods(dynamic raw, double total, int count) {
  final periods = <String, FeeBucket>{};
  if (raw is Map) {
    for (final key in feePeriodKeys) {
      if (!raw.containsKey(key)) continue;
      periods[key] = _bucket(raw[key]);
    }
  }
  periods.putIfAbsent('all', () => FeeBucket(total: total, count: count));
  return periods;
}

FeeBucket _bucket(dynamic raw) {
  if (raw is Map) {
    return FeeBucket(
      total: _asDouble(raw['total']),
      count: _asInt(raw['count']),
    );
  }
  if (raw is num) return FeeBucket(total: raw.toDouble(), count: 0);
  return const FeeBucket(total: 0, count: 0);
}

List<CollectedFee> _legacyFees(Map<String, dynamic> data) {
  const rows =
      <
        ({String type, String label, List<String> amounts, List<String> counts})
      >[
        (
          type: 'escrow_lock',
          label: 'Escrow creation fees',
          amounts: ['escrow_creation_earnings', 'escrow_creation_revenue'],
          counts: ['escrow_creation_count'],
        ),
        (
          type: 'escrow_release',
          label: 'Escrow release fees',
          amounts: ['escrow_release_earnings', 'escrow_release_revenue'],
          counts: ['escrow_release_count'],
        ),
        (
          type: 'withdrawal',
          label: 'Withdrawal fees',
          amounts: [
            'withdraw_fee_earnings',
            'withdrawal_total_earnings',
            'withdrawal_revenue',
          ],
          counts: [
            'withdraw_transaction_count',
            'withdraw_count',
            'withdrawal_fee_count',
          ],
        ),
        (
          type: 'merchant_payment',
          label: 'Merchant sales fees',
          amounts: ['merchant_sales_fee_earnings', 'merchant_sales_revenue'],
          counts: ['merchant_sales_count'],
        ),
      ];

  final fees = <CollectedFee>[];
  for (final row in rows) {
    if (!row.amounts.any(data.containsKey)) continue;
    final total = _firstDouble(data, row.amounts);
    final count = _firstInt(data, row.counts);
    fees.add(
      CollectedFee(
        type: row.type,
        label: row.label,
        total: total,
        count: count,
        periods: {'all': FeeBucket(total: total, count: count)},
      ),
    );
  }
  return fees;
}

String _label(dynamic raw, String type) {
  final label = _text(raw);
  if (label.isNotEmpty) return label;
  final words = type.replaceAll('_', ' ').trim();
  if (words.isEmpty) return 'Fees';
  return '${words[0].toUpperCase()}${words.substring(1)} fees';
}

String _text(dynamic value) => value?.toString().trim() ?? '';

double _firstDouble(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data.containsKey(key)) return _asDouble(data[key]);
  }
  return 0;
}

int _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (data.containsKey(key)) return _asInt(data[key]);
  }
  return 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
