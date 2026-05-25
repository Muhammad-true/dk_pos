import 'package:dk_pos/features/update/silent_update_platform.dart';
import 'package:dk_pos/features/update/silent_update_result.dart';

class SilentUpdatePlatformImpl implements SilentUpdatePlatform {
  @override
  bool supportsTarget(SilentUpdateTarget target) => false;

  @override
  Future<SilentUpdateResult> installDownloadedArtifact({
    required String localPath,
    required SilentUpdateTarget target,
  }) async {
    return const SilentUpdateResult(
      ok: false,
      message: 'Тихая установка недоступна на этой платформе',
    );
  }
}

SilentUpdatePlatform createSilentUpdatePlatform() =>
    SilentUpdatePlatformImpl();
