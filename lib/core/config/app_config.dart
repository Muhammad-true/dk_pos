import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфиг из `assets/.env` → `API_BASE_URL`, иначе dart-define, иначе localhost.
class AppConfig {
  AppConfig._();

  static String? _apiOriginOverride;
  static int? _defaultStoreBranchFranchiseId;

  /// Runtime ID точки: `default_location_id` из лицензии, иначе `franchise_id`
  /// (как backend getDefaultStoreBranchId).
  static void setDefaultStoreBranchIdFromFranchise(int? branchId) {
    if (branchId != null && branchId > 0) {
      _defaultStoreBranchFranchiseId = branchId;
    } else {
      _defaultStoreBranchFranchiseId = null;
    }
  }

  static void clearDefaultStoreBranchIdFromFranchise() {
    _defaultStoreBranchFranchiseId = null;
  }

  /// Локальный `branch_id` для orders/payments/смена (совпадает с backend getDefaultStoreBranchId).
  static String get storeBranchId {
    final f = _defaultStoreBranchFranchiseId;
    if (f != null && f > 0) return f.toString();
    throw StateError(
      'STORE_BRANCH_ID_UNRESOLVED: default_location_id / franchise_id не получен из локальной лицензии.',
    );
  }

  static void setApiOriginOverride(String value) {
    _apiOriginOverride = _normalize(value);
  }

  static void clearApiOriginOverride() {
    _apiOriginOverride = null;
  }

  /// IP кассового ПК по умолчанию (подсеть точки).
  static const String defaultLocalServerHost = '192.168.0.101';

  /// Полный origin локального backend для автоподключения кухни / планшетов.
  static const String defaultLocalServerOrigin =
      'http://$defaultLocalServerHost:3000';

  /// Подсказка в поле IP (не используется для подключения).
  static const String serverHostInputHint = defaultLocalServerHost;

  /// @deprecated Используйте [serverHostInputHint]. Оставлено для совместимости UI.
  static const String defaultServerHost = serverHostInputHint;

  static bool get isLocalhostApi {
    final host = Uri.tryParse(apiOrigin)?.host.toLowerCase();
    return host == '127.0.0.1' || host == 'localhost';
  }

  /// Хост для поля «IP сервера» на экране подключения.
  static String serverInputHintHost({String? savedOrigin}) {
    if (savedOrigin != null && savedOrigin.trim().isNotEmpty) {
      final host = Uri.tryParse(savedOrigin.trim())?.host;
      if (host != null && host.isNotEmpty) return host;
    }
    if (!isLocalhostApi) {
      final host = Uri.tryParse(apiOrigin)?.host;
      if (host != null &&
          host.isNotEmpty &&
          host != '127.0.0.1' &&
          host != 'localhost') {
        return host;
      }
    }
    return defaultLocalServerHost;
  }

  /// Озвучка и сигнал нового заказа на экране кухни (Windows).
  /// По умолчанию включено. Отключить: `POS_DISABLE_KITCHEN_AUDIO_ON_WINDOWS=true`
  static bool get posEnableKitchenAudioOnWindows {
    try {
      final v = dotenv
          .maybeGet('POS_DISABLE_KITCHEN_AUDIO_ON_WINDOWS')
          ?.trim()
          .toLowerCase();
      if (v == null || v.isEmpty) return true;
      return !(v == '1' || v == 'true' || v == 'yes' || v == 'on');
    } catch (_) {
      return true;
    }
  }

