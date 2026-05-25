import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'package:dk_pos/core/config/app_config.dart';

/// Звук «новый заказ на кухне»: кастом из админки или встроенный WAV.
class KitchenOrderAlert {
  KitchenOrderAlert._();

  static const String assetPath = 'audio/kitchen_new_order.wav';

  static Future<void> play(
    AudioPlayer player, {
    String? customUploadPath,
  }) async {
    try {
      await player.stop();
      final custom = (customUploadPath ?? '').trim();
      if (custom.isNotEmpty) {
        final url = AppConfig.mediaUrl(custom);
        if (url.isNotEmpty) {
          await player.play(UrlSource(url));
          return;
        }
      }
      await player.play(AssetSource(assetPath));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
