import 'package:dk_pos/features/admin/data/app_version_row.dart';

abstract class AppVersionsRemoteDataSource {
  Future<List<AppVersionRow>> fetchVersions();

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
