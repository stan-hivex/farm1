import 'package:flutter/material.dart';
// Removed unused imports
import '/backend/services/api_service.dart';
import '/services/app_session_manager.dart';
import '/services/transaction_authorization_service.dart';
import '/flutter_flow/flutter_flow_util.dart';

class IncomingRequestsWidget extends StatefulWidget {
  const IncomingRequestsWidget({super.key});

  static const routeName = 'IncomingRequests';

  @override
  State<IncomingRequestsWidget> createState() => _IncomingRequestsWidgetState();
}

class _IncomingRequestsWidgetState extends State<IncomingRequestsWidget> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        ApiService.request(method: 'GET', path: '/payment-requests/pending')
            .then((r) => List<dynamic>.from(r['data'] ?? r));
  }

  Future<void> _pay(String requestId) async {
    final pinCtrl = TextEditingController();
    final authResult = await TransactionAuthorizationService()
        .authorizeTransaction(
          localizedReason: 'Confirm payment',
        )
        .then((r) => r.toTransactionAuthenticationResult());

    String? pin;
    if (authResult.biometricUsed != true) {
      final ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('common.pin'.tr()),
                const SizedBox(height: 8),
                TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'common.pin'.tr())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('common.confirm'.tr())))
                ])
              ]),
            );
          });

      if (ok != true) {
        pinCtrl.dispose();
        return;
      }

      pin = pinCtrl.text.trim();
      pinCtrl.dispose();
      if (pin.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('common.pin_required'.tr())));
        return;
      }
    }

    try {
      final res = await ApiService.request(
        method: 'POST',
        path: '/payment-requests/accept',
        body: {
          'request_id': requestId,
          if (authResult.biometricUsed != true) 'pin': pin,
          if (authResult.biometricUsed == true) 'biometric_auth': true,
          if (authResult.deviceFingerprint != null)
            'device_fingerprint': authResult.deviceFingerprint,
        },
      );
      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 5,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? 'Paid')));
      setState(() => _load());
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('common.failed'.tr())));
    }
  }

  Future<void> _decline(String requestId) async {
    try {
      final res = await ApiService.request(
          method: 'POST', path: '/payment-requests/$requestId/reject');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['message'] ?? 'Declined')));
      setState(() => _load());
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('common.failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('common.incoming_requests'.tr())),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError)
            return Center(child: Text('common.load_failed'.tr()));
          final list = snap.data ?? [];
          if (list.isEmpty)
            return Center(child: Text('common.no_pending_requests'.tr()));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _load()),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = list[i] as Map<String, dynamic>;
                final requester = r['users_requester'] ?? {};
                return ListTile(
                  title: Text(requester['username'] ?? 'User'),
                  subtitle: Text('${(r['amount'] as num).toString()} FARM'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(
                        onPressed: () => _decline(r['id']),
                        child: Text('common.cancel'.tr())),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () => _pay(r['id']),
                        child: Text('common.confirm'.tr())),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
