import 'package:flutter/material.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ForgotPinPageWidget extends StatefulWidget {
  const ForgotPinPageWidget({super.key});

  static String routeName = 'forgot_pin_page';
  static String routePath = '/forgotPinPage';

  @override
  State<ForgotPinPageWidget> createState() => _ForgotPinPageWidgetState();
}

class _ForgotPinPageWidgetState extends State<ForgotPinPageWidget> {
  final _contactController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _contactController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final contact = _contactController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();
    final password = _passwordController.text.trim();

    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.contact_required'.tr())),
      );
      return;
    }

    if (newPin.length < 4 || confirmPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.pin_length'.tr())),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.pin_mismatch'.tr())),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('validation.password_required'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.setPin(
        pin: newPin,
        confirmPin: confirmPin,
      );

      if (!mounted) return;

      final message = response['message']?.toString() ??
          response['error']?.toString() ??
          'pin.updated'.tr();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'pin.update_failed'.tr()}: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: Text('pin.forgot'.tr()),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'pin.reset_title'.tr(),
              style: theme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'pin.reset_description'.tr(),
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _contactController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'pin.phone_or_email'.tr(),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.contact_phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _newPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'New PIN',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _confirmPinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Your password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(_isLoading ? 'Updating PIN...' : 'Reset PIN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}