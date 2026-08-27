import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalOrderHandoutSettings {
  const LocalOrderHandoutSettings({
    required this.autoHandoutEnabled,
    required this.autoHandoutMinutes,
    required this.kitchenReadyAutoHandoutEnabled,
    required this.tvReadyDisplayMinutes,
  });

  final bool autoHandoutEnabled;
  final int autoHandoutMinutes;

  /// «Готово» на кухне = сразу «Выдан» на кассе + колонка «Готово» на ТВ.
  final bool kitchenReadyAutoHandoutEnabled;

  /// Сколько минут заказ виден в «Готово» на ТВ после кухни.
  final int tvReadyDisplayMinutes;
}

class LocalOrderHandoutSettingsRepository {
  LocalOrderHandoutSettingsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  static const Duration _fetchTtl = Duration(seconds: 30);
  final Map<String, ({LocalOrderHandoutSettings settings, DateTime at})> _cache =
      {};

  Future<LocalOrderHandoutSettings> fetch({
    String? branchId,
    bool forceRefresh = false,
  }) async {
    final bid = branchId ?? _defaultBranchId;
    if (!forceRefresh) {
      final hit = _cache[bid];
      if (hit != null && DateTime.now().difference(hit.at) < _fetchTtl) {
        return hit.settings;
      }
    }
    final res = await _http.get(
      'api/local/order-handout-settings',
      query: {'branchId': bid},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ order handout settings');
    }
    final settings = body['settings'];
    final parsed = _parseSettings(settings);
    _cache[bid] = (settings: parsed, at: DateTime.now());
    return parsed;
  }

  Future<LocalOrderHandoutSettings> update({
    required bool autoHandoutEnabled,
    required int autoHandoutMinutes,
    required bool kitchenReadyAutoHandoutEnabled,
    required int tvReadyDisplayMinutes,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/order-handout-settings',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'autoHandoutEnabled': autoHandoutEnabled,
        'autoHandoutMinutes': autoHandoutMinutes,
        'kitchenReadyAutoHandoutEnabled': kitchenReadyAutoHandoutEnabled,
        'tvReadyDisplayMinutes': tvReadyDisplayMinutes,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map || body['settings'] is! Map) {
      throw ApiException(
        res.statusCode,
        'Некорректный ответ после сохранения автовыдачи',
      );
    }
    final bid = branchId ?? _defaultBranchId;
    final parsed = _parseSettings(body['settings']);
    _cache[bid] = (settings: parsed, at: DateTime.now());
    return parsed;
  }

  LocalOrderHandoutSettings _parseSettings(Object? settings) {
    if (settings is! Map) {
      return const LocalOrderHandoutSettings(
        autoHandoutEnabled: true,
        autoHandoutMinutes: 20,
        kitchenReadyAutoHandoutEnabled: false,
        tvReadyDisplayMinutes: 10,
      );
    }
    final enabled = settings['autoHandoutEnabled'];
    final minutesRaw = settings['autoHandoutMinutes'] ??
        settings['auto_handout_minutes'];
    final kitchenRaw = settings['kitchenReadyAutoHandoutEnabled'] ??
        settings['kitchen_ready_auto_handout_enabled'];
    final tvRaw = settings['tvReadyDisplayMinutes'] ??
        settings['tv_ready_display_minutes'];
    final minutes = int.tryParse(minutesRaw?.toString() ?? '') ?? 20;
    final tvMinutes = int.tryParse(tvRaw?.toString() ?? '') ?? 10;
    return LocalOrderHandoutSettings(
      autoHandoutEnabled: enabled == null
          ? true
          : enabled == true || enabled.toString() == '1',
      autoHandoutMinutes: minutes.clamp(1, 24 * 60),
      kitchenReadyAutoHandoutEnabled:
          kitchenRaw == true || kitchenRaw?.toString() == '1',
      tvReadyDisplayMinutes: tvMinutes.clamp(1, 24 * 60),
    );
  }
}
