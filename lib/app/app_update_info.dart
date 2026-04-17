class AppUpdateInfo {
  const AppUpdateInfo({
    required this.displayName,
    required this.installedVersion,
    required this.targetVersion,
    required this.minSupportedVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  final String displayName;
  final String installedVersion;
  final String? targetVersion;
  final String? minSupportedVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool isMandatory;

  bool get hasUpdate => compareVersions(installedVersion, targetVersion) < 0;

  bool get belowMinSupported =>
      compareVersions(installedVersion, minSupportedVersion) < 0;

  bool get requiresBlock => belowMinSupported || (isMandatory && hasUpdate);

  bool get shouldNotify => hasUpdate;

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required String installedVersion,
  }) {
    return AppUpdateInfo(
      displayName: json['displayName']?.toString() ?? 'Приложение',
      installedVersion: installedVersion,
      targetVersion: json['targetVersion']?.toString(),
      minSupportedVersion: json['minSupportedVersion']?.toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      releaseNotes: json['releaseNotes']?.toString(),
      isMandatory: json['isMandatory'] == true,
    );
  }
}

int compareVersions(String? a, String? b) {
  if (b == null || b.trim().isEmpty) return 0;
  final left = RegExp(r'\d+')
      .allMatches((a ?? '').trim())
      .map((m) => int.tryParse(m.group(0)!) ?? 0)
      .toList();
  final right = RegExp(r'\d+')
      .allMatches(b.trim())
      .map((m) => int.tryParse(m.group(0)!) ?? 0)
      .toList();
  final len = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < len; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l < r ? -1 : 1;
  }
  return 0;
}
