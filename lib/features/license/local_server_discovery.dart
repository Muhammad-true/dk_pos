import 'package:dio/dio.dart';
import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/core/network/lan_backend_scanner.dart';
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
  static const Duration _quickProbeTimeout = Duration(seconds: 4);
  static const Duration _autoProbeTimeout = Duration(seconds: 8);

  static const String _localhostOrigin = 'http://127.0.0.1:3000';

  /// Быстрый старт: сохранённый → localhost → .env → скан подсети Wi‑Fi.
  static Future<LocalServerDiscoveryResult> resolveQuick() async {
    final saved = await ServerEndpointStore.read();
    final envOrigin = AppConfig.apiOrigin;
    final tryFirst = <String>[
      if (saved != null && saved.isNotEmpty) saved,
      _localhostOrigin,
      if (!AppConfig.isLocalhostApi &&
          envOrigin != saved &&
          envOrigin != _localhostOrigin)
        envOrigin,
    ];

    for (final origin in tryFirst) {
      if (await _probeHealth(origin, timeout: _quickProbeTimeout)) {
        final persist = origin != saved;
        await _applyOrigin(origin, persist: persist);
        return LocalServerDiscoveryResult(ok: true, appliedOrigin: origin);
      }
    }

    await restoreSavedOrClearOverride();

    final scanned = await LanBackendScanner.findBackendOrigin(
      tryFirst: tryFirst,
      probeTimeout: const Duration(seconds: 2),
      batchSize: 24,
    );
    if (scanned != null) {
      await _applyOrigin(scanned, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: scanned);
    }

    await restoreSavedOrClearOverride();
    return LocalServerDiscoveryResult(
      ok: false,
      needsManualInput: true,
      message:
          'Сервер не найден в сети. Введите IP кассового ПК (порт 3000) '
          'или нажмите «Автопоиск в сети».',
    );
  }

  /// Полный автопоиск: сохранённый → localhost → .env → скан подсети → setup API.
  static Future<LocalServerDiscoveryResult> resolveAuto() async {
    final saved = await ServerEndpointStore.read();
    final envOrigin = AppConfig.apiOrigin;
    final tryFirst = <String>[
      if (saved != null && saved.isNotEmpty) saved,
      _localhostOrigin,
      if (!AppConfig.isLocalhostApi &&
          envOrigin != saved &&
          envOrigin != _localhostOrigin)
        envOrigin,
    ];

    for (final origin in tryFirst) {
      if (await _probeHealth(origin, timeout: _autoProbeTimeout)) {
        final persist = origin != saved;
        await _applyOrigin(origin, persist: persist);
        return LocalServerDiscoveryResult(ok: true, appliedOrigin: origin);
      }
    }

    await restoreSavedOrClearOverride();

    final scanned = await LanBackendScanner.findBackendOrigin(
      tryFirst: tryFirst,
      probeTimeout: _autoProbeTimeout,
      batchSize: 32,
    );
    if (scanned != null) {
      final best = await _bestOriginViaSetup(scanned) ?? scanned;
      await _applyOrigin(best, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: best);
    }

    if (await _probeHealth(_localhostOrigin, timeout: _autoProbeTimeout)) {
      final best = await _bestOriginViaSetup(_localhostOrigin) ?? _localhostOrigin;
      await _applyOrigin(best, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: best);
    }

    await restoreSavedOrClearOverride();
    return const LocalServerDiscoveryResult(
      ok: false,
      needsManualInput: true,
      message:
          'Автопоиск не нашёл сервер. Введите IP кассового ПК и нажмите «Подключить».',
    );
  }

  static Future<LocalServerDiscoveryResult> resolveAndApply({
    String? manualInput,
  }) async {
    if (manualInput != null && manualInput.trim().isNotEmpty) {
      final normalized = AppConfig.normalizeServerConnectionInput(manualInput);
      if (await _probeHealth(normalized, timeout: _autoProbeTimeout)) {
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

    return resolveQuick();
  }

  static Future<bool> _probeHealth(
    String origin, {
    Duration timeout = _autoProbeTimeout,
  }) async {
    AppConfig.setApiOriginOverride(origin);
    dm_app_config.AppConfig.setApiOriginOverride(origin);
    try {
      final dio = createDio();
      final res = await dio.get<Object>(
        'api/health',
        options: Options(
          validateStatus: (_) => true,
          sendTimeout: timeout,
          receiveTimeout: timeout,
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
      if (suggested == null || suggested.isEmpty) return connectedOrigin;
      final normalized = AppConfig.normalizeServerConnectionInput(suggested);
      if (normalized == connectedOrigin) return connectedOrigin;
      final host = Uri.tryParse(normalized)?.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        return connectedOrigin;
      }
      if (await _probeHealth(normalized, timeout: _autoProbeTimeout)) {
        return normalized;
      }
      await _applyOrigin(connectedOrigin, persist: false);
      return connectedOrigin;
    } catch (_) {
      await _applyOrigin(connectedOrigin, persist: false);
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
