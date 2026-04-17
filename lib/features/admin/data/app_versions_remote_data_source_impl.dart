import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/app_version_row.dart';
import 'package:dk_pos/features/admin/data/app_versions_remote_data_source.dart';

class AppVersionsRemoteDataSourceImpl implements AppVersionsRemoteDataSource {
  AppVersionsRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<AppVersionRow>> fetchVersions() async {
    final res = await _http.get('api/versions');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['versions'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AppVersionRow.fromJson)
        .toList();
  }

  @override
  Future<AppVersionRow> updateVersion(
    String appKey, {
    String? displayName,
    String? currentVersion,
    String? targetVersion,
    String? minSupportedVersion,
    String? downloadUrl,
    String? releaseNotes,
    bool? isMandatory,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (currentVersion != null) body['currentVersion'] = currentVersion;
    if (targetVersion != null) body['targetVersion'] = targetVersion;
    if (minSupportedVersion != null) {
      body['minSupportedVersion'] = minSupportedVersion;
    }
    if (downloadUrl != null) body['downloadUrl'] = downloadUrl;
    if (releaseNotes != null) body['releaseNotes'] = releaseNotes;
    if (isMandatory != null) body['isMandatory'] = isMandatory;

    final res = await _http.patch('api/versions/$appKey', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['version'];
    if (raw is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return AppVersionRow.fromJson(raw);
  }
}
