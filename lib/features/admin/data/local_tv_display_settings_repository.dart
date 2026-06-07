import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalTvDisplaySettings {
  const LocalTvDisplaySettings({
    required this.queueOnly,
    required this.queueTtsEnabled,
    required this.fakeDeliveryEnabled,
    required this.queuePollSeconds,
    required this.readyTtsPhrase,
    required this.readyTtsPhraseNoNumber,
    required this.announceAcceptedOnTv,
    required this.acceptedTtsPhrase,
  });

  final bool queueOnly;
  final bool queueTtsEnabled;
  final bool fakeDeliveryEnabled;
  final int queuePollSeconds;
  final String readyTtsPhrase;
  final String readyTtsPhraseNoNumber;
  final bool announceAcceptedOnTv;
  final String acceptedTtsPhrase;

  static const defaultReadyWithNumber = 'Заказ номер {number}. Можно забирать!';
  static const defaultReadyNoNumber = 'Можно забирать заказ!';
  static const defaultAcceptedWithNumber = 'Заказ номер {number}. Принят.';

  static const defaults = LocalTvDisplaySettings(
    queueOnly: false,
    queueTtsEnabled: true,
    fakeDeliveryEnabled: false,
    queuePollSeconds: 10,
    readyTtsPhrase: defaultReadyWithNumber,
    readyTtsPhraseNoNumber: defaultReadyNoNumber,
    announceAcceptedOnTv: false,
    acceptedTtsPhrase: defaultAcceptedWithNumber,
  );

  factory LocalTvDisplaySettings.fromJson(Map settings) {
    return LocalTvDisplaySettings(
      queueOnly: _bool(settings['queueOnly'] ?? settings['queue_only'], false),
      queueTtsEnabled: _bool(settings['queueTtsEnabled'] ?? settings['queue_tts_enabled'], true),
      fakeDeliveryEnabled:
          _bool(settings['fakeDeliveryEnabled'] ?? settings['fake_delivery_enabled'], false),
      queuePollSeconds: _poll(settings['queuePollSeconds'] ?? settings['queue_poll_seconds']),
      readyTtsPhrase: _phrase(
        settings['readyTtsPhrase'] ?? settings['ready_tts_phrase'],
        defaultReadyWithNumber,
      ),
      readyTtsPhraseNoNumber: _phrase(
        settings['readyTtsPhraseNoNumber'] ?? settings['ready_tts_phrase_no_number'],
        defaultReadyNoNumber,
      ),
      announceAcceptedOnTv: _bool(
        settings['announceAcceptedOnTv'] ?? settings['announce_accepted_on_tv'],
        false,
      ),
      acceptedTtsPhrase: _phrase(
        settings['acceptedTtsPhrase'] ?? settings['accepted_tts_phrase'],
        defaultAcceptedWithNumber,
      ),
    );
  }

  static bool _bool(Object? raw, bool fallback) {
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    final s = raw.toString().trim().toLowerCase();
    if (s == '1' || s == 'true' || s == 'yes' || s == 'on') return true;
    if (s == '0' || s == 'false' || s == 'no' || s == 'off') return false;
    return fallback;
  }

  static int _poll(Object? raw) {
    final n = int.tryParse(raw?.toString() ?? '');
    if (n == null) return 10;
    return n.clamp(3, 120);
  }

  static String _phrase(Object? raw, String fallback) {
    final s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return fallback;
    return s.length > 255 ? s.substring(0, 255) : s;
  }
}

class LocalTvDisplaySettingsRepository {
  LocalTvDisplaySettingsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<LocalTvDisplaySettings> fetch({String? branchId}) async {
    final res = await _http.get(
      'api/local/tv-display-settings',
      query: {'branchId': branchId ?? _defaultBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ настроек ТВ');
    }
    final settings = body['settings'];
    if (settings is! Map) return LocalTvDisplaySettings.defaults;
    return LocalTvDisplaySettings.fromJson(Map<String, dynamic>.from(settings));
  }

  Future<LocalTvDisplaySettings> update({
    required bool queueOnly,
    required bool queueTtsEnabled,
    required bool fakeDeliveryEnabled,
    required int queuePollSeconds,
    required String readyTtsPhrase,
    required String readyTtsPhraseNoNumber,
    required bool announceAcceptedOnTv,
    required String acceptedTtsPhrase,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/tv-display-settings',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'queueOnly': queueOnly,
        'queueTtsEnabled': queueTtsEnabled,
        'fakeDeliveryEnabled': fakeDeliveryEnabled,
        'queuePollSeconds': queuePollSeconds,
        'readyTtsPhrase': readyTtsPhrase,
        'readyTtsPhraseNoNumber': readyTtsPhraseNoNumber,
        'announceAcceptedOnTv': announceAcceptedOnTv,
        'acceptedTtsPhrase': acceptedTtsPhrase,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ настроек ТВ');
    }
    final settings = body['settings'];
    if (settings is! Map) return LocalTvDisplaySettings.defaults;
    return LocalTvDisplaySettings.fromJson(Map<String, dynamic>.from(settings));
  }
}
