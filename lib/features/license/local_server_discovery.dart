import 'package:dio/dio.dart';
import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/features/license/local_setup_api.dart';

class LocalServerDiscoveryResult {
  const LocalServerDiscoveryResult({
    required this.ok,
    this.needsManualInput = false,
    this.appliedOrigin,
    this.message,
  });

  final bool ok;
  final bool needsManualInput;
  final String? appliedOrigin;
  final String? message;
}

/// Подбор URL локального backend без пересборки POS.
class LocalServerDiscovery {
  static Future<LocalServerDiscoveryResult> resolveAndApply({
    String? manualInput,
  }) async {
    if (manualInput != null && manualInput.trim().isNotEmpty) {
      final normalized = AppConfig.normalizeServerConnectionInput(manualInput);
      if (await _probeHealth(normalized)) {
        await _applyOrigin(normalized, persist: true);
        return LocalServerDiscoveryResult(ok: true, appliedOrigin: normalized);
      }
      return LocalServerDiscoveryResult(
        ok: false,
        needsManualInput: true,
        message:
            'Сервер не отвечает по адресу $normalized. Проверьте IP, порт 3000 и firewall.',
      );
    }

    final saved = await ServerEndpointStore.read();
    if (saved != null && saved.isNotEmpty && await _probeHealth(saved)) {
      await _applyOrigin(saved, persist: false);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: saved);
    }

    final envOrigin = AppConfig.apiOrigin;
    if (!AppConfig.isLocalhostApi && await _probeHealth(envOrigin)) {
      await _applyOrigin(envOrigin, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: envOrigin);
    }

    const localhost = 'http://127.0.0.1:3000';
    if (await _probeHealth(localhost)) {
      final best = await _bestOriginViaSetup(localhost) ?? localhost;
      await _applyOrigin(best, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: best);
    }

    if (envOrigin != localhost && await _probeHealth(envOrigin)) {
      await _applyOrigin(envOrigin, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: envOrigin);
    }

    await restoreSavedOrClearOverride();
    return const LocalServerDiscoveryResult(
      ok: false,
      needsManualInput: true,
      message:
          'Укажите IP компьютера с backend (порт 3000). После активации лицензии адрес сохранится для этой кассы.',
    );
  }

  static Future<bool> _probeHealth(String origin) async {
    AppConfig.setApiOriginOverride(origin);
    dm_app_config.AppConfig.setApiOriginOverride(origin);
    try {
      final dio = createDio();
      final res = await dio.get<Object>(
        'api/health',
        options: Options(
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      return (res.statusCode ?? 0) == 200;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> restoreSavedOrClearOverride() async {
    final saved = await ServerEndpointStore.read();
    if (saved != null && saved.isNotEmpty) {
      AppConfig.setApiOriginOverride(saved);
      dm_app_config.AppConfig.setApiOriginOverride(saved);
    } else {
      AppConfig.clearApiOriginOverride();
      dm_app_config.AppConfig.clearApiOriginOverride();
    }
  }

  static Future<String?> _bestOriginViaSetup(String connectedOrigin) async {
    try {
      await _applyOrigin(connectedOrigin, persist: false);
      final setup = await LocalSetupApi(createDio()).fetchNetwork();
      final suggested = setup.apiBaseUrlSuggested?.trim();
      if (suggested == null || suggested.isEmpty) return null;
      final normalized = AppConfig.normalizeServerConnectionInput(suggested);
      final host = Uri.tryParse(normalized)?.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        return connectedOrigin;
      }
      if (await _probeHealth(normalized)) {
        return normalized;
      }
      return connectedOrigin;
    } catch (_) {
      return connectedOrigin;
    }
  }

  static Future<void> _applyOrigin(String origin, {required bool persist}) async {
    AppConfig.setApiOriginOverride(origin);
    dm_app_config.AppConfig.setApiOriginOverride(origin);
    if (persist) {
      await ServerEndpointStore.save(origin);
    }
  }
}
