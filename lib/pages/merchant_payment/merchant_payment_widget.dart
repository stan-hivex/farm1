import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/services/api_service.dart';
import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/app_session_manager.dart';
import '/widgets/common/back_chevron.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MerchantPaymentWidget extends StatefulWidget {
  const MerchantPaymentWidget({
    super.key,
    required this.merchantId,
    required this.businessName,
    required this.qrPayload,
  });

  static String routeName = 'MerchantPayment';
  static String routePath = '/merchantPayment';

  final String merchantId;
  final String businessName;
  final String qrPayload;

  @override
  State<MerchantPaymentWidget> createState() => _MerchantPaymentWidgetState();
}

class _MerchantPaymentWidgetState extends State<MerchantPaymentWidget> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final FocusNode pinFocusNode = FocusNode();
  bool isLoading = false;
  bool _pinEntryEnabled = false;
  bool _isBiometricChecking = false;
  String error = '';
  TransactionAuthenticationResult? _lastPinAuthResult;

  Future<void> _startExternalPayment(String paymentMethod) async {
    final kesController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    var crypto = 'USDT';
    var chain = 'BSC';
    Map<String, String>? details;

    try {
      details = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Pay ${widget.businessName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: kesController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                    ),
                  ),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                  ),
                  if (paymentMethod == 'MOBILE_MONEY')
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number with country code',
                      ),
                    ),
                  if (paymentMethod == 'CRYPTO') ...[
                    DropdownButtonFormField<String>(
                      initialValue: crypto,
                      decoration: const InputDecoration(labelText: 'Token'),
                      items: const ['USDT', 'USDC']
                          .map((token) => DropdownMenuItem(
                                value: token,
                                child: Text(token),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => crypto = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: chain,
                      decoration: const InputDecoration(labelText: 'Network'),
                      items: const [
                        'BSC',
                        'POLYGON',
                        'SOL',
                        'BASE',
                        'STARKNET',
                        'ALGORAND',
                      ]
                          .map((network) => DropdownMenuItem(
                                value: network,
                                child: Text(network),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => chain = value);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'amount': kesController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'crypto': crypto,
                  'chain': chain,
                }),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      kesController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }

    if (details == null) return;
    final amountKes = double.tryParse(details['amount'] ?? '') ?? 0;
    if (!amountKes.isFinite || amountKes <= 0) {
      _showSnack('Enter an amount greater than 0');
      return;
    }
    if (paymentMethod == 'CRYPTO' && (details['email'] ?? '').trim().isEmpty) {
      _showSnack('Enter an email address for crypto payment');
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await ApiService.request(
        method: 'POST',
        path: '/qr/checkout/payment',
        requiresAuth: false,
        body: {
          'qr_payload': widget.qrPayload,
          'amount_kes': amountKes,
          'payment_method': paymentMethod,
          if ((details['email'] ?? '').isNotEmpty) 'email': details['email'],
          if ((details['phone'] ?? '').isNotEmpty) 'phone': details['phone'],
          if (paymentMethod == 'CRYPTO') ...{
            'crypto': details['crypto'],
            'chain': details['chain'],
          },
        },
      );
      final data = response['data'];
      final paymentUrl = data is Map ? data['payment_url']?.toString() : null;
      final uri = paymentUrl == null ? null : Uri.tryParse(paymentUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the payment provider checkout');
      }
    } catch (e) {
      if (mounted) _showSnack('Could not start payment: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    pinController.dispose();
    pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _promptBiometricForPinField() async {
    if (_lastPinAuthResult?.biometricUsed == true) {
      return;
    }

    try {
      setState(() => _isBiometricChecking = true);
      final authResult = await TransactionAuthorizationService()
          .authorizeTransaction(
            localizedReason: 'Confirm payment',
          )
          .then((r) => r.toTransactionAuthenticationResult());

      if (authResult.biometricUsed) {
        if (mounted) {
          setState(() {
            _lastPinAuthResult = authResult;
          });
        }

        await _submitPayment();
        return;
      }

      if (mounted) {
        setState(() {
          _lastPinAuthResult = authResult;
          _pinEntryEnabled = true;
        });
        pinFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isBiometricChecking = false);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (isLoading) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final pin = pinController.text.trim();

    if (amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }

    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final authResult = _lastPinAuthResult ??
          await TransactionAuthorizationService()
              .authorizeTransaction(
                localizedReason: 'Confirm payment',
              )
              .then((r) => r.toTransactionAuthenticationResult());

      if (authResult?.biometricUsed == true) {
        await ApiService.merchantPay(
          qrPayload: widget.qrPayload,
          amount: amount,
          pin: null,
          biometricAuth: true,
          deviceFingerprint: authResult?.deviceFingerprint,
        );

        final current = FFAppState().walletBalance;
        FFAppState().walletBalance = current + amount;

        await AppSessionManager().syncNow(
          profileTimeoutSeconds: 5,
          walletTimeoutSeconds: 5,
          transactionsTimeoutSeconds: 5,
        );

        if (!mounted) return;
        _showSnack('common.transaction_success'.tr());
        context.pop();
        return;
      }

      if (authResult?.biometricUsed != true && pin.isEmpty) {
        _showSnack('common.pin_required'.tr());
        return;
      }

      await ApiService.merchantPay(
        qrPayload: widget.qrPayload,
        amount: amount,
        pin: pin,
        biometricAuth: null,
        deviceFingerprint: authResult?.deviceFingerprint,
      );

      // Optimistic update: ensure the app's main wallet UI reflects
      // the incoming platform credit immediately. The backend should
      // also record this on the server; this client-side increment
      // provides immediate feedback if the server-side platform
      // wallet update is not yet visible.
      final current = FFAppState().walletBalance;
      FFAppState().walletBalance = current + amount;

      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 5,
      );

      if (!mounted) return;
      _showSnack('common.transaction_success'.tr());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
      _showSnack('common.transaction_failed'.tr());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Merchant Payment'),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryText),
      ),
      backgroundColor: theme.primaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName.isNotEmpty
                  ? 'Pay to ${widget.businessName}'
                  : 'Pay to merchant',
              style: theme.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.businessName.isNotEmpty)
              Text(
                'Business: ${widget.businessName}',
                style: theme.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text('Merchant ID: ${widget.merchantId}', style: theme.bodyMedium),
            const SizedBox(height: 24),
            Text(
              'Pay with FARM wallet',
              style: theme.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Amount',
                style: theme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                filled: true,
                fillColor: theme.secondaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.alternate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pinEntryEnabled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transaction PIN',
                      style: theme.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    focusNode: pinFocusNode,
                    readOnly: _isBiometricChecking,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    onTap: () async {
                      if (!_pinEntryEnabled && !_isBiometricChecking) {
                        await _promptBiometricForPinField();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter PIN',
                      filled: true,
                      fillColor: theme.secondaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Or pay in KES',
                    style:
                        theme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const <Map<String, String>>[
                        {'label': 'Card', 'method': 'CARD'},
                        {'label': 'Mobile money', 'method': 'MOBILE_MONEY'},
                        {'label': 'Bank transfer', 'method': 'BANK_TRANSFER'},
                        {'label': 'Crypto', 'method': 'CRYPTO'},
                      ])
                        OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () => _startExternalPayment(option['method']!),
                          child: Text(option['label']!),
                        ),
                    ],
                  ),
                ],
              )
            else if (!_isBiometricChecking)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _promptBiometricForPinField,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : theme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Continue',
                      style: theme.titleMedium.copyWith(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 24),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            if (_pinEntryEnabled)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : theme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Builder(builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final textColor =
                              isDark ? Colors.black : Colors.white;
                          return Text('Pay Merchant',
                              style: theme.titleMedium.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.bold));
                        }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
