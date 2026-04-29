import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'package:dk_pos/app/app_update_info.dart';
import 'package:dk_pos/core/config/app_config.dart';

/// Имя компонента для API глобальных релизов (`pos_windows` / `pos_android`).
/// Должно совпадать с допустимыми значениями на сервере dk_global.
String posReleaseComponentForPlatform() {
  if (kIsWeb) return 'pos_windows';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'pos_android',
    TargetPlatform.windows => 'pos_windows',
    _ => 'pos_windows',
  };
}

/// Запрос `GET /api/v1/releases/check` к глобальному API, если в `.env` задан `GLOBAL_RELEASES_BASE_URL`.
/// Без URL возвращает `null` (глобальная проверка отключена).
Future<AppUpdateInfo?> fetchGlobalReleaseUpdate(String installedVersion) async {
  final base = AppConfig.globalReleasesBaseUrl;
  if (base == null || base.isEmpty) return null;

  final headers = <String, String>{};
  final token = AppConfig.globalUpdateClientToken;
  if (token != null && token.isNotEmpty) {
    headers['X-Update-Token'] = token;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: headers,
    ),
  );

  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/releases/check',
    queryParameters: <String, dynamic>{
      'component': posReleaseComponentForPlatform(),
      'channel': 'stable',
      'current_version': installedVersion,
    },
  );

  final data = response.data;
  if (data == null || data['updateAvailable'] != true) return null;

  final rel = data['release'];
  if (rel is! Map<String, dynamic>) return null;

  return AppUpdateInfo(
    displayName: 'Doner POS',
    installedVersion: installedVersion,
    targetVersion: rel['version']?.toString(),
    minSupportedVersion: rel['minSupportedVersion']?.toString(),
    downloadUrl: _resolveDownloadUrl(base: base, release: rel),
    releaseNotes: rel['releaseNotes']?.toString(),
    isMandatory: rel['mandatory'] == true,
  );
}

/// Сервер отдаёт либо готовый `downloadUrl`, либо только `artifactPath` — собираем URL и при необходимости добавляем токен для GET.
String? _resolveDownloadUrl({
  required String base,
  required Map<String, dynamic> release,
}) {
  final fromServer = release['downloadUrl']?.toString().trim();
  if (fromServer != null && fromServer.isNotEmpty) return fromServer;

  final artifactPath = release['artifactPath']?.toString();
  if (artifactPath == null || artifactPath.isEmpty) return null;

  final origin = base.replaceAll(RegExp(r'/$'), '');
  var url = '$origin$artifactPath';

  final token = AppConfig.globalUpdateClientToken;
  if (token != null && token.isNotEmpty) {
    url = '$url?token=${Uri.encodeQueryComponent(token)}';
  }
  return url;
}
