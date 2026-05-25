import 'package:dk_pos/features/update/silent_update_result.dart';

/// Платформенный запуск скачанного установщика.
abstract class SilentUpdatePlatform {
  Future<SilentUpdateResult> installDownloadedArtifact({
    required String localPath,
    required SilentUpdateTarget target,
  });

  bool supportsTarget(SilentUpdateTarget target);
}
