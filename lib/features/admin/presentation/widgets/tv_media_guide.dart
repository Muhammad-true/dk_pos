import 'package:flutter/material.dart';

/// Рекомендации по видео для ТВ (не грузит сервер — только подсказки в админке).
abstract final class TvMediaGuide {
  static const videoSpecsTitle = 'Какое видео подойдёт';

  static const videoSpecsBullets = [
    'Формат: MP4 (H.264), без звука или тихий фон',
    'Разрешение: 1920×1080 (Full HD), можно 1280×720',
    'Длина: 10–30 секунд, зацикленное — идеально',
    'Размер файла: до 15–25 МБ (чтобы ТВ грузило быстро)',
    'Соотношение сторон: 16:9, без чёрных полос по краям',
    'Для «стены» из 3 ТВ — одно и то же видео на все экраны',
  ];

  static const syncTitle = 'Синхрон нескольких ТВ';

  static const syncBullets = [
    'Обычно каждый ТВ крутит страницы сам — сервер не нагружается.',
    '«Вместе 10 мин» — один раз все ТВ переключаются синхронно (акция, открытие).',
    '«Волна 1→2→3» — переход бежит по экранам слева направо.',
    'После 10 минут снова обычный режим — можно настроить разный контент.',
  ];

  static const mixedPagesTitle = 'Меню + очередь + видео на одном ТВ';

  static const mixedPagesBullets = [
    'Создайте экран типа ТВ2 и добавьте страницы в нужном порядке.',
    'Типы: «Только видео/фото», «Лента меню», «Список», «Очередь заказов»…',
    'ТВ4 (очередь) — для простого «приветствие + очередь»; для микса лучше ТВ2.',
  ];

  /// Рекомендуемый patch для `screen.config` при видео-странице.
  static Map<String, dynamic> recommendedVideoScreenPatch({
    int pageHoldSec = 12,
    String syncMode = 'off',
    int cascadeIndex = 0,
    int syncMinutes = 10,
  }) {
    return {
      'tvLayout': {
        'layoutVersion': 1,
        'tv2': {
          'pageHoldMs': (pageHoldSec * 1000).clamp(3000, 120000),
          'pageTransition': 'crossFade',
          'transitionDurationMs': 480,
        },
      },
      'tvSync': buildTvSyncConfig(
        mode: syncMode,
        cascadeIndex: cascadeIndex,
        durationMinutes: syncMinutes,
      ),
    };
  }

  static Map<String, dynamic> buildTvSyncConfig({
    required String mode,
    int cascadeIndex = 0,
    int durationMinutes = 10,
    String groupId = 'wall',
  }) {
    final m = mode.trim().toLowerCase();
    if (m == 'off' || m.isEmpty) {
      return {'enabled': false, 'mode': 'off'};
    }
    return {
      'enabled': true,
      'mode': m == 'wave' ? 'wave' : 'together',
      'group': groupId,
      'groupId': groupId,
      'cascadeIndex': cascadeIndex.clamp(0, 8),
      'cascadeStepMs': 700,
      'durationMinutes': durationMinutes.clamp(1, 60),
    };
  }

  static String readSyncMode(Map<String, dynamic>? config) {
    final raw = config?['tvSync'] ?? config?['tv_sync'];
    if (raw is! Map) return 'off';
    final m = Map<String, dynamic>.from(raw);
    if (m['enabled'] != true && m['enabled'] != 1) return 'off';
    final mode = (m['mode'] ?? m['syncMode'] ?? 'together').toString();
    return mode == 'wave' ? 'wave' : 'together';
  }

  static int readCascadeIndex(Map<String, dynamic>? config) {
    final raw = config?['tvSync'] ?? config?['tv_sync'];
    if (raw is! Map) return 0;
    return int.tryParse(
          (raw['cascadeIndex'] ?? raw['cascade_index'] ?? '0').toString(),
        ) ??
        0;
  }
}

class TvMediaHintCard extends StatelessWidget {
  const TvMediaHintCard({
    super.key,
    this.compact = false,
    this.showSync = true,
    this.showMixed = false,
  });

  final bool compact;
  final bool showSync;
  final bool showMixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates_outlined,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  TvMediaGuide.videoSpecsTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...TvMediaGuide.videoSpecsBullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $b', style: theme.textTheme.bodySmall),
              ),
            ),
            if (!compact && showSync) ...[
              const SizedBox(height: 12),
              Text(
                TvMediaGuide.syncTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...TvMediaGuide.syncBullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $b', style: theme.textTheme.bodySmall),
                ),
              ),
            ],
            if (!compact && showMixed) ...[
              const SizedBox(height: 12),
              Text(
                TvMediaGuide.mixedPagesTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...TvMediaGuide.mixedPagesBullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $b', style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
