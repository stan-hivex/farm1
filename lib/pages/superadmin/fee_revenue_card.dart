import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/admin/widgets/admin_ui.dart';
import 'fee_revenue.dart';

/// Every collected fee, including zeros, with a period selector.
class FeeRevenueCard extends StatelessWidget {
  const FeeRevenueCard({
    super.key,
    required this.report,
    required this.period,
    required this.onPeriod,
    required this.cardColor,
    required this.accent,
    required this.muted,
  });

  final FeeRevenueReport report;
  final String period;
  final ValueChanged<String> onPeriod;
  final Color cardColor;
  final Color accent;
  final Color muted;

  static const _colors = <Color>[
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFFC084FC),
    Color(0xFFFB923C),
    Color(0xFF2DD4BF),
    Color(0xFFF472B6),
    Color(0xFFFACC15),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = report.hasPeriods && feePeriodLabels.containsKey(period)
        ? period
        : 'all';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Revenue',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fees collected',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              if (report.hasPeriods) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in feePeriodKeys) _periodChip(key, selected),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Today starts at 00:00 UTC. 7 days and 30 days count back from now.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (report.fees.isEmpty)
                Text(
                  'No fee totals were returned.',
                  style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 13,
                  ),
                )
              else
                for (var i = 0; i < report.fees.length; i++) ...[
                  _feeRow(
                    report.fees[i],
                    selected,
                    _colors[i % _colors.length],
                  ),
                  const SizedBox(height: 12),
                ],
              if (report.fees.isNotEmpty)
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total (${report.fees.length} types)',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${formatFarmAmount(report.totalFor(selected))} FARM',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodChip(String key, String selected) {
    final on = key == selected;
    return GestureDetector(
      onTap: () => onPeriod(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? accent : Colors.white24),
        ),
        child: Text(
          feePeriodLabels[key] ?? key,
          style: GoogleFonts.plusJakartaSans(
            color: on ? accent : muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _feeRow(CollectedFee fee, String period, Color color) {
    final count = fee.countFor(period);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fee.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatFarmAmount(fee.amountFor(period))} FARM',
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            count == 1 ? 'From 1 transaction' : 'From $count transactions',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          if (fee.note != null) ...[
            const SizedBox(height: 4),
            Text(
              fee.note!,
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
