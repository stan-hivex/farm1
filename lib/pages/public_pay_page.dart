import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/qr_public_payment_api.dart';

class PublicPayPage extends StatefulWidget {
  const PublicPayPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  State<PublicPayPage> createState() => _PublicPayPageState();
}

class _PublicPayPageState extends State<PublicPayPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _emailController = TextEditingController();

  Map<String, dynamic>? _merchant;
  String _method = 'mpesa';
  String? _error;
  bool _loadingMerchant = true;
  bool _submitting = false;
  bool _openingFarmApp = false;

  bool get _invalidMerchantId =>
      widget.merchantId.isEmpty ||
      widget.merchantId == 'ANYID' ||
      widget.merchantId.length < 10;

  @override
  void initState() {
    super.initState();
    if (_invalidMerchantId) {
      _loadingMerchant = false;
      _error = 'Invalid QR Code. Please ask the merchant to regenerate.';
    } else {
      _loadMerchant();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchant() async {
    try {
      final response = await QrPublicPaymentApi.get(
        '/merchants/public/${Uri.encodeComponent(widget.merchantId)}',
      );
      final data = response['data'];
      if (data is! Map) {
        throw const FormatException('Merchant details were not returned.');
      }
      if (!mounted) return;
      setState(() {
        _merchant = Map<String, dynamic>.from(data);
        _loadingMerchant = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingMerchant = false;
      });
    }
  }

  Future<void> _startPayment() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await QrPublicPaymentApi.post(
        '/qr-payments/initialize',
        {
          'merchantId': widget.merchantId,
          'amount': amount,
          'method': _method,
          'guestEmail': _emailController.text.trim(),
        },
      );
      final data = response['data'];
      final paymentUrl =
          data is Map ? data['authorization_url']?.toString() : null;
      final uri = paymentUrl == null ? null : Uri.tryParse(paymentUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the payment provider checkout.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openFarmApp() async {
    final farmName = _merchant?['farmName']?.toString().trim();
    final storedQrPayload = _merchant?['qrPayload']?.toString().trim();
    final qrPayload = storedQrPayload != null && storedQrPayload.isNotEmpty
        ? storedQrPayload
        : 'https://farmapp-e2145.web.app/pay/'
            '${Uri.encodeComponent(widget.merchantId)}';
    final deepLink = Uri(
      scheme: 'farm',
      host: 'farm.com',
      path: '/pay',
      queryParameters: {
        'merchantId': widget.merchantId,
        'businessName':
            farmName == null || farmName.isEmpty ? 'Merchant' : farmName,
        'qrPayload': qrPayload,
      },
    );

    setState(() {
      _openingFarmApp = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() {
          _error = 'Could not open FARM. Make sure the app is installed.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not open FARM: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _openingFarmApp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmName = _merchant?['farmName']?.toString() ?? 'merchant';
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _loadingMerchant
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _merchant == null
                        ? _ErrorMessage(message: _error!)
                        : Form(
                            key: _formKey,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                Text(
                                  'Pay $farmName',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text('Securely pay this FARM merchant.'),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed:
                                      _openingFarmApp ? null : _openFarmApp,
                                  icon: _openingFarmApp
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.open_in_new),
                                  label: const Text(
                                    'Open Farm to pay with your FARM wallet',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text('Or pay with another method.'),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (KES)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    final amount =
                                        double.tryParse(value?.trim() ?? '');
                                    if (amount == null ||
                                        !amount.isFinite ||
                                        amount <= 0) {
                                      return 'Enter an amount greater than 0.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _method,
                                  decoration: const InputDecoration(
                                    labelText: 'Payment method',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'mpesa',
                                      child: Text('M-Pesa'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'card',
                                      child: Text('Card'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'bank',
                                      child: Text('Bank transfer'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'crypto',
                                      child: Text('Crypto'),
                                    ),
                                  ],
                                  onChanged: _submitting
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(() => _method = value);
                                          }
                                        },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty ||
                                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                            .hasMatch(email)) {
                                      return 'Enter a valid email address.';
                                    }
                                    return null;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'you@example.com',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _submitting ? null : _startPayment,
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Continue to payment'),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}
