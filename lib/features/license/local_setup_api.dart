import 'package:dio/dio.dart';

/// GET /api/local/setup/network — LAN URL для планшета и проверка глобала.
class LocalSetupApi {
  LocalSetupApi(this._dio);

  final Dio _dio;

  Future<void> saveInstallLocal(String apiBaseUrl) async {
    final res = await _dio.put<Object>(
      'api/local/setup/install-local',
      data: {'apiBaseUrl': apiBaseUrl},
      options: Options(validateStatus: (_) => true),
    );
    final code = res.statusCode ?? 0;
    final data = res.data;
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }
    if (code == 403) {
      throw StateError('Только администратор может сохранить адрес на сервере');
    }
    if (code != 200 || map == null || map['ok'] != true) {
      final err = map?['error']?.toString() ?? 'HTTP $code';
      throw StateError(err);
    }
  }

  Future<LocalNetworkSetup> fetchNetwork() async {
    final res = await _dio.get<Object>(
      'api/local/setup/network',
      options: Options(validateStatus: (_) => true),
    );
    final code = res.statusCode ?? 0;
    final data = res.data;
    Map<String, dynamic>? map;
    if (data is Map<String, dynamic>) {
      map = data;
    } else if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }
    if (code != 200 || map == null || map['ok'] != true) {
      throw StateError('setup/network HTTP $code');
    }
    final global = map['global'];
    return LocalNetworkSetup(
      apiBaseUrlSuggested: map['apiBaseUrlSuggested']?.toString(),
      apiBaseUrlEnv: map['apiBaseUrlEnv']?.toString(),
      lanIpv4: map['lanIpv4']?.toString(),
      port: _asInt(map['port']),
      globalSyncConfigured: global is Map && global['syncConfigured'] == true,
      globalCatalogPullConfigured:
          global is Map && global['catalogPullConfigured'] == true,
    );
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

class LocalNetworkSetup {
  const LocalNetworkSetup({
    this.apiBaseUrlSuggested,
    this.apiBaseUrlEnv,
    this.lanIpv4,
    this.port,
    this.globalSyncConfigured = false,
    this.globalCatalogPullConfigured = false,
  });

  final String? apiBaseUrlSuggested;
  final String? apiBaseUrlEnv;
  final String? lanIpv4;
  final int? port;
  final bool globalSyncConfigured;
  final bool globalCatalogPullConfigured;
}
