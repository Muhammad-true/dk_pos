import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_applier.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';

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

/// Подключение к backend: только сохранённый IP или ручной ввод (без сканирования LAN).
class LocalServerDiscovery {
  static const Duration _savedProbeTimeout = Duration(seconds: 3);

  /// Быстрый старт: сохранённый IP + проверка health (без автопоиска).
  static Future<LocalServerDiscoveryResult> resolveQuick() async {
    final saved = await ServerEndpointStore.read();
    if (saved == null || saved.isEmpty) {
      return const LocalServerDiscoveryResult(
        ok: false,
        needsManualInput: true,
        message: 'Введите IP кассового ПК (порт 3000).',
      );
    }

    if (!await ServerEndpointStore.isNetworkBindingValid()) {
      return const LocalServerDiscoveryResult(
        ok: false,
        needsManualInput: true,
        message:
            'Сменилась Wi‑Fi сеть. Введите IP сервера заново (настройки или при входе).',
      );
    }

    if (await ServerEndpointApplier.probeHealth(
      saved,
      timeout: _savedProbeTimeout,
    )) {
      await _applyOrigin(saved, persist: false);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: saved);
    }

    return const LocalServerDiscoveryResult(
      ok: false,
      needsManualInput: true,
      message:
          'Сервер не отвечает по сохранённому адресу. '
          'Проверьте, что backend запущен, и введите IP заново.',
    );
  }

  /// Ручной ввод IP (без сканирования подсети).
  static Future<LocalServerDiscoveryResult> resolveAndApply({
    String? manualInput,
  }) async {
    if (manualInput == null || manualInput.trim().isEmpty) {
      return resolveQuick();
    }

    final normalized = AppConfig.normalizeServerConnectionInput(manualInput);
    if (await ServerEndpointApplier.probeHealth(
      normalized,
      timeout: const Duration(seconds: 8),
    )) {
      await _applyOrigin(normalized, persist: true);
      return LocalServerDiscoveryResult(ok: true, appliedOrigin: normalized);
    }

    return LocalServerDiscoveryResult(
      ok: false,
      needsManualInput: true,
      message:
          'Сервер не отвечает по адресу $normalized. '
          'Проверьте IP (ipconfig на кассе), порт 3000 и Wi‑Fi.',
    );
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

  static Future<void> _applyOrigin(String origin, {required bool persist}) async {
    AppConfig.setApiOriginOverride(origin);
    dm_app_config.AppConfig.setApiOriginOverride(origin);
    if (persist) {
      await ServerEndpointStore.save(origin);
    }
  }
}
