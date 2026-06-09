import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';

/// Понятное сообщение для UI вместо «ApiException(0): Ошибка сети».
String formatNetworkErrorMessage(Object error) {
  if (error is ApiException) {
    return _formatApiException(error);
  }
  final text = error.toString().trim();
  if (text.startsWith('ApiException(')) {
    final colon = text.indexOf(': ');
    if (colon > 0 && colon < text.length - 2) {
      return _humanizeRawMessage(text.substring(colon + 2).trim());
    }
  }
  return _humanizeRawMessage(text);
}

String _formatApiException(ApiException error) {
  if (error.statusCode == 403) {
    return error.message;
  }
  if (error.statusCode == 401) {
    return 'Сессия истекла — выйдите и войдите снова';
  }
  return _humanizeRawMessage(error.message, statusCode: error.statusCode);
}

String _humanizeRawMessage(String message, {int statusCode = 0}) {
  final msg = message.trim();
  final lower = msg.toLowerCase();
  if (statusCode == 0 ||
      lower == 'ошибка сети' ||
      lower.contains('connection error') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('socketexception')) {
    return 'Нет связи с сервером ${AppConfig.apiOrigin}. '
        'Проверьте Wi‑Fi и что backend запущен на кассовом ПК.';
  }
  if (lower.contains('timeout') || lower.contains('timed out') || lower.contains('не ответил')) {
    return 'Сервер ${AppConfig.apiOrigin} не ответил вовремя. Повторите через несколько секунд.';
  }
  if (msg.isEmpty) {
    return 'Ошибка связи с сервером ${AppConfig.apiOrigin}';
  }
  return msg;
}
