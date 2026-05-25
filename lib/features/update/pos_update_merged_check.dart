import 'package:package_info_plus/package_info_plus.dart';

import 'package:dk_pos/app/app_update_info.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/update/global_release_check.dart';

/// Та же логика, что при старте кассы: `api/versions/report` + глобальный `releases/check`.
Future<AppUpdateInfo?> fetchMergedPosUpdateInfo(HttpClient http) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final versionText = '${info.version}+${info.buildNumber}';
    AppUpdateInfo? local;
    try {
      final res = await http.post(
        'api/versions/report',
        body: {
          'appKey': 'pos',
          'displayName': 'dk_pos',
          'currentVersion': versionText,
        },
      );
      final body = res.body;
      if (body is Map<String, dynamic>) {
        final raw = body['version'];
        if (raw is Map<String, dynamic>) {
          local = AppUpdateInfo.fromJson(raw, installedVersion: versionText);
        }
      }
    } catch (_) {}
    AppUpdateInfo? global;
    try {
      global = await fetchGlobalReleaseUpdate(versionText);
    } catch (_) {}
    return AppUpdateInfo.mergeLocalAndGlobal(local, global);
  } catch (_) {
    return null;
  }
}
