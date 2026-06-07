import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/features/license/license_local_api.dart';
import 'package:dk_pos/features/license/local_setup_api.dart';

/// Применяет ответ лицензии (default_location_id или franchise_id → branchId).
class LicenseRuntimeConfig {
  static int? _parsePositiveInt(dynamic raw) {
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      final n = raw.toInt();
      return n > 0 ? n : null;
    }
    final n = int.tryParse(raw?.toString() ?? '');
    return n != null && n > 0 ? n : null;
  }

  static void applyFromLicenseStatus(Map<String, dynamic> status) {
    final fr = status['franchise'];
    if (fr is! Map) {
      AppConfig.clearDefaultStoreBranchIdFromFranchise();
      return;
    }
    final locationId = _parsePositiveInt(
      fr['default_location_id'] ?? fr['defaultLocationId'],
    );
    final franchiseId = _parsePositiveInt(fr['id']);
    final branchId = locationId ?? franchiseId;
    if (branchId != null) {
      AppConfig.setDefaultStoreBranchIdFromFranchise(branchId);
    } else {
      AppConfig.clearDefaultStoreBranchIdFromFranchise();
    }
  }

  /// После активации: branchId + LAN URL в prefs (для планшетов на той же точке).
  static Future<void> applyAfterLicenseActivation({
    Map<String, dynamic>? syncResponse,
  }) async {
    if (syncResponse != null) {
      applyFromLicenseStatus(syncResponse);
    }
    try {
      final status = await LicenseLocalApi(createDio()).getStatus();
      applyFromLicenseStatus(status);
    } catch (_) {}
    await persistBestServerEndpoint();
  }

  static Future<void> persistBestServerEndpoint() async {
    try {
      final setup = await LocalSetupApi(createDio()).fetchNetwork();
      final suggested = setup.apiBaseUrlSuggested?.trim();
      if (suggested == null || suggested.isEmpty) return;
      final normalized = AppConfig.normalizeServerConnectionInput(suggested);
      final current = AppConfig.apiOrigin;
      if (normalized == current) {
        await ServerEndpointStore.save(normalized);
        return;
      }
      final host = Uri.tryParse(normalized)?.host.toLowerCase();
      final curHost = Uri.tryParse(current)?.host.toLowerCase();
      final isLan =
          host != null &&
          host != 'localhost' &&
          host != '127.0.0.1' &&
          (curHost == 'localhost' || curHost == '127.0.0.1');
      if (isLan || normalized != current) {
        AppConfig.setApiOriginOverride(normalized);
        dm_app_config.AppConfig.setApiOriginOverride(normalized);
        await ServerEndpointStore.save(normalized);
      }
    } catch (_) {}
  }
}
