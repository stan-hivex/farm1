import 'package:farm/pages/superadmin/fee_revenue.dart';
import 'package:farm/pages/superadmin/fee_revenue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard fees include zeros, notes, and period buckets', () {
    final report = parseFeeRevenue({
      'fees': [
        {
          'type': 'travel',
          'label': 'Travel commission',
          'source': 'transactions.fee on escrow holds',
          'total': 4,
          'count': 1,
          'periods': {
            'day': {'total': 4, 'count': 1},
            'week': {'total': 4, 'count': 1},
            'month': {'total': 4, 'count': 1},
            'all': {'total': 4, 'count': 1},
          },
        },
        {
          'type': 'x402',
          'label': 'x402 platform fees',
          'source': 'none',
          'note': 'x402 does not charge a platform fee. Sponsored network fees are a cost.',
          'total': 0,
          'count': 0,
          'periods': {
            'day': {'total': 0, 'count': 0},
            'week': {'total': 0, 'count': 0},
            'month': {'total': 0, 'count': 0},
            'all': {'total': 0, 'count': 0},
          },
        },
        {
          'type': 'project_consolidation',
          'label': 'Project consolidation fund',
          'total': 15,
          'count': 1,
          'periods': {
            'all': {'total': 15, 'count': 1},
            'day': {'total': 0, 'count': 0},
            'week': {'total': 15, 'count': 1},
            'month': {'total': 15, 'count': 1},
          },
        },
      ],
      'escrow_creation_earnings': 99,
      'revenue_streams': [
        {'type': 'transfer', 'label': 'ignored', 'total': 1, 'count': 1},
      ],
    });

    expect(report.fromList, isTrue);
    expect(report.fees.map((fee) => fee.type), [
      'travel',
      'x402',
      'project_consolidation',
    ]);
    expect(report.fees[1].note, contains('does not charge'));
    expect(report.fees[1].amountFor('all'), 0);
    expect(report.totalFor('day'), 4);
    expect(report.totalFor('week'), 19);
    expect(report.totalFor('all'), 19);
    expect(report.hasPeriods, isTrue);
  });

  test('revenue_streams is used when fees is absent', () {
    final report = parseFeeRevenue({
      'revenue_streams': [
        {
          'type': 'transfer',
          'label': 'Transfer and send fees',
          'total': 1.5,
          'count': 3,
          'periods': {
            'all': {'total': 1.5, 'count': 3},
            'day': {'total': 0, 'count': 0},
            'week': {'total': 1.5, 'count': 3},
            'month': {'total': 1.5, 'count': 3},
          },
        },
      ],
    });
    expect(report.fees.single.label, 'Transfer and send fees');
    expect(report.fees.single.amountFor('week'), 1.5);
  });

  test('legacy earnings and wallet revenue fields still display', () {
    final dashboard = parseFeeRevenue({
      'escrow_creation_earnings': 1.5,
      'escrow_creation_count': 2,
      'escrow_release_earnings': 1.5,
      'withdraw_fee_earnings': 3,
      'withdraw_transaction_count': 4,
      'merchant_sales_fee_earnings': 2,
      'merchant_sales_count': 5,
    });
    expect(dashboard.fromList, isFalse);
    expect(dashboard.fees.map((fee) => fee.label), [
      'Escrow creation fees',
      'Escrow release fees',
      'Withdrawal fees',
      'Merchant sales fees',
    ]);
    expect(dashboard.totalFor('all'), 8);
    expect(dashboard.fees.first.count, 2);
    expect(dashboard.hasPeriods, isFalse);

    final wallet = parseFeeRevenue({
      'escrow_creation_revenue': 1,
      'escrow_release_revenue': 2,
      'withdrawal_revenue': 3,
      'merchant_sales_revenue': 4,
      'merchant_sales_count': 6,
    });
    expect(wallet.fees.map((fee) => fee.total), [1, 2, 3, 4]);
    expect(wallet.fees.last.count, 6);
  });

  test('wallet fees win over the legacy revenue fields', () {
    final report = feeReportFor(
      {'escrow_creation_earnings': 50},
      {
        'fees': [
          {
            'type': 'investment',
            'label': 'Investment fees',
            'total': 3,
            'count': 1,
            'periods': {
              'all': {'total': 3, 'count': 1},
              'day': {'total': 3, 'count': 1},
              'week': {'total': 3, 'count': 1},
              'month': {'total': 3, 'count': 1},
            },
          },
        ],
        'withdrawal_revenue': 9,
      },
    );
    expect(report.fees.single.type, 'investment');
    expect(report.totalFor('day'), 3);
  });

  testWidgets('the revenue card lists zero fees and follows the period', (
    tester,
  ) async {
    var period = 'all';
    final report = parseFeeRevenue({
      'fees': [
        {
          'type': 'travel',
          'label': 'Travel commission',
          'total': 10,
          'count': 2,
          'periods': {
            'day': {'total': 4, 'count': 1},
            'week': {'total': 4, 'count': 1},
            'month': {'total': 4, 'count': 1},
            'all': {'total': 10, 'count': 2},
          },
        },
        {
          'type': 'x402',
          'label': 'x402 platform fees',
          'note': 'x402 does not charge a platform fee.',
          'total': 0,
          'count': 0,
          'periods': {
            'day': {'total': 0, 'count': 0},
            'week': {'total': 0, 'count': 0},
            'month': {'total': 0, 'count': 0},
            'all': {'total': 0, 'count': 0},
          },
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: FeeRevenueCard(
              report: report,
              period: period,
              onPeriod: (value) => setState(() => period = value),
              cardColor: const Color(0xFF111111),
              accent: const Color(0xFFD4AF37),
              muted: Colors.white54,
            ),
          ),
        ),
      ),
    );

    expect(find.text('x402 platform fees'), findsOneWidget);
    expect(find.text('x402 does not charge a platform fee.'), findsOneWidget);
    expect(find.text('0.00 FARM'), findsOneWidget);
    expect(find.text('10.00 FARM'), findsWidgets);

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(period, 'day');
    expect(find.text('10.00 FARM'), findsNothing);
    expect(find.text('4.00 FARM'), findsWidgets);
  });
}
