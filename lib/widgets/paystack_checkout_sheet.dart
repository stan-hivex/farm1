import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackCheckoutSheet extends StatefulWidget {
  const PaystackCheckoutSheet({
    required this.authorizationUrl,
    required this.reference,
    this.callbackUrl,
    super.key,
  });

  final String authorizationUrl;
  final String reference;
  final String? callbackUrl;

  static Future<bool?> show(
    BuildContext context, {
    required String authorizationUrl,
    required String reference,
    String? callbackUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => PaystackCheckoutSheet(
        authorizationUrl: authorizationUrl,
        reference: reference,
        callbackUrl: callbackUrl,
      ),
    );
  }

  @override
  State<PaystackCheckoutSheet> createState() => _PaystackCheckoutSheetState();
}

class _PaystackCheckoutSheetState extends State<PaystackCheckoutSheet> {
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
      _loading = false;
      _error = 'In-app Paystack checkout is not supported on this device.';
      return;
    }
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final uri = Uri.tryParse(widget.authorizationUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'checkout.paystack.com') {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Paystack did not provide a valid checkout URL.';
        });
      }
      return;
    }

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          final navigationUri = Uri.tryParse(request.url);
          if (navigationUri == null ||
              (navigationUri.scheme != 'https' &&
                  navigationUri.scheme != 'http')) {
            return NavigationDecision.prevent;
          }
          if (_isCheckoutReturn(navigationUri)) {
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
    await controller.loadRequest(uri);
  }

  bool _isCheckoutReturn(Uri uri) {
    final expectedCallback = Uri.tryParse(widget.callbackUrl ?? '');
    if (expectedCallback != null &&
        uri.scheme == expectedCallback.scheme &&
        uri.host == expectedCallback.host &&
        uri.path == expectedCallback.path) {
      return true;
    }

    if (uri.toString().contains(widget.reference)) return true;

    final host = uri.host.toLowerCase();
    final isPaystackHost = host == 'paystack.co' ||
        host.endsWith('.paystack.co') ||
        host == 'paystack.com' ||
        host.endsWith('.paystack.com');
    return isPaystackHost &&
        uri.pathSegments.any((segment) => segment.toLowerCase() == 'close');
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
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
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
