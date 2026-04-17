import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфиг из `assets/.env` → `API_BASE_URL`, иначе dart-define, иначе localhost.
class AppConfig {
  AppConfig._();

  static String? _apiOriginOverride;

  static void setApiOriginOverride(String value) {
    _apiOriginOverride = _normalize(value);
  }

  static void clearApiOriginOverride() {
    _apiOriginOverride = null;
  }

  static bool get isLocalhostApi {
    final host = Uri.tryParse(apiOrigin)?.host.toLowerCase();
    return host == '127.0.0.1' || host == 'localhost';
  }

  /// Второе окно (экран покупателя) на Windows. Отключите на терминале, где из‑за него зависает или закрывается приложение.
  /// В `assets/.env`: `POS_DISABLE_CUSTOMER_DISPLAY=true` или `1`.
  static bool get isCustomerDisplayWindowDisabled {
    try {
      final v =
          dotenv.maybeGet('POS_DISABLE_CUSTOMER_DISPLAY')?.trim().toLowerCase();
      if (v == null || v.isEmpty) return false;
      return v == '1' || v == 'true' || v == 'yes' || v == 'on';
    } catch (_) {
      return false;
    }
  }

  static String get apiOrigin {
    if (_apiOriginOverride != null && _apiOriginOverride!.isNotEmpty) {
      return _apiOriginOverride!;
    }
    String? fromDot;
    try {
      fromDot = dotenv.maybeGet('API_BASE_URL')?.trim();
    } catch (_) {}
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final raw = (fromDot != null && fromDot.isNotEmpty)
        ? fromDot
        : (fromDefine.isNotEmpty ? fromDefine : 'http://127.0.0.1:3000');
    return _normalize(raw);
  }

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final p = path.replaceFirst(RegExp(r'^/+'), '');
    final origin = apiOrigin;
    if (p.startsWith('uploads/')) return '$origin/$p';
    return '$origin/uploads/$p';
  }

  static String _normalize(String raw) {
    var base = raw.trim().replaceAll(RegExp(r'/$'), '');
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Ввод с экрана подключения: всегда приводит к URL с портом API (по умолчанию 3000).
  /// Иначе `http://192.168.x.x` без порта шёл на :80 и давал «удалённый компьютер отклонил подключение».
  static String normalizeServerConnectionInput(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;

    if (t.startsWith('http://') || t.startsWith('https://')) {
      final uri = Uri.tryParse(t);
      if (uri == null || uri.host.isEmpty) return _normalize(t);
      if (uri.hasPort) return _normalize(t);
      if (uri.scheme == 'http') {
        return _normalize(uri.replace(port: 3000).toString());
      }
      return _normalize(t);
    }

    final hasExplicitPort = RegExp(
      r'^(\d{1,3}\.){3}\d{1,3}:\d+$',
    ).hasMatch(t) || RegExp(r'^[\w.-]+:\d+$').hasMatch(t);
    if (hasExplicitPort) {
      return _normalize('http://$t');
    }
    return _normalize('http://$t:3000');
  }
}
