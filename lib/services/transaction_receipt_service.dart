import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/transaction_peer_resolver.dart';

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

  static String transactionId(Map<String, dynamic> transaction) =>
      _displayValue(transaction['transaction_id'] ??
          transaction['transactionId'] ??
          transaction['transaction_reference'] ??
          transaction['reference'] ??
          transaction['id']);

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _partyName(Map<String, dynamic> transaction,
      {required bool sender}) {
    final keys = sender
        ? ['sender_name', 'sender_username', 'sender']
        : ['receiver_name', 'recipient_name', 'recipient_username', 'receiver_username', 'recipient'];
    for (final key in keys) {
      final value = _text(transaction[key]);
      if (value.isNotEmpty) return value.startsWith('@') ? value : '@$value';
    }
    final resolved = resolveTransactionPeer(transaction, outgoing: !sender);
    if (resolved.isEmpty || resolved == 'unknown user') return 'Unknown';
    return resolved.startsWith('@') ? resolved : '@$resolved';
  }

  static String _dateTime(Map<String, dynamic> transaction) {
    final raw = transaction['created_at'] ?? transaction['createdAt'] ??
        transaction['processed_at'] ?? transaction['timestamp'] ?? transaction['date'];
    final parsed = DateTime.tryParse(_text(raw));
    return parsed == null ? _text(raw) : dateTimeFormatEastAfricanTime('MMM d, yyyy • h:mm a EAT', parsed);
  }

  static List<MapEntry<String, String>> _details(
      Map<String, dynamic> transaction) {
    final amount = transaction['amount'] ?? transaction['value'] ?? 'N/A';
    final type = transaction['transaction_type'] ?? transaction['type'] ?? 'N/A';
    final typeText = _text(type).toLowerCase();
    final isOutgoing = transaction['is_outgoing'] == true ||
        typeText.contains('withdraw') || typeText.contains('send');
    return [
      MapEntry('Amount', '${_displayValue(amount)} FARM'),
      MapEntry('Status', _displayValue(transaction['status'] ?? transaction['state'] ?? 'N/A')),
      MapEntry('Fee charged', '${_displayValue(transaction['fee'] ?? 0)} FARM'),
      MapEntry('Net amount', '${_displayValue(transaction['net_amount'] ?? transaction['netAmount'] ?? amount)} FARM'),
      MapEntry('Currency', _displayValue(transaction['currency'] ?? 'FARM')),
      MapEntry('Description', _displayValue(transaction['description'] ?? '')),
      MapEntry('Transaction type', _displayValue(type)),
      MapEntry('Date and time', _dateTime(transaction)),
      MapEntry('Is outgoing', isOutgoing ? 'Yes' : 'No'),
      MapEntry('Sender', _partyName(transaction, sender: true)),
      MapEntry('Receiver', _partyName(transaction, sender: false)),
    ].where((entry) => entry.value.isNotEmpty).toList();
  }

  static Future<void> share(Map<String, dynamic> transaction) async {
    await shareReceipts([transaction]);
  }

  static Future<void> shareReceipts(
      List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return;
    final lines = <String>[
      'FARM transaction receipts',
    ];
    for (final transaction in transactions) {
      lines
        ..add('')
        ..add('Transaction ID: ${transactionId(transaction)}')
        ..addAll(_details(transaction).map((entry) => '${entry.key}: ${entry.value}'));
    }
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  static Future<void> downloadReceipt(Map<String, dynamic> transaction) async {
    await downloadReceipts([transaction]);
  }

  static Future<void> downloadReceipts(
      List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return;
    if (kIsWeb) {
      throw UnsupportedError('Receipt downloads are not supported on web');
    }
    final bytes = await _renderReceipts(transactions);
    await _channel.invokeMethod<void>('saveReceipt', <String, dynamic>{
      'bytes': bytes,
      'fileName': 'farm_receipts_${DateTime.now().millisecondsSinceEpoch}.png',
    });
  }

  static Future<Uint8List> _renderReceipts(
      List<Map<String, dynamic>> transactions) async {
    const width = 900.0;
    final sections = transactions
        .map((transaction) => <String, dynamic>{
              'title': _title(transaction),
              'details': _details(transaction),
              'amount': _displayValue(
                  transaction['amount'] ?? transaction['value'] ?? 'N/A'),
            })
        .toList();
    final height = 80.0 +
        sections.fold<double>(0, (total, section) {
          final details = section['details'] as List<MapEntry<String, String>>;
          return total + 150.0 + details.length * 46.0;
        });
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final background = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), background);

    void drawText(String text, double x, double y,
        {double size = 28,
        FontWeight weight = FontWeight.normal,
        Color color = Colors.black87}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      )..layout(maxWidth: width - x - 40);
      painter.paint(canvas, Offset(x, y));
    }

    drawText('FARM TRANSACTION RECEIPTS', 40, 36,
        size: 34, weight: FontWeight.bold, color: Colors.black);
    var y = 100.0;
    for (final section in sections) {
      final details = section['details'] as List<MapEntry<String, String>>;
      drawText(section['title'] as String, 40, y,
          size: 26, weight: FontWeight.w600);
      drawText('Amount: ${section['amount']} FARM', 40, y + 46,
          size: 30, weight: FontWeight.bold, color: Colors.green.shade800);
      y += 118;
      for (final entry in details) {
        drawText('${entry.key}:', 40, y, size: 22, weight: FontWeight.w600);
        drawText(entry.value, 280, y, size: 22);
        y += 46;
      }
      y += 32;
    }

    final image =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static String formatKey(String key) => key;

  static String formatValue(dynamic value) => _displayValue(value);
}

class _TransactionDetailsSheet extends StatelessWidget {
  const _TransactionDetailsSheet({required this.transaction});

  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = TransactionReceiptService._details(transaction);
    final id = TransactionReceiptService.transactionId(transaction);
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
            if (id.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaction ID: $id',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy transaction ID',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction ID copied'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
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
                            SnackBar(
                                content:
                                    Text('Could not save receipt: $error')),
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
                    onPressed: () =>
                        TransactionReceiptService.share(transaction),
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
