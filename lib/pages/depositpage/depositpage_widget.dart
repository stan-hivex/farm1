import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/services/api_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Removed unused import
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/kyc_required_widget.dart';
import '/pages/depositpage/deposit_status_utils.dart';
import '/services/app_session_manager.dart';
import '/services/transaction_receipt_service.dart';

class DepositpageWidget extends StatefulWidget {
  const DepositpageWidget({super.key});

  static String routeName = 'DepositPage';
  static String routePath = '/depositpage';

  @override
  State<DepositpageWidget> createState() => _DepositpageWidgetState();
}

class _DepositpageWidgetState extends State<DepositpageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController amountController = TextEditingController();

  String selectedCurrency = 'KES';
  String selectedMethod = 'CARD';

  bool isLoading = false;
  bool loadingWallet = true;

  double walletBalance = 0;
  List<dynamic> recentDeposits = [];
  final Set<int> _selectedDeposits = <int>{};

  // Deposit fees are disabled. The amount entered by the user is the amount credited.
  final Map<String, double> _feeRates = {
    'CARD': 0.0,
    'BANK_TRANSFER': 0.0,
    'MOBILE_MONEY': 0.0,
    'CRYPTO': 0.0,
  };

  final Map<String, Map<String, double?>> _depositLimits = {
    'CARD': {'min': 10, 'max': 249000},
    'CRYPTO': {'min': 100, 'max': null},
  };

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;
  double get feeRate => _feeRates[selectedMethod] ?? 0.0;
  double get fee => 0;
  double get total => amount;

  Map<String, double?> get _activeDepositLimits =>
      _depositLimits[selectedMethod] ?? _depositLimits['CARD']!;
  double get _activeDepositMin => _activeDepositLimits['min'] ?? 10;
  double? get _activeDepositMax => _activeDepositLimits['max'];
  bool get _hasValidDepositAmount =>
      amount > 0 &&
      amount >= _activeDepositMin &&
      (_activeDepositMax == null || amount <= _activeDepositMax!);

  bool _isValidDepositAmountFor(String method) {
    final limits = _depositLimits[method] ?? _depositLimits['CARD']!;
    final min = limits['min'] ?? 10;
    final max = limits['max'];
    return amount > 0 && amount >= min && (max == null || amount <= max);
  }

  String _formatAmount(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value);
  }

  String get _depositValidationMessage {
    if (amount <= 0) {
      return 'Range: KES ${_formatAmount(_activeDepositMin)}${_activeDepositMax == null ? '+' : ' - KES ${_formatAmount(_activeDepositMax!)}'}';
    }
    if (_hasValidDepositAmount) {
      return 'Range: KES ${_formatAmount(_activeDepositMin)}${_activeDepositMax == null ? '+' : ' - KES ${_formatAmount(_activeDepositMax!)}'}';
    }
    final maxText = _activeDepositMax == null
        ? ' and above'
        : ' and KES ${_formatAmount(_activeDepositMax!)}';
    return 'Amount must be between KES ${_formatAmount(_activeDepositMin)}$maxText';
  }

  @override
  void initState() {
    super.initState();
    FFAppState().addListener(_handleAppStateChanged);
    _fetchWallet();
    _fetchHistory();
  }

  @override
  void dispose() {
    FFAppState().removeListener(_handleAppStateChanged);
    amountController.dispose();
    super.dispose();
  }

  void _handleAppStateChanged() {
    if (!mounted || walletBalance == FFAppState().walletBalance) return;
    setState(() => walletBalance = FFAppState().walletBalance);
  }

  bool get isKycApproved {
    final status = FFAppState().kycStatus.trim().toLowerCase();
    return ['verified', 'approved', 'complete', 'success'].contains(status);
  }

  // ── Fetch wallet balance ─────────────────────────────────────────────────────────────────
  Future<void> _fetchWallet() async {
    try {
      final resp = await ApiService.getWallet();
      if (!mounted) return;
      final data = resp['data'] as Map<String, dynamic>? ?? resp;
      final bal =
          (data['balance'] ?? data['available_balance'] ?? 0).toString();
      final parsedBalance = double.tryParse(bal) ?? 0;
      final kesEquivalent =
          double.tryParse((data['kes_equivalent'] ?? '').toString());
      FFAppState().batchUpdate(() {
        FFAppState().walletBalance = parsedBalance;
        if (kesEquivalent != null) {
          FFAppState().kesEquivalent = kesEquivalent;
        }
      });
      if (mounted) setState(() => walletBalance = parsedBalance);
    } catch (e) {
      debugPrint('fetchWallet error: $e');
    } finally {
      if (mounted) setState(() => loadingWallet = false);
    }
  }

  // ── Fetch deposit history ────────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    try {
      final resp = await ApiService.getDepositHistory();
      if (!mounted) return;
      final items = resp['data'] is List ? resp['data'] as List : [];
      setState(() => recentDeposits = items);
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
  }

  Map<String, dynamic> _depositReceipt(
      Map<String, dynamic> deposit, Map<String, dynamic> metadata) {
    final receipt = Map<String, dynamic>.from(deposit);
    final farmAmount =
        deposit['amount_farm'] ??
        metadata['amount_farm'] ??
        deposit['amountFarm'] ??
        deposit['amount'];
    final amountCurrency = deposit['amount_farm'] != null ||
            metadata['amount_farm'] != null ||
            deposit['amountFarm'] != null
        ? 'FARM'
        : deposit['currency'] ??
            metadata['currency_fiat'] ??
            selectedCurrency;
    final reference = deposit['reference'] ??
        deposit['transaction_reference'] ??
        metadata['reference'];
    final method = _depositMethodLabel(deposit, metadata);
    final provider = deposit['payment_provider'] ??
        deposit['provider'] ??
        metadata['provider'];

    receipt['amount'] = farmAmount;
    receipt['transaction_type'] = 'Deposit';
    receipt['description'] = deposit['description'] ??
        '$amountCurrency deposit via $method';
    receipt['currency'] = amountCurrency;
    receipt['payment_method'] = method;
    if (provider != null) receipt['payment_provider'] = provider;
    if (reference != null) receipt['transaction_reference'] = reference;
    if (deposit['amount_fiat'] != null || metadata['amount_fiat'] != null) {
      receipt['fiat_amount'] =
          metadata['amount_fiat'] ?? deposit['amount_fiat'];
      receipt['fiat_currency'] =
          metadata['currency_fiat'] ?? deposit['currency'] ?? selectedCurrency;
    }
    return receipt;
  }

  List<Map<String, dynamic>> get _selectedDepositReceipts => _selectedDeposits
          .where((index) => index >= 0 && index < recentDeposits.length)
          .map((index) {
        final deposit = Map<String, dynamic>.from(recentDeposits[index] as Map);
        final metadata = deposit['metadata'] is Map
            ? Map<String, dynamic>.from(deposit['metadata'] as Map)
            : <String, dynamic>{};
        return _depositReceipt(deposit, metadata);
      }).toList();

  Future<void> _downloadSelectedDeposits() async {
    try {
      await TransactionReceiptService.downloadReceipts(
          _selectedDepositReceipts);
      if (!mounted) return;
      setState(() => _selectedDeposits.clear());
      _snack('Selected receipts saved to gallery');
    } catch (error) {
      if (mounted) _snack('Could not save receipts: $error');
    }
  }

  Future<void> _shareSelectedDeposits() async {
    try {
      await TransactionReceiptService.shareReceipts(_selectedDepositReceipts);
      if (!mounted) return;
      setState(() => _selectedDeposits.clear());
    } catch (error) {
      if (mounted) _snack('Could not share receipts: $error');
    }
  }

  // ── Create a backend-tracked deposit and open its checkout in-app ────────
  Future<void> _createDeposit(String method) async {
    if (isLoading) return;

    setState(() => selectedMethod = method);
    if (!_hasValidDepositAmount) {
      _snack(_depositValidationMessage);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.request(
        method: 'POST',
        path: '/payments/deposit',
        body: {
          'amount_fiat': amount,
          'currency': selectedCurrency,
          'paymentMethod': method,
          if (method == 'CARD' && FFAppState().phone.isNotEmpty)
            'phone': FFAppState().phone,
        },
        requiresAuth: true,
      );

      if (!mounted) return;

      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      final paymentUrl = (data['authorization_url'] ??
              data['payment_url'] ??
              data['payment_link'] ??
              data['checkout_url'])
          ?.toString();
      final reference =
          (data['reference'] ?? data['transaction_reference'])?.toString();
      final checkoutUri = paymentUrl == null ? null : Uri.tryParse(paymentUrl);
      if (reference == null ||
          reference.isEmpty ||
          checkoutUri == null ||
          !['http', 'https'].contains(checkoutUri.scheme)) {
        throw StateError(
          'The payment service did not return a valid checkout link and reference.',
        );
      }

      final returnedFromCheckout = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (_) => _DepositCheckoutSheet(
          paymentUrl: checkoutUri.toString(),
          title: method == 'CRYPTO' ? 'IvoryPay checkout' : 'Paystack checkout',
        ),
      );

      if (!mounted) return;
      if (returnedFromCheckout != true) {
        await _refreshDepositState(reference);
        if (mounted) {
          _snack(
            'Checkout closed. If you completed payment, confirmation will appear in Recent Deposits.',
          );
        }
        return;
      }

      await _verifyDeposit(reference);
    } catch (e) {
      if (mounted) _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _verifyDeposit(String reference) async {
    const maxAttempts = 60;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;

      try {
        final history = await ApiService.getDepositHistory();
        final items =
            history['data'] is List ? history['data'] as List : <dynamic>[];
        if (mounted) setState(() => recentDeposits = items);

        Map<String, dynamic>? deposit;
        for (final item in items) {
          if (item is! Map) continue;
          final candidate = Map<String, dynamic>.from(item);
          final candidateReference =
              (candidate['reference'] ?? candidate['transaction_reference'])
                  ?.toString();
          if (candidateReference == reference) {
            deposit = candidate;
            break;
          }
        }

        if (deposit != null) {
          final status = parseDepositLifecycleStatus(deposit['status']);
          if (status == DepositLifecycleStatus.completed) {
            await AppSessionManager().syncNow(
              profileTimeoutSeconds: 5,
              walletTimeoutSeconds: 5,
              transactionsTimeoutSeconds: 5,
            );
            if (!mounted) return;
            amountController.clear();
            await _fetchHistory();
            await _fetchWallet();
            if (mounted) {
              _snack('Payment successful. Your wallet has been credited.');
            }
            return;
          }
          if (status == DepositLifecycleStatus.failed) {
            await _fetchWallet();
            if (mounted) {
              _snack(
                  'Payment failed or was cancelled. No funds were credited.');
            }
            return;
          }
        }
      } catch (error) {
        debugPrint(
            'Deposit verification attempt ${attempt + 1} failed: $error');
      }

      if (attempt + 1 < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    if (mounted) {
      _snack(
        'Payment is still awaiting confirmation. Your wallet will update after the provider confirms it.',
      );
    }
  }

  Future<void> _refreshDepositState(String reference) async {
    try {
      final history = await ApiService.getDepositHistory();
      final items =
          history['data'] is List ? history['data'] as List : <dynamic>[];
      if (mounted) setState(() => recentDeposits = items);
      for (final item in items) {
        if (item is! Map) continue;
        final candidate = Map<String, dynamic>.from(item);
        if ((candidate['reference'] ?? candidate['transaction_reference'])
                ?.toString() !=
            reference) {
          continue;
        }
        final status = parseDepositLifecycleStatus(candidate['status']);
        if (status == DepositLifecycleStatus.completed) {
          await AppSessionManager().syncNow(
            profileTimeoutSeconds: 5,
            walletTimeoutSeconds: 5,
            transactionsTimeoutSeconds: 5,
          );
          if (!mounted) return;
          amountController.clear();
          await _fetchWallet();
          _snack('Payment successful. Your wallet has been credited.');
          return;
        }
        if (status == DepositLifecycleStatus.failed) {
          await _fetchWallet();
          if (mounted) {
            _snack('Payment failed or was cancelled. No funds were credited.');
          }
          return;
        }
      }
      await _fetchWallet();
    } catch (error) {
      debugPrint('Could not refresh deposit state: $error');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _depositMethodLabel(
    Map<String, dynamic> deposit,
    Map<String, dynamic> metadata,
  ) {
    final rawMethod = metadata['method'] ??
        deposit['paymentMethod'] ??
        deposit['payment_method'] ??
        metadata['payment_method'] ??
        deposit['payment_channel'] ??
        deposit['payment_provider'] ??
        metadata['provider'] ??
        deposit['provider'];
    final method = rawMethod?.toString().toLowerCase() ?? '';

    if (method.contains('crypto') || method.contains('ivory')) {
      return 'CRYPTO';
    }
    if (method.contains('mobile')) return 'MOBILE MONEY';
    if (method.contains('bank') && method.contains('transfer')) {
      return 'BANK TRANSFER';
    }
    if (method.contains('card') || method.contains('paystack')) {
      return 'BANK CARD';
    }
    return method.isEmpty ? 'METHOD UNAVAILABLE' : method.toUpperCase();
  }

  String _depositDateLabel(Map<String, dynamic> deposit) {
    final rawDate = deposit['created_at'] ??
        deposit['createdAt'] ??
        deposit['deposited_at'] ??
        deposit['timestamp'] ??
        deposit['date'];
    final parsedDate = DateTime.tryParse(rawDate?.toString() ?? '');
    if (parsedDate == null) return 'Date unavailable';
    return DateFormat('dd MMM yyyy, h:mm a').format(parsedDate.toLocal());
  }

  String _depositAmountLabel(
    Map<String, dynamic> deposit,
    Map<String, dynamic> metadata,
  ) {
    final method = _depositMethodLabel(deposit, metadata);
    final farmAmount = deposit['amount_farm'] ?? metadata['amount_farm'];
    final usdAmount = deposit['amount_usd'] ?? metadata['amount_usd'];
    final usdToFarmRate =
        deposit['usd_to_farm_rate'] ?? metadata['usd_to_farm_rate'];

    if (method == 'CRYPTO' && farmAmount != null && usdAmount != null) {
      final rateText = usdToFarmRate == null
          ? ''
          : ' (1 USD = ${_formatDepositNumber(usdToFarmRate)} FARM)';
      return 'USD ${_formatDepositNumber(usdAmount)} = '
          '${_formatDepositNumber(farmAmount)} FARM$rateText';
    }

    final currency = metadata['currency_fiat'] ?? deposit['currency'] ?? 'KES';
    final fiatAmount = metadata['amount_fiat'] ?? deposit['amount'];
    return '$currency ${_formatDepositNumber(fiatAmount)} ≈ '
        '${_formatDepositNumber(farmAmount ?? deposit['amount'])} FARM';
  }

  String _formatDepositNumber(Object? value) {
    final number = double.tryParse(value?.toString() ?? '');
    if (number == null) return value?.toString() ?? '0';
    return number.toStringAsFixed(number == number.roundToDouble() ? 0 : 2);
  }

  Widget _paymentButton(
    BuildContext context, {
    required String paymentMethod,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F1F1F)
                : Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isLoading || !_isValidDepositAmountFor(paymentMethod)
              ? null
              : () => _createDeposit(paymentMethod),
          icon: Icon(icon),
          label: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  )),
              Text(subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white70,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isKycApproved) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: KycRequiredWidget(feature: 'deposit'),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FlutterFlowIconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => context.goNamed('Dashboard'),
                  ),
                  Text('Deposit Funds',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText)),
                  Icon(Icons.help_outline, color: theme.secondaryText),
                ],
              ),

              const SizedBox(height: 28),

              // Wallet balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111111) : Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: loadingWallet
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wallet Balance',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            '${walletBalance.toStringAsFixed(4)} FARM',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 28),

              // Amount input
              Center(
                child: TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText),
                  decoration: InputDecoration(
                    prefixText: '$selectedCurrency  ',
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 36, color: theme.secondaryText),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                _depositValidationMessage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: amount > 0 && !_hasValidDepositAmount
                      ? Colors.redAccent
                      : theme.secondaryText,
                ),
              ),

              const SizedBox(height: 24),

              // Payment provider
              Text('Choose how to pay',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText)),
              const SizedBox(height: 12),

              _paymentButton(
                context,
                paymentMethod: 'CARD',
                icon: Icons.credit_card,
                title: 'Pay with Paystack',
                subtitle: 'M-Pesa or bank card • KES 10–249,000',
              ),
              _paymentButton(
                context,
                paymentMethod: 'CRYPTO',
                icon: Icons.currency_bitcoin,
                title: 'Pay with IvoryPay',
                subtitle: 'Crypto • USDT • Minimum KES 100',
              ),

              const SizedBox(height: 24),

              // Fee breakdown
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.secondaryText.withAlpha(80)),
                ),
                child: Column(
                  children: [
                    _feeRow('Amount', 'KES ${amount.toStringAsFixed(2)}'),
                    const SizedBox(height: 10),
                    _feeRow('Fee (${(feeRate * 100).toStringAsFixed(1)}%)',
                        'KES ${fee.toStringAsFixed(2)}'),
                    const Divider(height: 20),
                    _feeRow('Total', 'KES ${total.toStringAsFixed(2)}',
                        bold: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 32),

              // Recent deposits
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Deposits',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_selectedDeposits.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Share selected receipts',
                          icon: const Icon(Icons.share_rounded),
                          onPressed: _shareSelectedDeposits,
                        ),
                        IconButton(
                          tooltip: 'Download selected receipts',
                          icon: const Icon(Icons.download_rounded),
                          onPressed: _downloadSelectedDeposits,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (recentDeposits.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No deposits yet',
                        style: GoogleFonts.plusJakartaSans(
                            color: theme.secondaryText)),
                  ),
                )
              else
                ...recentDeposits.asMap().entries.map((entry) {
                  final index = entry.key;
                  final d = entry.value;
                  final deposit = Map<String, dynamic>.from(d as Map);
                  final status = depositStatusLabel(deposit['status']);
                  final isComplete =
                      parseDepositLifecycleStatus(deposit['status']) ==
                          DepositLifecycleStatus.completed;
                  final meta = deposit['metadata'] is Map
                      ? Map<String, dynamic>.from(deposit['metadata'] as Map)
                      : <String, dynamic>{};
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => TransactionReceiptService.showDetails(
                      context,
                      _depositReceipt(deposit, meta),
                      fetchLatest: true,
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border: Border.all(
                            color: theme.secondaryText.withAlpha(70)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectedDeposits.contains(index),
                            onChanged: (selected) => setState(() {
                              if (selected == true) {
                                _selectedDeposits.add(index);
                              } else {
                                _selectedDeposits.remove(index);
                              }
                            }),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isComplete
                                  ? Icons.check_circle_outline
                                  : Icons.hourglass_top,
                              color: isComplete ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _depositDateLabel(deposit),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: theme.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _depositAmountLabel(deposit, meta),
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryText),
                                ),
                                Text(
                                  '≈ ${d['amount']} FARM • $status',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, color: theme.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _depositMethodLabel(deposit, meta),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),
              Center(
                child: Text('Secured by FARM 🔒',
                    style: TextStyle(color: theme.secondaryText, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool bold = false}) {
    final style = GoogleFonts.plusJakartaSans(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _DepositCheckoutSheet extends StatefulWidget {
  const _DepositCheckoutSheet({
    required this.paymentUrl,
    required this.title,
  });

  final String paymentUrl;
  final String title;

  @override
  State<_DepositCheckoutSheet> createState() => _DepositCheckoutSheetState();
}

class _DepositCheckoutSheetState extends State<_DepositCheckoutSheet> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  String? _loadError;
  bool _returnedToApp = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == 'https' &&
                uri.host.toLowerCase() == 'farmapp.africa' &&
                uri.path.replaceAll(RegExp(r'/+$'), '') ==
                    '/payment-callback') {
              if (!_returnedToApp) {
                _returnedToApp = true;
                Navigator.of(context).pop(true);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _loadError = error.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close checkout',
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
          Expanded(
            child: _loadError == null
                ? WebViewWidget(controller: _controller)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load checkout: $_loadError',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.primaryText),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _loadError = null;
                                _loadingProgress = 0;
                              });
                              _controller.reload();
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