  /// Второе окно (экран покупателя) на Windows. Отключите на терминале, где из‑за него зависает или закрывается приложение.
  /// В `assets/.env`: `POS_DISABLE_CUSTOMER_DISPLAY=true` или `1`.
  static bool get isCustomerDisplayWindowDisabled {
    try {
      final v = dotenv
          .maybeGet('POS_DISABLE_CUSTOMER_DISPLAY')
          ?.trim()
          .toLowerCase();
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
  /// На Wi‑Fi LAN дефолт 2500 — не дублируем full HTTP поверх WS-патчей.
  static int get cashierRealtimeMinGapMs {
    final n = _readInt('POS_CASHIER_REALTIME_MIN_GAP_MS');
    if (n == null) return 2500;
    return n.clamp(0, 10000);
  }

  /// Период обновления счётчиков сборки/выдачи для бейджа кассы (сек).
  static int get expeditorRefreshIntervalSec {
    final n = _readInt('POS_EXPEDITOR_REFRESH_INTERVAL_SEC');
    if (n == null) return 30;
    return n.clamp(10, 180);
  }

  /// Модуль сортировщика (очередь сборка/выдача). По умолчанию включён.
  /// Отключить: `POS_ENABLE_EXPEDITOR=false` в `.env`.
  static bool get posEnableExpeditor {
    try {
      final raw = dotenv.maybeGet('POS_ENABLE_EXPEDITOR')?.trim().toLowerCase();
      if (raw == null || raw.isEmpty) return true;
      if (raw == '0' || raw == 'false' || raw == 'no' || raw == 'off') {
        return false;
      }
      return raw == '1' || raw == 'true' || raw == 'yes' || raw == 'on';
    } catch (_) {
      return true;
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
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uploadsPath = _extractUploadsRelativePath(path);
      if (uploadsPath != null) {
        return '$apiOrigin/$uploadsPath';
      }
      return path;
    }
    final p = path.replaceFirst(RegExp(r'^/+'), '');
    final origin = apiOrigin;
    if (p.startsWith('uploads/')) return '$origin/$p';
    return '$origin/uploads/$p';
  }

  /// Поддержка legacy-конфигов: ранее в screen config могли сохраниться
  /// абсолютные URL с прошлым IP сервера. Если ссылка указывает на uploads,
  /// возвращаем относительный путь uploads/... для склейки с актуальным apiOrigin.
  static String? _extractUploadsRelativePath(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final idx = segments.indexOf('uploads');
    if (idx < 0) return null;
    final tail = segments.sublist(idx).join('/');
    if (tail.isEmpty) return null;
    return tail;
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
  /// Режим красного бейджа «инциденты синхронизации» в админке (меню / «Смены и кухня»).
  /// В `assets/.env`: `POS_ADMIN_SYNC_INCIDENT_MODE`
  ///
  /// - `full` (по умолчанию) — незакрытые ошибки импорта сайт-заказов + `outbox.failed` + 1,
  ///   если у push или pull есть `lastError`.
  /// - `site_only` — только незакрытые ошибки импорта сайт-заказов (без учёта push/pull и outbox).
  /// - `strict` — как `full`, плюс в счёт добавляется число событий outbox в retry (`retrying` из API).
  static PosAdminSyncIncidentMode get adminSyncIncidentMode {
    try {
      final v = dotenv
          .maybeGet('POS_ADMIN_SYNC_INCIDENT_MODE')
          ?.trim()
          .toLowerCase();
      if (v == null || v.isEmpty) return PosAdminSyncIncidentMode.full;
      if (v == 'site_only' ||
          v == 'site' ||
          v == 'website' ||
          v == 'website_only') {
        return PosAdminSyncIncidentMode.siteOnly;
      }
      if (v == 'strict' || v == 'sla' || v == 'strict_sla') {
        return PosAdminSyncIncidentMode.strict;
      }
      if (v == 'full' || v == 'default') {
        return PosAdminSyncIncidentMode.full;
      }
      return PosAdminSyncIncidentMode.full;
    } catch (_) {
      return PosAdminSyncIncidentMode.full;
    }
  }

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

    final hasExplicitPort =
        RegExp(r'^(\d{1,3}\.){3}\d{1,3}:\d+$').hasMatch(t) ||
        RegExp(r'^[\w.-]+:\d+$').hasMatch(t);
    if (hasExplicitPort) {
      return _normalize('http://$t');
    }
    return _normalize('http://$t:3000');
  }
}

/// См. [AppConfig.adminSyncIncidentMode].
enum PosAdminSyncIncidentMode { full, siteOnly, strict }
