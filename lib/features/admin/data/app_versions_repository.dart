import 'package:dk_pos/features/admin/data/app_version_row.dart';
import 'package:dk_pos/features/admin/data/app_versions_remote_data_source.dart';

class AppVersionsRepository {
  AppVersionsRepository(this._remote);

  final AppVersionsRemoteDataSource _remote;

  Future<List<AppVersionRow>> fetchVersions() => _remote.fetchVersions();

  Future<AppVersionRow> updateVersion(
    String appKey, {
    String? displayName,
    String? currentVersion,
    String? targetVersion,
    String? minSupportedVersion,
    String? downloadUrl,
    String? releaseNotes,
    bool? isMandatory,
  }) {
    return _remote.updateVersion(
      appKey,
      displayName: displayName,
      currentVersion: currentVersion,
      targetVersion: targetVersion,
      minSupportedVersion: minSupportedVersion,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      isMandatory: isMandatory,
    );
  }
}
