/// Готовое к установке обновление (после фонового скачивания).
class PendingAppUpdate {
  const PendingAppUpdate({
    required this.appKey,
    required this.displayName,
    required this.targetVersion,
    required this.downloadUrl,
    required this.localPath,
    this.isMandatory = false,
  });

  final String appKey;
  final String displayName;
  final String targetVersion;
  final String downloadUrl;
  final String localPath;
  final bool isMandatory;

  int get priority => switch (appKey.trim().toLowerCase()) {
        'server' => 0,
        'pos' => 1,
        'pos_android' => 2,
        _ => 9,
      };
}
