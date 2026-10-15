import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RevenueOverviewChart extends StatelessWidget {
  const RevenueOverviewChart({
    required this.series,
    required this.cardColor,
    required this.accent,
    super.key,
  });

  final List<Map<String, dynamic>> series;
  final Color cardColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final values = series
        .map((item) => double.tryParse(item['value'].toString()) ?? 0)
        .toList();
    final maximum =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final previousTotal = values.length > 3
        ? values.sublist(0, values.length - 3).fold<double>(0, (a, b) => a + b)
        : 0.0;
    final recentTotal = values.length > 3
        ? values.sublist(values.length - 3).fold<double>(0, (a, b) => a + b)
        : values.fold<double>(0, (a, b) => a + b);
    final change = previousTotal == 0
        ? (recentTotal > 0 ? 100.0 : 0.0)
        : ((recentTotal - previousTotal) / previousTotal) * 100;
    const textColor = Colors.white;
    const mutedColor = Colors.white60;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Revenue Overview',
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completed platform fees, last 7 days',
                      style: GoogleFonts.plusJakartaSans(
                        color: mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RevenueChart(
            series: series,
            maximum: maximum,
            accent: accent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({
    required this.series,
    required this.maximum,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  final List<Map<String, dynamic>> series;
  final double maximum;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  String _formatValue(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Text(
            'No completed fee revenue in this period',
            style: GoogleFonts.plusJakartaSans(color: mutedColor),
          ),
        ),
      );
    }

    final chartMaximum = maximum <= 0 ? 1.0 : maximum * 1.2;
    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatValue(chartMaximum),
                    style: TextStyle(color: mutedColor, fontSize: 10)),
                Text(_formatValue(chartMaximum / 2),
                    style: TextStyle(color: mutedColor, fontSize: 10)),
                Text('0', style: TextStyle(color: mutedColor, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _RevenueChartPainter(
                      values: series
                          .map((item) =>
                              double.tryParse(item['value'].toString()) ?? 0)
                          .toList(),
                      maximum: chartMaximum,
                      accent: accent,
                      gridColor: textColor.withValues(alpha: 0.1),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: series
                      .map((item) => Text(
                            item['label']?.toString() ?? '',
                            style: TextStyle(color: mutedColor, fontSize: 10),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueChartPainter extends CustomPainter {
  const _RevenueChartPainter({
    required this.values,
    required this.maximum,
    required this.accent,
    required this.gridColor,
  });

  final List<double> values;
  final double maximum;
  final Color accent;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = size.height * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = values.asMap().entries.map((entry) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * entry.key / (values.length - 1);
      final y = size.height - (entry.value / maximum * size.height);
      return Offset(x, y.clamp(0, size.height).toDouble());
    }).toList();

    for (var index = 0; index < points.length; index++) {
      if (index == 0) {
        path.moveTo(points[index].dx, points[index].dy);
      } else {
        path.lineTo(points[index].dx, points[index].dy);
      }
    }

    canvas.drawPath(path, linePaint);
    final pointPaint = Paint()..color = accent;
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maximum != maximum ||
      oldDelegate.accent != accent ||
      oldDelegate.gridColor != gridColor;
}
