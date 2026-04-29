import 'package:dio/dio.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/features/license/license_global_api.dart';
import 'package:dk_pos/features/license/license_local_api.dart';
import 'package:dk_pos/features/license/license_storage.dart';

sealed class GlobalLicenseStartupResult {}

final class GlobalLicenseStartupNeedKey extends GlobalLicenseStartupResult {}

final class GlobalLicenseStartupBlocked extends GlobalLicenseStartupResult {
  GlobalLicenseStartupBlocked(this.message, {this.suggestServerEndpoint = false});
  final String message;
  /// Показать ввод IP/URL локального backend (сервер не отвечает по сети).
  final bool suggestServerEndpoint;
}

final class GlobalLicenseStartupOk extends GlobalLicenseStartupResult {}

/// Лицензия до запуска POS:
/// 1) **Локальный** backend: `GET /api/local/license/status` — снимок в MySQL; ключ в SharedPreferences **не** используется;
/// 2) при необходимости активации — ввод ключа и `POST …/license/sync` (ключ уходит на сервер, в prefs не пишем);
/// 3) если локальный сервер не настроен для лицензирования — запуск блокируется (лицензия обязательна).
class GlobalLicenseBootstrap {
  /// Быстрая проверка, что локальный backend отвечает (до запроса лицензии).
  static Future<GlobalLicenseStartupResult?> _checkLocalBackendReachable() async {
    try {
      final dio = createDio();
      final res = await dio.get<Object>(
        'api/health',
        options: Options(validateStatus: (_) => true),
      );
      final code = res.statusCode ?? 0;
      if (code == 200) {
        return null;
      }
      return GlobalLicenseStartupBlocked(
        'Локальный сервер (${AppConfig.apiOrigin}) отвечает с кодом HTTP $code вместо 200.\n'
        'Проверьте адрес API и что запущен правильный backend.',
        suggestServerEndpoint: true,
      );
    } on DioException catch (e) {
      return GlobalLicenseStartupBlocked(
        'Локальный сервер недоступен (${AppConfig.apiOrigin}).\n'
        'Введите ниже IP или URL компьютера с backend (порт 3000, если не указан).\n'
        '${e.message ?? e}',
        suggestServerEndpoint: true,
      );
    } catch (e) {
      return GlobalLicenseStartupBlocked(
        'Не удалось связаться с локальным сервером (${AppConfig.apiOrigin}).\n$e',
        suggestServerEndpoint: true,
      );
    }
  }

  static bool _isNeedKeyError(LicenseApiException e) {
    final c = (e.code ?? '').toUpperCase();
    final m = e.message.toLowerCase();
    if (c == 'LICENSE_EXPIRED') return true;
    if (c == 'LICENSE_NOT_ACTIVATED') return true;
    if (c == 'LICENSE_NOT_FOUND') return true;
    if (e.statusCode == 404) return true;
    if (m.contains('лицензия не найд')) return true;
    if (m.contains('license not found')) return true;
    return false;
  }

  static Future<GlobalLicenseStartupResult> _applyPayloadOrNeedKey(
    LicenseStorage storage,
    Map<String, dynamic> json,
  ) async {
    final perpetual = json['perpetual_license'] == true;
    if (!perpetual) {
      final dr = json['days_remaining'];
      if (dr is num && dr <= 0) {
        await storage.wipeLegacyLicensePrefs();
        return GlobalLicenseStartupNeedKey();
      }
    }
    return GlobalLicenseStartupOk();
  }

  static Future<GlobalLicenseStartupResult?> _evaluateViaLocalBackend(
    LicenseStorage storage,
  ) async {
    try {
      final dio = createDio();
      final localApi = LicenseLocalApi(dio);
      final status = await localApi.getStatus();
      final mode = status['licensing_mode']?.toString();
      if (mode != 'on') {
        return null;
      }

      final configured = status['configured'] == true;
      final ok = status['ok'] == true;
      if (configured && ok) {
        await storage.wipeLegacyLicensePrefs();
        return _applyPayloadOrNeedKey(storage, status);
      }

      // Ключ только с экрана ввода, не из SharedPreferences — источник правды локальная БД.
      return GlobalLicenseStartupNeedKey();
    } on LicenseApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      if (_isNeedKeyError(e)) {
        await storage.wipeLegacyLicensePrefs();
        return GlobalLicenseStartupNeedKey();
      }
      return GlobalLicenseStartupBlocked(
        'Локальная лицензия (${AppConfig.apiOrigin}):\n${e.message}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      if (AppConfig.globalLicenseApiOrigin != null &&
          AppConfig.globalLicenseApiOrigin!.isNotEmpty) {
        return null;
      }
      return GlobalLicenseStartupBlocked(
        'Локальный сервер лицензий недоступен (${AppConfig.apiOrigin}).\n'
        'Не задан GLOBAL_LICENSE_API_BASE_URL для прямого обхода.\n$e',
        suggestServerEndpoint: true,
      );
    } catch (e) {
      return GlobalLicenseStartupBlocked(
        'Локальный сервер (${AppConfig.apiOrigin}) при проверке лицензии вернул неожиданную ошибку.\n$e',
      );
    }
  }

  /// Старт POS: 1) доступность локального API; 2) `GET /api/local/license/status`; при валидной записи в БД — без ключа.
  static Future<GlobalLicenseStartupResult> evaluateBeforePos() async {
    final storage = LicenseStorage();
    await storage.ensureDeviceId();

    final reach = await _checkLocalBackendReachable();
    if (reach != null) {
      return reach;
    }

    final local = await _evaluateViaLocalBackend(storage);
    if (local != null) {
      return local;
    }

    return GlobalLicenseStartupBlocked(
      'Лицензия обязательна. На локальном сервере (${AppConfig.apiOrigin}) не включено лицензирование '
      '(задайте GLOBAL_LICENSE_API_BASE_URL в .env backend и перезапустите сервер).',
    );
  }

  static Future<void> activateAndPersist(String licenseKeyPlain) async {
    final storage = LicenseStorage();
    final deviceId = await storage.ensureDeviceId();
    final trimmed = licenseKeyPlain.trim();

    final reach = await _checkLocalBackendReachable();
    if (reach is GlobalLicenseStartupBlocked) {
      throw LicenseApiException(
        reach.message,
        statusCode: 503,
        code: reach.suggestServerEndpoint ? 'LOCAL_SERVER_UNREACHABLE' : 'LICENSE_GATEWAY_ERROR',
      );
    }

    try {
      final dio = createDio();
      final localApi = LicenseLocalApi(dio);
      final status = await localApi.getStatus();
      if (status['licensing_mode']?.toString() == 'on') {
        final synced = await localApi.sync(licenseKey: trimmed, deviceId: deviceId);
        final r = await _applyPayloadOrNeedKey(storage, synced);
        if (r is GlobalLicenseStartupNeedKey) {
          throw LicenseApiException('Срок лицензии истёк', statusCode: 403, code: 'LICENSE_EXPIRED');
        }
        await storage.wipeLegacyLicensePrefs();
        return;
      }
    } on LicenseApiException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        rethrow;
      }
    }

    throw StateError(
      'Лицензия: на локальном API не включён режим licensing_mode=on. '
      'Укажите GLOBAL_LICENSE_API_BASE_URL в .env backend и перезапустите сервер.',
    );
  }
}
