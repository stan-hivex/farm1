import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackInlineCheckout extends StatefulWidget {
  const PaystackInlineCheckout({
    required this.accessCode,
    required this.paymentUrl,
    super.key,
  });

  final String? accessCode;
  final String? paymentUrl;

  static Future<bool?> show(
    BuildContext context, {
    required String? accessCode,
    required String? paymentUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => PaystackInlineCheckout(
        accessCode: accessCode,
        paymentUrl: paymentUrl,
      ),
    );
  }

  @override
  State<PaystackInlineCheckout> createState() => _PaystackInlineCheckoutState();
}

class _PaystackInlineCheckoutState extends State<PaystackInlineCheckout> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  bool get _supportsWebView =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    if (!_supportsWebView) {
      _error = 'In-app Paystack checkout is not supported on this device.';
      _loading = false;
      return;
    }
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel(
      'FarmCheckout',
      onMessageReceived: _handleCheckoutMessage,
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null ||
              (uri.scheme != 'https' && uri.scheme != 'http')) {
            return NavigationDecision.prevent;
          }
          if (uri.host == 'farmapp.africa' &&
              uri.path == '/payment-callback') {
            if (mounted) Navigator.of(context).pop(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _loading = false;
              _error = error.description;
            });
          }
        },
      ),
    );

    if (!mounted) return;
    setState(() => _controller = controller);

    final accessCode = widget.accessCode?.trim() ?? '';
    if (accessCode.isNotEmpty) {
      await controller.loadHtmlString(
        _inlineCheckoutHtml(accessCode),
        baseUrl: 'https://farmapp.africa',
      );
      return;
    }

    final checkoutUri = Uri.tryParse(widget.paymentUrl ?? '');
    if (checkoutUri == null ||
        checkoutUri.scheme != 'https' ||
        checkoutUri.host != 'checkout.paystack.com') {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Paystack did not provide a valid in-app checkout session.';
        });
      }
      return;
    }
    await controller.loadRequest(checkoutUri);
  }

  void _handleCheckoutMessage(JavaScriptMessage message) {
    try {
      final event = jsonDecode(message.message);
      if (event is! Map) return;
      final type = event['event']?.toString();
      if (type == 'success') {
        if (mounted) Navigator.of(context).pop(true);
      } else if (type == 'cancelled') {
        if (mounted) Navigator.of(context).pop(false);
      } else if (type == 'error' && mounted) {
        setState(() {
          _loading = false;
          _error = event['message']?.toString() ??
              'Paystack could not load this transaction.';
        });
      }
    } catch (error) {
      debugPrint('Invalid Paystack checkout message: $error');
    }
  }

  String _inlineCheckoutHtml(String accessCode) {
    final encodedAccessCode = jsonEncode(accessCode);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; min-height: 100%; background: #fff; }
    body { font: 15px Arial, sans-serif; color: #333; }
    #checkout-status { padding: 24px; text-align: center; }
  </style>
  <script src="https://js.paystack.co/v2/inline.js"
    onerror="FarmCheckout.postMessage(JSON.stringify({event:'error',message:'Could not load secure Paystack checkout.'}))">
  </script>
</head>
<body>
  <div id="checkout-status">Opening secure Paystack checkout…</div>
  <script>
    try {
      const popup = new PaystackPop();
      popup.resumeTransaction($encodedAccessCode, {
        onSuccess: function (transaction) {
          FarmCheckout.postMessage(JSON.stringify({
            event: 'success',
            reference: transaction.reference || transaction.trxref || ''
          }));
        },
        onCancel: function () {
          FarmCheckout.postMessage(JSON.stringify({event: 'cancelled'}));
        },
        onError: function (error) {
          FarmCheckout.postMessage(JSON.stringify({
            event: 'error',
            message: error && error.message ? error.message : 'Paystack checkout failed.'
          }));
        }
      });
    } catch (error) {
      FarmCheckout.postMessage(JSON.stringify({
        event: 'error',
        message: error && error.message ? error.message : 'Could not open Paystack checkout.'
      }));
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.94,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pay securely with Paystack',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close checkout',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                if (controller != null) WebViewWidget(controller: controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
