import 'package:dk_digitial_menu/data/display_image_cache.dart';
import 'package:dk_digitial_menu/data/tv2_video_cache.dart';
import 'package:flutter/painting.dart';

import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';

/// Сброс локальных кешей POS (картинки меню, видео ТВ, декодированные изображения Flutter),
/// плюс закрытие окна клиента и удаление файла синхронизации с ним.
///
/// Вызывать при выходе из сессии и при смене адреса API, чтобы не тянуть старые URL/байты.
Future<void> clearPosLocalCaches() async {
  try {
    await CustomerDisplayWindowService.instance.close();
  } catch (_) {}
  try {
    await CustomerDisplayWindowService.instance.clearSyncFile();
  } catch (_) {}
  try {
    DisplayImageCache.clear();
  } catch (_) {}
  try {
    await Tv2VideoCache.instance.clearAll();
  } catch (_) {}
  try {
    PaintingBinding.instance.imageCache.clear();
  } catch (_) {}
}
