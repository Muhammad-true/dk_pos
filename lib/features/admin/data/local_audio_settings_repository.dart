import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalAudioSettings {
  const LocalAudioSettings({
    required this.readySoundPath,
    required this.kitchenSoundPath,
    required this.kitchenTtsEnabled,
    required this.kitchenTtsRate,
    required this.kitchenTtsLocale,
    required this.kitchenTtsVoiceName,
  });

  final String? readySoundPath;
  final String? kitchenSoundPath;
  final bool kitchenTtsEnabled;
  final double kitchenTtsRate;
  final String kitchenTtsLocale;
  final String? kitchenTtsVoiceName;
}

class LocalAudioSettingsRepository {
  LocalAudioSettingsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<LocalAudioSettings> fetch({String? branchId}) async {
    final res = await _http.get(
      'api/local/audio-settings',
      query: {'branchId': branchId ?? _defaultBranchId},
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
      return const LocalAudioSettings(
        readySoundPath: null,
        kitchenSoundPath: null,
        kitchenTtsEnabled: true,
        kitchenTtsRate: 0.48,
        kitchenTtsLocale: 'ru-RU',
        kitchenTtsVoiceName: null,
      );
    }
    final ttsRate = num.tryParse(settings['kitchenTtsRate']?.toString() ?? '')?.toDouble() ?? 0.48;
    return LocalAudioSettings(
      readySoundPath: settings['readySoundPath']?.toString(),
      kitchenSoundPath: settings['kitchenSoundPath']?.toString(),
      kitchenTtsEnabled: settings['kitchenTtsEnabled'] == null
          ? true
          : settings['kitchenTtsEnabled'] == true ||
              settings['kitchenTtsEnabled'].toString() == '1',
      kitchenTtsRate: ttsRate,
      kitchenTtsLocale: settings['kitchenTtsLocale']?.toString() ?? 'ru-RU',
      kitchenTtsVoiceName: settings['kitchenTtsVoiceName']?.toString(),
    );
  }

  Future<LocalAudioSettings> update({
    required String readySoundPath,
    String? kitchenSoundPath,
    bool? kitchenTtsEnabled,
    double? kitchenTtsRate,
    String? kitchenTtsLocale,
    String? kitchenTtsVoiceName,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/audio-settings',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'readySoundPath': readySoundPath,
        'kitchenSoundPath': kitchenSoundPath,
        'kitchenTtsEnabled': kitchenTtsEnabled,
        'kitchenTtsRate': kitchenTtsRate,
        'kitchenTtsLocale': kitchenTtsLocale,
        'kitchenTtsVoiceName': kitchenTtsVoiceName,
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
    return LocalAudioSettings(
      readySoundPath: settings['readySoundPath']?.toString(),
      kitchenSoundPath: settings['kitchenSoundPath']?.toString(),
      kitchenTtsEnabled: settings['kitchenTtsEnabled'] == null
          ? true
          : settings['kitchenTtsEnabled'] == true ||
              settings['kitchenTtsEnabled'].toString() == '1',
      kitchenTtsRate: ttsRate,
      kitchenTtsLocale: settings['kitchenTtsLocale']?.toString() ?? 'ru-RU',
      kitchenTtsVoiceName: settings['kitchenTtsVoiceName']?.toString(),
    );
  }
}
