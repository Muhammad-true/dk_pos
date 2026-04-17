class AppVersionRow {
  const AppVersionRow({
    required this.id,
    required this.appKey,
    required this.displayName,
    required this.currentVersion,
    required this.targetVersion,
    required this.minSupportedVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
    required this.updatedAt,
  });

  final int id;
  final String appKey;
  final String displayName;
  final String? currentVersion;
  final String? targetVersion;
  final String? minSupportedVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool isMandatory;
  final DateTime? updatedAt;

  factory AppVersionRow.fromJson(Map<String, dynamic> json) {
    return AppVersionRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      appKey: json['appKey']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      currentVersion: json['currentVersion']?.toString(),
      targetVersion: json['targetVersion']?.toString(),
      minSupportedVersion: json['minSupportedVersion']?.toString(),
      downloadUrl: json['downloadUrl']?.toString(),
      releaseNotes: json['releaseNotes']?.toString(),
      isMandatory: json['isMandatory'] == true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  AppVersionRow copyWith({
    String? displayName,
    String? currentVersion,
    String? targetVersion,
    String? minSupportedVersion,
    String? downloadUrl,
    String? releaseNotes,
    bool? isMandatory,
  }) {
    return AppVersionRow(
      id: id,
      appKey: appKey,
      displayName: displayName ?? this.displayName,
      currentVersion: currentVersion ?? this.currentVersion,
      targetVersion: targetVersion ?? this.targetVersion,
      minSupportedVersion: minSupportedVersion ?? this.minSupportedVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      isMandatory: isMandatory ?? this.isMandatory,
      updatedAt: updatedAt,
    );
  }
}
