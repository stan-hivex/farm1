import 'dart:async';

import 'package:http/http.dart' as http;

import '/backend/services/api_service.dart';

/// Reads a notifications payload whether the list is `data` or nested.
List<Map<String, dynamic>> notificationItems(dynamic response) {
  if (response is! Map) return const [];
  final data = response['data'];
  final raw = data is List
      ? data
      : data is Map && data['notifications'] is List
          ? data['notifications'] as List
          : response['notifications'] is List
              ? response['notifications'] as List
              : const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

int notificationLastPage(dynamic response, int page) {
  if (response is! Map) return page;
  final meta = response['meta'];
  if (meta is! Map) return page;
  return int.tryParse('${meta['last_page'] ?? ''}') ?? page;
}

/// Offline with nothing cached is the only time we say the phone is offline.
/// Other failures stay retryable and do not replace a list we already have.
String? notificationFailureMessage(Object error, {required bool hasCache}) {
  final type = error.runtimeType.toString();
  final text = error.toString().toLowerCase();
  final offline = error is TimeoutException ||
      error is http.ClientException ||
      type == 'SocketException' ||
      type == 'HandshakeException' ||
      text.contains('socketexception') ||
      text.contains('failed host lookup');
  if (offline) {
    return hasCache
        ? null
        : 'You are offline. Pull to refresh when you are back online.';
  }
  if (hasCache) return null;
  if (error is ApiServiceException && error.statusCode == 429) {
    return error.message;
  }
  return 'Could not refresh notifications. Pull to try again.';
}
