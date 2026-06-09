import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/kitchen_board/audio/kitchen_order_alert.dart';

/// Звук «новый онлайн-заказ на кассе»: кастом из админки или двойной сигнал (отличается от счёта/готовности).
class WebsiteOrderAlert {
  WebsiteOrderAlert._();

  static Future<void> play(
    AudioPlayer player, {
    String? customUploadPath,
  }) async {
    final custom = (customUploadPath ?? '').trim();
    if (custom.isNotEmpty) {
      final url = AppConfig.mediaUrl(custom);
      if (url.isNotEmpty) {
        try {
          await player.stop();
          await player.play(UrlSource(url));
          return;
        } catch (_) {
          // fallback ниже
        }
      }
    }

    try {
      await player.stop();
      await KitchenOrderAlert.play(player);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await player.stop();
      await KitchenOrderAlert.play(player);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
        await Future<void>.delayed(const Duration(milliseconds: 220));
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
