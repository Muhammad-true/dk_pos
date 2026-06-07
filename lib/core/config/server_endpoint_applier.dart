import 'package:dio/dio.dart';
import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/features/license/local_setup_api.dart';

class ServerEndpointApplyResult {
  const ServerEndpointApplyResult({
    required this.ok,
    required this.normalizedOrigin,
    this.message,
    this.serverInstallLocalSaved = false,
  });

  final bool ok;
  final String normalizedOrigin;
  final String? message;
  final bool serverInstallLocalSaved;
}

/// Единая смена адреса API: prefs кассы, digital menu, фон кухни, опционально install_local на сервере.
class ServerEndpointApplier {
  static const _kitchenServerKey = 'server_api_origin';
  static const _kitchenBgKey = 'bg_kitchen_api_origin';

  static String formatConnectionError(Object e, {String? targetOrigin}) {
    final origin = targetOrigin ?? AppConfig.apiOrigin;
    final t = e.toString();
    final lower = t.toLowerCase();
    if (lower.contains('no route to host') ||
        lower.contains('network is unreachable') ||
        lower.contains('errno = 113')) {
      return 'Нет маршрута к $origin. После Wi‑Fi IP сервера мог смениться — '
          'нажмите «Подставить с сервера» или введите IP с ipconfig на кассовом ПК.\n\n$t';
    }
    if (lower.contains('connection refused') || lower.contains('connection reset')) {
      return 'Сервер $origin не принимает подключение. Проверьте службу backend и порт 3000.\n\n$t';
    }
    if (lower.contains('failed host lookup')) {
      return 'Неверный адрес сервера.\n\n$t';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Сервер $origin не ответил вовремя.\n\n$t';
    }
    return t;
  }

  static Future<bool> probeHealth(String origin) async {
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
    } catch (_) {
      return false;
    }
  }

  static Future<void> _syncKitchenPrefs(String origin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kitchenServerKey, origin);
    await prefs.setString(_kitchenBgKey, origin);
  }

  static void refreshBoundHttpClient(DioHttpClient? client) {
    if (client == null) return;
    final base = AppConfig.apiOrigin;
    client.updateBaseUrl(base.endsWith('/') ? base : '$base/');
  }

  static Future<ServerEndpointApplyResult> apply(
    String rawInput, {
    bool probeHealth = true,
    bool saveOnServer = false,
    Dio? dioForServerSave,
  }) async {
    final normalized = AppConfig.normalizeServerConnectionInput(rawInput);
    if (normalized.isEmpty) {
      return const ServerEndpointApplyResult(
        ok: false,
        normalizedOrigin: '',
        message: 'Введите IP или URL сервера',
      );
    }

    AppConfig.setApiOriginOverride(normalized);
    dm_app_config.AppConfig.setApiOriginOverride(normalized);

    if (probeHealth) {
      final ok = await ServerEndpointApplier.probeHealth(normalized);
      if (!ok) {
        return ServerEndpointApplyResult(
          ok: false,
          normalizedOrigin: normalized,
          message:
              'Сервер не отвечает по адресу $normalized. Проверьте IP, порт 3000 и что backend запущен.',
        );
      }
    }

    await ServerEndpointStore.save(normalized);
    await _syncKitchenPrefs(normalized);

    var serverSaved = false;
    if (saveOnServer) {
      try {
        final dio = dioForServerSave ?? createDio();
        await LocalSetupApi(dio).saveInstallLocal(normalized);
        serverSaved = true;
      } catch (e) {
        return ServerEndpointApplyResult(
          ok: true,
          normalizedOrigin: normalized,
          serverInstallLocalSaved: false,
          message:
              'На этой кассе адрес сохранён ($normalized), но на сервер записать не удалось: $e',
        );
      }
    }

    return ServerEndpointApplyResult(
      ok: true,
      normalizedOrigin: normalized,
      serverInstallLocalSaved: serverSaved,
      message: serverSaved
          ? 'Адрес $normalized сохранён на кассе и на сервере (для ТВ и планшетов).'
          : 'Адрес $normalized сохранён на этой кассе.',
    );
  }
}
