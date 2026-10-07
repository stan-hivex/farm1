import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/services/api_service.dart';
import '/utils/transaction_peer_resolver.dart';

class TransactionReceiptService {
  static const MethodChannel _channel =
      MethodChannel('farm.transaction_receipt');

  static Future<void> showDetails(
    BuildContext context,
    Map<String, dynamic> transaction, {
    bool fetchLatest = false,
  }) async {
    var detailsTransaction = Map<String, dynamic>.from(transaction);
    var detailsLoadError = false;
    final transactionDbId = _text(transaction['id']);
    if (fetchLatest && transactionDbId.isNotEmpty) {
      try {
        final response =
            await ApiService.getTransactionDetails(transactionDbId);
        final remote = response['data'];
        if (remote is Map) {
          detailsTransaction.addAll(
            Map<String, dynamic>.from(remote)
              ..removeWhere((_, value) => value == null),
          );
        } else {
          detailsLoadError = true;
        }
      } catch (error) {
        debugPrint('Could not fetch full transaction details: $error');
        detailsLoadError = true;
      }
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TransactionDetailsSheet(
        transaction: detailsTransaction,
        detailsLoadError: detailsLoadError,
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

  static dynamic _firstValue(
    Map<String, dynamic> transaction,
    List<String> keys, {
    Map<String, dynamic>? metadata,
  }) {
    for (final key in keys) {
      final value = transaction[key] ?? metadata?[key];
      final normalized = value?.toString().trim().toLowerCase();
      if (value != null &&
          normalized != null &&
          normalized.isNotEmpty &&
          !const {'n/a', 'na', 'null', 'undefined'}.contains(normalized)) {
        return value;
      }
    }
    return null;
  }

  static String _partyName(Map<String, dynamic> transaction,
      {required bool sender}) {
    final keys = sender
        ? ['sender_name', 'sender_username', 'sender']
        : [
            'receiver_name',
            'recipient_name',
            'recipient_username',
            'receiver_username',
            'recipient'
          ];
    for (final key in keys) {
      final value = _text(transaction[key]);
      if (value.isNotEmpty) return value.startsWith('@') ? value : '@$value';
    }
    final resolved = resolveTransactionPeer(transaction, outgoing: !sender);
    if (resolved.isEmpty || resolved == 'unknown user') return '';
    return resolved.startsWith('@') ? resolved : '@$resolved';
  }

  static String _dateTime(Map<String, dynamic> transaction) {
    final raw = transaction['created_at'] ??
        transaction['createdAt'] ??
        transaction['processed_at'] ??
        transaction['timestamp'] ??
        transaction['date'];
    final parsed = DateTime.tryParse(_text(raw));
    return parsed == null
        ? _text(raw)
        : dateTimeFormatEastAfricanTime('MMM d, yyyy • h:mm a EAT', parsed);
  }

  static List<MapEntry<String, String>> _details(
      Map<String, dynamic> transaction) {
    final nestedData = transaction['data'] is Map
        ? Map<String, dynamic>.from(transaction['data'] as Map)
        : <String, dynamic>{};
    final data = {...nestedData, ...transaction};
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};
    final amount = _firstValue(
          data,
          [
            'amount',
            'amount_farm',
            'amountFarm',
            'transaction_amount',
            'transactionAmount',
            'value',
          ],
          metadata: metadata,
        ) ??
        'Unavailable';
    final currency = _firstValue(
          data,
          ['currency', 'currency_code', 'currencyCode'],
          metadata: metadata,
        ) ??
        'FARM';
    final type = _firstValue(
          data,
          ['transaction_type', 'transactionType', 'type'],
        ) ??
        'Transaction';
    final typeText = _text(type).toLowerCase();
    final fee = _firstValue(
          data,
          ['fee', 'fee_amount', 'feeAmount', 'transaction_fee'],
          metadata: metadata,
        ) ??
        0;
    final netAmount = _firstValue(
          data,
          ['net_amount', 'netAmount', 'settlement'],
          metadata: metadata,
        ) ??
        _subtractAmounts(amount, fee);
    final status = _firstValue(
          data,
          ['status', 'state', 'transaction_status', 'transactionStatus'],
          metadata: metadata,
        ) ??
        'Unknown';
    final isOutgoing = data['is_outgoing'] == true ||
        typeText.contains('withdraw') ||
        typeText.contains('send');
    final fiatAmount = _firstValue(
      data,
      ['fiat_amount', 'amount_fiat', 'amount_usd'],
      metadata: metadata,
    );
    final fiatCurrency = _firstValue(
          data,
          ['fiat_currency', 'currency_fiat'],
          metadata: metadata,
        ) ??
        (metadata['amount_usd'] != null ? 'USD' : '');
    return [
      MapEntry('Amount', '${_displayValue(amount)} $currency'),
      MapEntry('Status', _displayValue(status)),
      MapEntry('Fee charged', '${_displayValue(fee)} $currency'),
      MapEntry('Net amount', '${_displayValue(netAmount)} $currency'),
      MapEntry('Currency', _displayValue(currency)),
      if (fiatAmount != null)
        MapEntry(
            'Fiat amount', '$fiatCurrency ${_displayValue(fiatAmount)}'.trim()),
      if (_firstValue(data, ['payment_method', 'paymentMethod', 'method'],
              metadata: metadata) !=
          null)
        MapEntry(
          'Payment method',
          _displayValue(
            _firstValue(data, ['payment_method', 'paymentMethod', 'method'],
                metadata: metadata),
          ),
        ),
      if (_firstValue(data, ['payment_provider', 'provider'],
              metadata: metadata) !=
          null)
        MapEntry(
          'Payment provider',
          _displayValue(_firstValue(data, ['payment_provider', 'provider'],
              metadata: metadata)),
        ),
      if (_firstValue(data, ['provider_reference', 'providerReference'],
              metadata: metadata) !=
          null)
        MapEntry(
          'Provider reference',
          _displayValue(_firstValue(
              data, ['provider_reference', 'providerReference'],
              metadata: metadata)),
        ),
      if (_firstValue(
              data, ['provider_transaction_id', 'providerTransactionId'],
              metadata: metadata) !=
          null)
        MapEntry(
          'Provider transaction ID',
          _displayValue(_firstValue(
              data, ['provider_transaction_id', 'providerTransactionId'],
              metadata: metadata)),
        ),
      if (_firstValue(data, ['blockchain_tx_hash', 'blockchainTransactionHash'],
              metadata: metadata) !=
          null)
        MapEntry(
          'Blockchain transaction',
          _displayValue(_firstValue(
              data, ['blockchain_tx_hash', 'blockchainTransactionHash'],
              metadata: metadata)),
        ),
      if (data['deposit_status'] != null)
        MapEntry('Deposit status', _displayValue(data['deposit_status'])),
      if (data['deposit_verified_at'] != null)
        MapEntry('Provider verified at',
            _dateTime({'created_at': data['deposit_verified_at']})),
      if (data['deposit_credited_at'] != null)
        MapEntry('Wallet credited at',
            _dateTime({'created_at': data['deposit_credited_at']})),
      if (data['withdrawal_method'] != null ||
          data['withdrawal_network'] != null)
        MapEntry(
          'Withdrawal route',
          [
            data['withdrawal_method'],
            data['crypto_asset'],
            data['withdrawal_network'],
          ]
              .where((value) => value != null && value.toString().isNotEmpty)
              .join(' • '),
        ),
      if (data['settlement_amount'] != null)
        MapEntry(
          'Withdrawal settlement',
          '${_displayValue(data['settlement_amount'])} $currency',
        ),
      if (data['failure_reason'] != null &&
          data['failure_reason'].toString().trim().isNotEmpty)
        MapEntry('Failure reason', _displayValue(data['failure_reason'])),
      MapEntry(
          'Description',
          _displayValue(
              data['original_description'] ?? data['description'] ?? '')),
      MapEntry('Transaction type', _displayValue(type)),
      MapEntry('Date and time', _dateTime(data)),
      MapEntry('Is outgoing', isOutgoing ? 'Yes' : 'No'),
      if (_partyName(data, sender: true).isNotEmpty)
        MapEntry('Sender', _partyName(data, sender: true)),
      if (_partyName(data, sender: false).isNotEmpty)
        MapEntry('Receiver', _partyName(data, sender: false)),
    ].where((entry) => entry.value.isNotEmpty).toList();
  }

  static dynamic _subtractAmounts(dynamic amount, dynamic fee) {
    final parsedAmount = num.tryParse(amount.toString());
    final parsedFee = num.tryParse(fee.toString());
    if (parsedAmount == null || parsedFee == null) return amount;
    return parsedAmount - parsedFee;
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
        ..addAll(_details(transaction)
            .map((entry) => '${entry.key}: ${entry.value}'));
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
    final sections = transactions.map((transaction) {
      final metadata = transaction['metadata'] is Map
          ? Map<String, dynamic>.from(transaction['metadata'] as Map)
          : <String, dynamic>{};
      return <String, dynamic>{
        'title': _title(transaction),
        'details': _details(transaction),
        'amount': _displayValue(_firstValue(
              transaction,
              [
                'amount',
                'amount_farm',
                'amountFarm',
                'transaction_amount',
                'transactionAmount',
                'value',
              ],
              metadata: metadata,
            ) ??
            'Unavailable'),
        'currency': _displayValue(
            transaction['currency'] ?? transaction['currency_code'] ?? 'FARM'),
      };
    }).toList();
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
      drawText(
          'Amount: ${section['amount']} ${section['currency']}', 40, y + 46,
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
  const _TransactionDetailsSheet({
    required this.transaction,
    required this.detailsLoadError,
  });

  final Map<String, dynamic> transaction;
  final bool detailsLoadError;

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
            if (detailsLoadError)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Could not fetch the latest transaction details. Showing the information currently available.',
                  style: TextStyle(color: Colors.orange),
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
