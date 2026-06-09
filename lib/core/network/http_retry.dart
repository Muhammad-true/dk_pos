import 'package:dk_pos/core/error/api_exception.dart';

/// Повторяет запрос при кратковременных сбоях сети (пик заказов, Wi‑Fi).
Future<T> withNetworkRetry<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration initialDelay = const Duration(milliseconds: 350),
}) async {
  Object? last;
  StackTrace? lastStack;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      return await action();
    } catch (e, st) {
      last = e;
      lastStack = st;
      final isLast = attempt >= attempts - 1;
      if (isLast || !isRetryableNetworkError(e)) {
        Error.throwWithStackTrace(e, st);
      }
      await Future<void>.delayed(initialDelay * (attempt + 1));
    }
  }
  Error.throwWithStackTrace(last!, lastStack ?? StackTrace.empty);
}

bool isRetryableNetworkError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401 || error.statusCode == 403) return false;
    if (error.statusCode == 0) return true;
    if (error.statusCode >= 500) return true;
    final msg = error.message.toLowerCase();
    return msg.contains('timeout') ||
        msg.contains('сеть') ||
        msg.contains('связ') ||
        msg.contains('connection');
  }
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('timeout') ||
      text.contains('timed out');
}
