import '/backend/services/api_service.dart';

class PaymentRequestApiService {
  static String get defaultRequestExpiryIso =>
      DateTime.now().toUtc().add(const Duration(hours: 12)).toIso8601String();

  static Future<Map<String, dynamic>> requestPayment({
    required String recipientIdentifier,
    required double amount,
    String? description,
  }) async {
    final resp = await ApiService.request(
      method: 'POST',
      path: '/payment-requests/request',
      body: {
        'recipient_identifier': recipientIdentifier,
        'amount': amount,
        'description': description ?? '',
        'expires_at': defaultRequestExpiryIso,
      },
      requiresAuth: true,
    );
    return resp;
  }

  static Future<List<dynamic>> getPendingRequests() async {
    final resp = await ApiService.request(
      method: 'GET',
      path: '/payment-requests/pending',
      requiresAuth: true,
    );
    return List<dynamic>.from(resp['data'] ?? []);
  }

  static Future<Map<String, dynamic>> acceptPaymentRequest({
    required String requestId,
    String? pin,
    bool? biometricAuth,
    String? deviceFingerprint,
  }) async {
    final resp = await ApiService.request(
      method: 'POST',
      path: '/payment-requests/accept',
      body: {
        'request_id': requestId,
        if (pin != null) 'pin': pin,
        if (biometricAuth == true) 'biometric_auth': true,
        if (deviceFingerprint != null) 'device_fingerprint': deviceFingerprint,
      },
      requiresAuth: true,
    );
    return resp;
  }

  /// Summarises `data.results` so a partial batch is not reported as a full success.
  static String batchResultMessage(Map<String, dynamic> response) {
    final data = response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : response;
    final results = data['results'] ?? response['results'];
    if (results is List && results.isNotEmpty) {
      final failed = <String>[];
      var approved = 0;
      for (final item in results) {
        if (item is! Map) continue;
        final ok = item['success'] == true ||
            item['ok'] == true ||
            item['status'] == 'accepted' ||
            item['status'] == 'completed' ||
            item['status'] == 'approved';
        if (ok) {
          approved++;
          continue;
        }
        final id = '${item['request_id'] ?? item['id'] ?? ''}'.trim();
        final error = '${item['error'] ?? item['message'] ?? 'failed'}'.trim();
        failed.add(id.isEmpty ? error : '$id: $error');
      }
      if (approved == 0 && failed.isEmpty) {
        return _topMessage(response, data);
      }
      final parts = <String>[];
      if (approved > 0) parts.add('Approved $approved.');
      if (failed.isNotEmpty) parts.add('Could not approve ${failed.length}: ${failed.join('; ')}');
      return parts.join(' ');
    }
    return _topMessage(response, data);
  }

  static String _topMessage(Map<String, dynamic> response, Map<String, dynamic> data) {
    if (response['message'] is String && (response['message'] as String).trim().isNotEmpty) {
      return (response['message'] as String).trim();
    }
    if (data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
      return (data['message'] as String).trim();
    }
    return 'Selected requests completed';
  }

  static Future<Map<String, dynamic>> acceptPaymentRequestsBatch({
    required List<String> requestIds,
    String? pin,
    bool? biometricAuth,
    String? deviceFingerprint,
  }) async {
    return ApiService.request(
      method: 'POST',
      path: '/payment-requests/accept-batch',
      body: {
        'request_ids': requestIds,
        if (pin != null) 'pin': pin,
        if (biometricAuth == true) 'biometric_auth': true,
        if (deviceFingerprint != null) 'device_fingerprint': deviceFingerprint,
      },
      requiresAuth: true,
    );
  }

  static Future<Map<String, dynamic>> rejectPaymentRequest({
    required String requestId,
  }) async {
    final resp = await ApiService.request(
      method: 'POST',
      path: '/payment-requests/$requestId/reject',
      requiresAuth: true,
    );
    return resp;
  }

  static Future<Map<String, dynamic>> cancelPaymentRequest({
    required String requestId,
  }) async {
    final resp = await ApiService.request(
      method: 'POST',
      path: '/payment-requests/$requestId/cancel',
      requiresAuth: true,
    );
    return resp;
  }
}
