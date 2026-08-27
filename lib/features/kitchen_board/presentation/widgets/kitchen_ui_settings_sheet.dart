import 'package:flutter/material.dart';

import 'package:dk_pos/features/kitchen_board/presentation/kitchen_ui_preferences.dart';

/// Нижняя панель: размер кнопок, раскладка и режим «дозаказ» на экране кухни.
Future<KitchenScreenSettings?> showKitchenUiSettingsSheet(
  BuildContext context, {
  required KitchenScreenSettings initial,
}) {
  return showModalBottomSheet<KitchenScreenSettings>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _KitchenUiSettingsSheet(initial: initial),
  );
}

class _KitchenUiSettingsSheet extends StatefulWidget {
  const _KitchenUiSettingsSheet({required this.initial});

  final KitchenScreenSettings initial;

  @override
  State<_KitchenUiSettingsSheet> createState() => _KitchenUiSettingsSheetState();
}

class _KitchenUiSettingsSheetState extends State<_KitchenUiSettingsSheet> {
  late double _buttonScale;
  late double _buttonTextScale;
  late double _itemTextScale;
  late int _orderColumns;
  late KitchenFollowUpSettings _followUp;

  @override
  void initState() {
    super.initState();
    _buttonScale = widget.initial.uiScale.buttonScale;
    _buttonTextScale = widget.initial.uiScale.buttonTextScale;
    _itemTextScale = widget.initial.uiScale.itemTextScale;
    _orderColumns = widget.initial.uiScale.orderColumns;
    _followUp = widget.initial.followUp;
  }

  KitchenUiScale get _uiDraft => KitchenUiScale(
        buttonScale: _buttonScale,
        buttonTextScale: _buttonTextScale,
        itemTextScale: _itemTextScale,
        orderColumns: _orderColumns,
      ).clamped();

  void _applyPreset(KitchenUiScale preset) {
    setState(() {
      _buttonScale = preset.buttonScale;
      _buttonTextScale = preset.buttonTextScale;
      _itemTextScale = preset.itemTextScale;
      _orderColumns = preset.orderColumns;
    });
  }

  Future<void> _save() async {
    final settings = KitchenScreenSettings(
      uiScale: _uiDraft,
      followUp: _followUp,
    );
    await KitchenScreenPreferences.save(settings);
    if (!mounted) return;
    Navigator.of(context).pop(settings);
  }

