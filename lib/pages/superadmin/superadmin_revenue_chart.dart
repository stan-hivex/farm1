import 'package:flutter/material.dart';

class SuperadminRevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> series;
  final double maximum;
  final Color accent;
  final Color muted;

  const SuperadminRevenueChart({
    super.key,
    required this.series,
    required this.maximum,
    required this.accent,
    required this.muted,
  });

  String _formatValue(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)}K'
      : value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
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
                Text(
                  _formatValue(chartMaximum),
                  style: TextStyle(color: muted, fontSize: 10),
                ),
                Text(
                  _formatValue(chartMaximum / 2),
                  style: TextStyle(color: muted, fontSize: 10),
                ),
                Text('0', style: TextStyle(color: muted, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _SuperadminRevenueChartPainter(
                      values: series
                          .map((item) =>
                              double.tryParse(item['value'].toString()) ?? 0)
                          .toList(),
                      maximum: chartMaximum,
                      accent: accent,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: series
                      .map(
                        (item) => Expanded(
                          child: Text(
                            item['label']?.toString() ?? '',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(color: muted, fontSize: 9),
                          ),
                        ),
                      )
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

class _SuperadminRevenueChartPainter extends CustomPainter {
  final List<double> values;
  final double maximum;
  final Color accent;

  _SuperadminRevenueChartPainter({
    required this.values,
    required this.maximum,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = size.height * index / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = values.asMap().entries.map((entry) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * entry.key / (values.length - 1);
      final y = size.height - (entry.value / maximum * size.height);
      return Offset(x, y.clamp(0, size.height).toDouble());
    }).toList();
    if (points.isEmpty) return;

    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = accent.withValues(alpha: 0.08),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final pointPaint = Paint()..color = accent;
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuperadminRevenueChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maximum != maximum ||
      oldDelegate.accent != accent;
}
