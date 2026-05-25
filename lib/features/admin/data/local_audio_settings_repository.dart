import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalAudioSettings {
  const LocalAudioSettings({
    required this.readySoundPath,
    required this.kitchenSoundPath,
    required this.websiteOrderSoundPath,
    required this.kitchenTtsEnabled,
    required this.kitchenTtsRate,
    required this.kitchenTtsLocale,
    required this.kitchenTtsVoiceName,
    required this.tvReadySoundVolume,
    required this.tvTtsVolume,
    required this.tvVideoVolume,
  });

  final String? readySoundPath;
  final String? kitchenSoundPath;
  /// Новый входящий онлайн-заказ (сайт) на кассу.
  final String? websiteOrderSoundPath;
  final bool kitchenTtsEnabled;
  final double kitchenTtsRate;
  final String kitchenTtsLocale;
  final String? kitchenTtsVoiceName;
  /// Громкость сигнала «готово» на клиентском ТВ (0–1).
  final double tvReadySoundVolume;
  /// Громкость озвучки номера на ТВ (0–1).
  final double tvTtsVolume;
  /// Громкость видео-фона на слайдах ТВ2/ТВ3 (0–1).
  final double tvVideoVolume;
}

class LocalAudioSettingsRepository {
  LocalAudioSettingsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  /// Касса и кухня часто дергают звуки подряд; кэш снижает нагрузку на сеть и UI.
  static const Duration _fetchTtl = Duration(seconds: 45);
  final Map<String, ({LocalAudioSettings settings, DateTime at})> _fetchCache = {};

  void _putCache(String branchId, LocalAudioSettings s) {
    _fetchCache[branchId] = (settings: s, at: DateTime.now());
  }

  /// [forceRefresh] — всегда с сервера (например экран админки со звуками).
  Future<LocalAudioSettings> fetch({String? branchId, bool forceRefresh = false}) async {
    final bid = branchId ?? _defaultBranchId;
    if (!forceRefresh) {
      final hit = _fetchCache[bid];
      if (hit != null && DateTime.now().difference(hit.at) < _fetchTtl) {
        return hit.settings;
      }
    }
    final res = await _http.get(
      'api/local/audio-settings',
      query: {'branchId': bid},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ audio settings');
    }
    final settings = body['settings'];
    if (settings is! Map) {
      const empty = LocalAudioSettings(
        readySoundPath: null,
        kitchenSoundPath: null,
        websiteOrderSoundPath: null,
        kitchenTtsEnabled: true,
        kitchenTtsRate: 0.48,
        kitchenTtsLocale: 'ru-RU',
        kitchenTtsVoiceName: null,
        tvReadySoundVolume: 1,
        tvTtsVolume: 1,
        tvVideoVolume: 0,
      );
      _putCache(bid, empty);
      return empty;
    }
    final ttsRate = num.tryParse(settings['kitchenTtsRate']?.toString() ?? '')?.toDouble() ?? 0.48;
    final parsed = LocalAudioSettings(
      readySoundPath: settings['readySoundPath']?.toString(),
      kitchenSoundPath: settings['kitchenSoundPath']?.toString(),
      websiteOrderSoundPath: settings['websiteOrderSoundPath']?.toString() ??
          settings['website_order_sound_path']?.toString(),
      kitchenTtsEnabled: settings['kitchenTtsEnabled'] == null
          ? true
          : settings['kitchenTtsEnabled'] == true ||
              settings['kitchenTtsEnabled'].toString() == '1',
      kitchenTtsRate: ttsRate,
      kitchenTtsLocale: settings['kitchenTtsLocale']?.toString() ?? 'ru-RU',
      kitchenTtsVoiceName: settings['kitchenTtsVoiceName']?.toString(),
      tvReadySoundVolume: _parseVolume(settings['tvReadySoundVolume'], 1),
      tvTtsVolume: _parseVolume(settings['tvTtsVolume'], 1),
      tvVideoVolume: _parseVolume(settings['tvVideoVolume'], 0),
    );
    _putCache(bid, parsed);
    return parsed;
  }

  Future<LocalAudioSettings> update({
    required String readySoundPath,
    String? kitchenSoundPath,
    String? websiteOrderSoundPath,
    bool? kitchenTtsEnabled,
    double? kitchenTtsRate,
    String? kitchenTtsLocale,
    String? kitchenTtsVoiceName,
    double? tvReadySoundVolume,
    double? tvTtsVolume,
    double? tvVideoVolume,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/audio-settings',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'readySoundPath': readySoundPath,
        'kitchenSoundPath': kitchenSoundPath,
        'websiteOrderSoundPath': websiteOrderSoundPath,
        'kitchenTtsEnabled': kitchenTtsEnabled,
        'kitchenTtsRate': kitchenTtsRate,
        'kitchenTtsLocale': kitchenTtsLocale,
        'kitchenTtsVoiceName': kitchenTtsVoiceName,
        if (tvReadySoundVolume != null) 'tvReadySoundVolume': tvReadySoundVolume,
        if (tvTtsVolume != null) 'tvTtsVolume': tvTtsVolume,
        if (tvVideoVolume != null) 'tvVideoVolume': tvVideoVolume,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map || body['settings'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ после сохранения настроек');
    }
    final settings = body['settings'] as Map;
    final ttsRate = num.tryParse(settings['kitchenTtsRate']?.toString() ?? '')?.toDouble() ?? 0.48;
    final bid = branchId ?? _defaultBranchId;
    final parsed = LocalAudioSettings(
      readySoundPath: settings['readySoundPath']?.toString(),
      kitchenSoundPath: settings['kitchenSoundPath']?.toString(),
      websiteOrderSoundPath: settings['websiteOrderSoundPath']?.toString() ??
          settings['website_order_sound_path']?.toString(),
      kitchenTtsEnabled: settings['kitchenTtsEnabled'] == null
          ? true
          : settings['kitchenTtsEnabled'] == true ||
              settings['kitchenTtsEnabled'].toString() == '1',
      kitchenTtsRate: ttsRate,
      kitchenTtsLocale: settings['kitchenTtsLocale']?.toString() ?? 'ru-RU',
      kitchenTtsVoiceName: settings['kitchenTtsVoiceName']?.toString(),
      tvReadySoundVolume: _parseVolume(settings['tvReadySoundVolume'], 1),
      tvTtsVolume: _parseVolume(settings['tvTtsVolume'], 1),
      tvVideoVolume: _parseVolume(settings['tvVideoVolume'], 0),
    );
    _putCache(bid, parsed);
    return parsed;
  }

  static double _parseVolume(Object? raw, double fallback) {
    final n = num.tryParse(raw?.toString() ?? '');
    if (n == null || !n.isFinite) return fallback.clamp(0.0, 1.0);
    return n.toDouble().clamp(0.0, 1.0);
  }
}
