import 'package:dk_pos/features/admin/data/app_version_row.dart';

abstract class AppVersionsRemoteDataSource {
  Future<List<AppVersionRow>> fetchVersions();

  /// `POST /api/versions/sync-from-global` — заполняет target/downloadUrl для pos и server с dk_global.
  Future<Map<String, dynamic>> syncVersionsFromGlobal();

  Future<Map<String, dynamic>> silentInstall(String appKey, {String? downloadUrl});

  Future<AppVersionRow> updateVersion(
    String appKey, {
    String? displayName,
    String? currentVersion,
    String? targetVersion,
    String? minSupportedVersion,
    String? downloadUrl,
    String? releaseNotes,
    bool? isMandatory,
  });
}
