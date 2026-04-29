import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфиг из `assets/.env` → `API_BASE_URL`, иначе dart-define, иначе localhost.
class AppConfig {
  AppConfig._();

  static String? _apiOriginOverride;
  static int? _defaultStoreBranchFranchiseId;

  /// Runtime-источник `branchId`: franchiseId из локальной лицензии
  /// (как на backend: `branch_id` в заказах/оплатах — локальный код точки; для одной точки = id франшизы).
  static void setDefaultStoreBranchIdFromFranchise(int? franchiseId) {
    if (franchiseId != null && franchiseId > 0) {
      _defaultStoreBranchFranchiseId = franchiseId;
    } else {
      _defaultStoreBranchFranchiseId = null;
    }
  }

  static void clearDefaultStoreBranchIdFromFranchise() {
    _defaultStoreBranchFranchiseId = null;
  }

  /// Локальный `branchId` для orders/payments/смена (не путать с `franchise_id` в меню).
  static String get storeBranchId {
    final f = _defaultStoreBranchFranchiseId;
    if (f != null && f > 0) return f.toString();
    throw StateError(
      'STORE_BRANCH_ID_UNRESOLVED: franchise_id не получен из локальной лицензии.',
    );
  }

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

  /// Период фонового обновления кассовых списков (сек), если нет realtime-событий.
  static int get cashierRefreshIntervalSec {
    final n = _readInt('POS_CASHIER_REFRESH_INTERVAL_SEC');
    if (n == null) return 35;
    return n.clamp(10, 120);
  }

  /// Минимальный интервал между реакциями на realtime-события (мс).
  static int get cashierRealtimeMinGapMs {
    final n = _readInt('POS_CASHIER_REALTIME_MIN_GAP_MS');
    if (n == null) return 2500;
    return n.clamp(500, 10000);
  }

  /// Период обновления счётчиков сборки/выдачи для бейджа кассы (сек).
  static int get expeditorRefreshIntervalSec {
    final n = _readInt('POS_EXPEDITOR_REFRESH_INTERVAL_SEC');
    if (n == null) return 30;
    return n.clamp(10, 180);
  }

  /// Включить модуль сборщика (очередь bundling/pickup).
  /// По умолчанию выключен для упрощенного потока кухня -> касса.
  /// В `.env`: `POS_ENABLE_EXPEDITOR=true`
  static bool get posEnableExpeditor {
    try {
      final raw = dotenv.maybeGet('POS_ENABLE_EXPEDITOR')?.trim().toLowerCase();
      if (raw == null || raw.isEmpty) return false;
      return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
    } catch (_) {
      return false;
    }
  }

  /// Количество столов в зале для выбора в POS.
  /// В `.env`: `POS_HALL_TABLE_COUNT=15`
  static int get posHallTableCount {
    final n = _readInt('POS_HALL_TABLE_COUNT');
    if (n == null) return 15;
    return n.clamp(1, 80);
  }

  /// Количество столов на веранде для выбора в POS.
  /// В `.env`: `POS_VERANDA_TABLE_COUNT=10`
  static int get posVerandaTableCount {
    final n = _readInt('POS_VERANDA_TABLE_COUNT');
    if (n == null) return 10;
    return n.clamp(0, 80);
  }

  /// База глобального API (лицензии), без `/api`. Пример: `https://api.donerkebab.tj`
  /// В `assets/.env`: `GLOBAL_LICENSE_API_BASE_URL=...` — если пусто, проверка лицензии отключена.
  static String? get globalLicenseApiOrigin {
    try {
      final v = dotenv.maybeGet('GLOBAL_LICENSE_API_BASE_URL')?.trim();
      if (v == null || v.isEmpty) return null;
      return _normalize(v);
    } catch (_) {
      return null;
    }
  }

  /// База глобального API для канала релизов (`/api/v1/releases/check`). Часто совпадает с [globalLicenseApiOrigin].
  static String? get globalReleasesBaseUrl {
    try {
      final v = dotenv.maybeGet('GLOBAL_RELEASES_BASE_URL')?.trim();
      if (v == null || v.isEmpty) return null;
      return _normalize(v);
    } catch (_) {
      return null;
    }
  }

  /// Токен `X-Update-Token` — тот же, что `UPDATE_CLIENT_TOKEN` на глобальном API.
  static String? get globalUpdateClientToken {
    try {
      final v = dotenv.maybeGet('GLOBAL_UPDATE_CLIENT_TOKEN')?.trim();
      if (v == null || v.isEmpty) return null;
      return v;
    } catch (_) {
      return null;
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

  static int? _readInt(String key) {
    try {
      final raw = dotenv.maybeGet(key)?.trim();
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    } catch (_) {
      return null;
    }
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