  void _setFollowUp(KitchenFollowUpSettings next) {
    setState(() => _followUp = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final followUpOn = _followUp.enabled;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Настройки экрана кухни',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Сохраняются на этом планшете. Раскладка, размер кнопок и поведение при дозаказе.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      'Раскладка заказов',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.view_agenda_outlined),
                          label: Text('Одна колонка'),
                        ),
                        ButtonSegment(
                          value: 2,
                          icon: Icon(Icons.view_column_outlined),
                          label: Text('Две колонки'),
                        ),
                      ],
                      selected: {_orderColumns.clamp(1, 2)},
                      onSelectionChanged: (values) {
                        setState(() => _orderColumns = values.first);
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _applyPreset(KitchenUiScale.standard),
                          child: const Text('Стандарт'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyPreset(KitchenUiScale.large),
                          child: const Text('Крупный'),
                        ),
                        OutlinedButton(
                          onPressed: () => _applyPreset(KitchenUiScale.tablet),
                          child: const Text('Планшет'),
                        ),
                        TextButton(
                          onPressed: () => _applyPreset(KitchenUiScale.standard),
                          child: const Text('Сбросить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ScaleSlider(
                      label: 'Высота кнопок',
                      value: _buttonScale,
                      onChanged: (v) => setState(() => _buttonScale = v),
                    ),
                    _ScaleSlider(
                      label: 'Текст на кнопках',
                      value: _buttonTextScale,
                      onChanged: (v) => setState(() => _buttonTextScale = v),
                    ),
                    _ScaleSlider(
                      label: 'Названия блюд в заказе',
                      value: _itemTextScale,
                      onChanged: (v) => setState(() => _itemTextScale = v),
                    ),
                    const SizedBox(height: 12),
                    _PreviewButtons(scale: _uiDraft),
                    const SizedBox(height: 20),
                    Divider(color: scheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Дозаказ',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Когда к счёту добавляют позиции после того, как часть уже готова.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Режим «дозаказ»'),
                      subtitle: const Text(
                        'Отличать новые позиции от уже готовых, чтобы не готовить весь заказ заново',
                      ),
                      value: followUpOn,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(enabled: v)),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Подсветка карточки',
                      subtitle: 'Оранжевая рамка, бейдж и плашка «готовить только новое»',
                      value: _followUp.highlightCard,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(highlightCard: v)),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Метка «ГОТОВИТЬ» на новых позициях',
                      value: _followUp.highlightNewLines,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(highlightNewLines: v)),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Сворачивать «Уже готово»',
                      subtitle: 'Готовые позиции в свёрнутом блоке «не готовить»',
                      value: _followUp.collapseReadyItems,
                      onChanged: (v) {
                        _setFollowUp(
                          _followUp.copyWith(
                            collapseReadyItems: v,
                            hideReadyItems: v ? _followUp.hideReadyItems : false,
                          ),
                        );
                      },
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn && _followUp.collapseReadyItems,
                      title: 'Скрывать готовые позиции',
                      subtitle: 'Показывать только то, что нужно приготовить',
                      value: _followUp.hideReadyItems,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(hideReadyItems: v)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Оповещения при дозаказе',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Звук и вибрация',
                      value: _followUp.notifySound,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(notifySound: v)),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Озвучка с названиями блюд',
                      subtitle: '«Приготовить только: …» (если TTS включён в админке)',
                      value: _followUp.notifyTts,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(notifyTts: v)),
                    ),
                    _FollowUpSwitchTile(
                      enabled: followUpOn,
                      title: 'Сообщение внизу экрана',
                      value: _followUp.notifySnack,
                      onChanged: (v) => _setFollowUp(_followUp.copyWith(notifySnack: v)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _setFollowUp(KitchenFollowUpSettings.defaults),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Сбросить настройки дозаказа'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Применить'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowUpSwitchTile extends StatelessWidget {
  const _FollowUpSwitchTile({
    required this.enabled,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final bool enabled;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: enabled && value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  const _ScaleSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.75, 1.6) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '$pct%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0.75, 1.6),
          min: 0.75,
          max: 1.6,
          divisions: 17,
          label: '$pct%',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PreviewButtons extends StatelessWidget {
  const _PreviewButtons({required this.scale});

  final KitchenUiScale scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).shortestSide < 600;
    final minHeight = (compact ? 58.0 : 66.0) * scale.buttonScale;
    final fontSize = (compact ? 14.0 : 15.0) * scale.buttonTextScale;
    final iconSize = 16.0 * scale.buttonTextScale;
    final vPadding = (compact ? 8.0 : 10.0) * scale.buttonScale;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Пример',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Кнопки «Принять» и «Готова/выдать» — на весь заказ (все позиции этой кухни).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '2× Донер классический',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18 * scale.itemTextScale,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PreviewKitchenActionButton(
                    minHeight: minHeight,
                    fontSize: fontSize,
                    iconSize: iconSize,
                    verticalPadding: vPadding,
                    compact: compact,
                    icon: Icons.pan_tool_alt_rounded,
                    actorLabel: 'Повар',
                    actionLabel: 'Принять',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PreviewKitchenActionButton(
                    minHeight: minHeight,
                    fontSize: fontSize,
                    iconSize: iconSize,
                    verticalPadding: vPadding,
                    compact: compact,
                    icon: Icons.check_circle_rounded,
                    actorLabel: 'Повар',
                    actionLabel: 'Готова/выдать',
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewKitchenActionButton extends StatelessWidget {
  const _PreviewKitchenActionButton({
    required this.minHeight,
    required this.fontSize,
    required this.iconSize,
    required this.verticalPadding,
    required this.compact,
    required this.icon,
    required this.actorLabel,
    required this.actionLabel,
    this.color,
  });

  final double minHeight;
  final double fontSize;
  final double iconSize;
  final double verticalPadding;
  final bool compact;
  final IconData icon;
  final String actorLabel;
  final String actionLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color;
    final onColor = bg == null
        ? theme.colorScheme.onPrimary
        : (bg.computeLuminance() > 0.55 ? Colors.black : Colors.white);
    return FilledButton(
      onPressed: () {},
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: bg == null ? null : onColor,
        minimumSize: Size(0, minHeight),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: verticalPadding),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    height: 1.15,
                  ),
                ),
                Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize * 0.93,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
