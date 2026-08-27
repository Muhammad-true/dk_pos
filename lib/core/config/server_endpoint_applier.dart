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

  static Future<bool> probeHealth(
    String origin, {
    Duration timeout = const Duration(seconds: 12),
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
    } catch (_) {
      return false;
    }
  }

  /// Кандидаты для проверки: введённый адрес, затем localhost (если сервер на этом же ПК).
  static List<String> connectionCandidatesForInput(String rawInput) {
    final normalized = AppConfig.normalizeServerConnectionInput(rawInput);
    final out = <String>[];
    final seen = <String>{};

    void add(String raw) {
      final n = AppConfig.normalizeServerConnectionInput(raw);
      if (n.isEmpty || !seen.add(n)) return;
      out.add(n);
    }

    if (normalized.isNotEmpty) {
      add(normalized);
      final host = Uri.tryParse(normalized)?.host.toLowerCase();
      final isLoopback = host == '127.0.0.1' || host == 'localhost';
      if (!isLoopback) {
        add('http://127.0.0.1:3000');
        add('http://localhost:3000');
      }
    } else {
      add('http://127.0.0.1:3000');
      add('http://localhost:3000');
      add(AppConfig.defaultLocalServerOrigin);
    }
    return out;
  }

  static List<String> startupProbeOrigins({
    String? savedOrigin,
    String? envOrigin,
  }) {
    final out = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final n = AppConfig.normalizeServerConnectionInput(raw);
      if (n.isEmpty || !seen.add(n)) return;
      out.add(n);
    }

    add(savedOrigin);
    // На кассовом ПК с Windows backend часто доступен только через loopback.
    add('http://127.0.0.1:3000');
    add('http://localhost:3000');
    add(AppConfig.defaultLocalServerOrigin);
    if (envOrigin != null &&
        envOrigin.trim().isNotEmpty &&
        envOrigin != savedOrigin) {
      add(envOrigin);
    }
    return out;
  }

  static Future<String?> firstReachableOrigin(
    Iterable<String> origins, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    for (final origin in origins) {
      if (await probeHealth(origin, timeout: timeout)) {
        return origin;
      }
    }
    return null;
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

    var effectiveOrigin = normalized;
    AppConfig.setApiOriginOverride(effectiveOrigin);
    dm_app_config.AppConfig.setApiOriginOverride(effectiveOrigin);

    if (probeHealth) {
      final candidates = connectionCandidatesForInput(rawInput);
      final reachable = await firstReachableOrigin(candidates);
      if (reachable == null) {
        return ServerEndpointApplyResult(
          ok: false,
          normalizedOrigin: effectiveOrigin,
          message:
              'Сервер не отвечает по адресу $effectiveOrigin '
              '(и через 127.0.0.1:3000 на этом ПК). '
              'Проверьте, что служба backend запущена, порт 3000 открыт. '
              'Если касса на том же компьютере — попробуйте http://127.0.0.1:3000',
        );
      }
      effectiveOrigin = reachable;
      AppConfig.setApiOriginOverride(effectiveOrigin);
      dm_app_config.AppConfig.setApiOriginOverride(effectiveOrigin);
    }

    await ServerEndpointStore.save(effectiveOrigin);
    await _syncKitchenPrefs(effectiveOrigin);

    var serverSaved = false;
    final installLocalOrigin = _installLocalOriginForPeers(
      userInput: normalized,
      connectedOrigin: effectiveOrigin,
    );
    if (saveOnServer) {
      try {
        final dio = dioForServerSave ?? createDio();
        await LocalSetupApi(dio).saveInstallLocal(installLocalOrigin);
        serverSaved = true;
      } catch (e) {
        return ServerEndpointApplyResult(
          ok: true,
          normalizedOrigin: effectiveOrigin,
          serverInstallLocalSaved: false,
          message:
              'На этой кассе адрес сохранён ($effectiveOrigin), но на сервер записать не удалось: $e',
        );
      }
    }

    final usedLoopbackFallback = effectiveOrigin != normalized;
    return ServerEndpointApplyResult(
      ok: true,
      normalizedOrigin: effectiveOrigin,
      serverInstallLocalSaved: serverSaved,
      message: serverSaved
          ? 'Подключено: $effectiveOrigin. Для ТВ/планшетов на сервере: $installLocalOrigin'
          : usedLoopbackFallback
              ? 'Подключено через $effectiveOrigin (backend на этом ПК). '
                  'Для кухни/планшетов введите $normalized'
              : 'Адрес $effectiveOrigin сохранён на этой кассе.',
    );
  }

  static String _installLocalOriginForPeers({
    required String userInput,
    required String connectedOrigin,
  }) {
    final userHost = Uri.tryParse(userInput)?.host.toLowerCase();
    final connectedHost = Uri.tryParse(connectedOrigin)?.host.toLowerCase();
    final connectedIsLoopback =
        connectedHost == '127.0.0.1' || connectedHost == 'localhost';
    final userIsLan = userHost != null &&
        userHost != '127.0.0.1' &&
        userHost != 'localhost';
    if (connectedIsLoopback && userIsLan) {
      return userInput;
    }
    return connectedOrigin;
  }
}
