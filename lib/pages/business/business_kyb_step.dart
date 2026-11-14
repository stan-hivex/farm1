import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/services/api_service.dart';
import 'business_kyb_logic.dart';
import 'business_ui.dart';

/// "Verify business" step: opens Didit's hosted KYB link, like personal KYC.
/// Didit is the only KYB path.
class BusinessKybStep extends StatefulWidget {
  const BusinessKybStep({super.key, this.initialStatus, this.onStatusChanged});

  /// Normalised Didit KYB status from `/business/me` (`didit_kyb_status`).
  final String? initialStatus;
  final ValueChanged<String?>? onStatusChanged;

  @override
  State<BusinessKybStep> createState() => _BusinessKybStepState();
}

class _BusinessKybStepState extends State<BusinessKybStep> {
  late KybUiState _state = kybStateFor(widget.initialStatus);
  bool _busy = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resp = await ApiService.getDiditKybStatus();
      final data = resp['data'] is Map ? resp['data'] as Map : resp;
      if (mounted) {
        final status = data['status']?.toString();
        setState(() => _state = kybStateFor(status));
        widget.onStatusChanged?.call(status);
      }
    } catch (e) {
      if (mounted) setState(() => _error = kybErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Before you continue'),
        content: const Text(
          'FARM will open Didit, our business-verification provider. '
          'Information you enter in Didit will be processed for KYB. '
          'Didit’s signed decision controls whether this business is approved. '
          'Continue only if you are authorized to verify this business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I consent and continue'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ApiService.createDiditKybSession();
      final url = session['url'];
      if (url is! String || url.isEmpty) {
        throw const FormatException('invalid Didit session');
      }
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('could not open Didit');
      if (mounted) {
        setState(() => _state = KybUiState.pending);
        widget.onStatusChanged?.call('pending');
      }
    } catch (e) {
      if (mounted) setState(() => _error = kybErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData get _icon => switch (_state) {
    KybUiState.verified => Icons.verified_outlined,
    KybUiState.declined => Icons.cancel_outlined,
    KybUiState.inReview || KybUiState.pending => Icons.hourglass_top,
    KybUiState.actionNeeded => Icons.info_outline,
    KybUiState.notStarted => Icons.domain_verification_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BizCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: fgColor(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kybTitle(_state),
                      key: const Key('kyb-title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fgColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kybBody(_state),
                style: TextStyle(color: mutedColor(context), height: 1.5),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          BizCard(
            child: Row(
              children: [
                Icon(Icons.error_outline, color: fgColor(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    key: const Key('kyb-error'),
                    style: TextStyle(color: fgColor(context), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(key: Key('kyb-loading')),
            ),
          )
        else ...[
          if (kybCanStart(_state))
            ElevatedButton(
              key: const Key('kyb-start'),
              style: primaryButtonStyle(context),
              onPressed: _start,
              child: Text(kybStartLabel(_state)),
            ),
          if (_state != KybUiState.notStarted) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('kyb-refresh'),
              style: secondaryButtonStyle(context),
              onPressed: _refresh,
              child: const Text('Refresh status'),
            ),
          ],
        ],
        const SizedBox(height: 12),
        Text(
          'This step is required. FARM verifies the business only through Didit.',
          style: TextStyle(
            color: mutedColor(context),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
