import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class TransactionReceiptService {
  static const MethodChannel _channel =
      MethodChannel('farm.transaction_receipt');

  static Future<void> showDetails(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TransactionDetailsSheet(
        transaction: transaction,
      ),
    );
  }

  static String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  static String _title(Map<String, dynamic> transaction) =>
      _displayValue(transaction['description'] ??
          transaction['transaction_type'] ??
          transaction['type'] ??
          'Transaction');

  static List<MapEntry<String, String>> _details(
      Map<String, dynamic> transaction) {
    const hiddenKeys = {
      'password',
      'pin',
      'access_token',
      'refresh_token',
      'accessToken',
      'refreshToken',
    };
    return transaction.entries
        .where((entry) => !hiddenKeys.contains(entry.key))
        .map((entry) => MapEntry(entry.key.replaceAll('_', ' '),
            _displayValue(entry.value)))
        .where((entry) => entry.value.isNotEmpty)
        .toList();
  }

  static Future<void> share(Map<String, dynamic> transaction) async {
    final lines = <String>[
      'FARM transaction receipt',
      'Type: ${_displayValue(transaction['transaction_type'] ?? transaction['type'] ?? 'Transaction')}',
      'Amount: ${_displayValue(transaction['amount'] ?? transaction['value'] ?? 'N/A')} FARM',
      'Status: ${_displayValue(transaction['status'] ?? transaction['state'] ?? 'N/A')}',
      ..._details(transaction).map((entry) => '${entry.key}: ${entry.value}'),
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  static Future<void> downloadReceipt(Map<String, dynamic> transaction) async {
    if (kIsWeb) {
      throw UnsupportedError('Receipt downloads are not supported on web');
    }
    final bytes = await _renderReceipt(transaction);
    await _channel.invokeMethod<void>('saveReceipt', <String, dynamic>{
      'bytes': bytes,
      'fileName': 'farm_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
    });
  }

  static Future<Uint8List> _renderReceipt(
      Map<String, dynamic> transaction) async {
    const width = 900.0;
    final details = _details(transaction);
    final height = 220.0 + details.length * 46.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final background = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), background);

    void drawText(String text, double x, double y,
        {double size = 28, FontWeight weight = FontWeight.normal,
        Color color = Colors.black87}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: width - x - 40);
      painter.paint(canvas, Offset(x, y));
    }

    drawText('FARM TRANSACTION RECEIPT', 40, 36,
        size: 34, weight: FontWeight.bold, color: Colors.black);
    drawText(_title(transaction), 40, 92, size: 26, weight: FontWeight.w600);
    drawText(
      'Amount: ${_displayValue(transaction['amount'] ?? transaction['value'] ?? 'N/A')} FARM',
      40,
      138,
      size: 30,
      weight: FontWeight.bold,
      color: Colors.green.shade800,
    );

    var y = 210.0;
    for (final entry in details) {
      drawText('${entry.key}:', 40, y, size: 22, weight: FontWeight.w600);
      drawText(entry.value, 280, y, size: 22);
      y += 46;
    }

    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static String formatKey(String key) =>
      key.replaceAll('_', ' ').replaceFirstMapped(
            RegExp(r'^[a-z]'),
            (match) => match.group(0)!.toUpperCase(),
          );

  static String formatValue(dynamic value) => _displayValue(value);
}

class _TransactionDetailsSheet extends StatelessWidget {
  const _TransactionDetailsSheet({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = TransactionReceiptService._details(transaction);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TransactionReceiptService._title(transaction),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: details
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            TransactionReceiptService.formatKey(entry.key),
                            style: theme.textTheme.labelMedium,
                          ),
                          subtitle: Text(
                            TransactionReceiptService.formatValue(entry.value),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download receipt'),
                    onPressed: () async {
                      try {
                        await TransactionReceiptService.downloadReceipt(
                            transaction);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Receipt saved to gallery')),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not save receipt: $error')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                    onPressed: () => TransactionReceiptService.share(transaction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
