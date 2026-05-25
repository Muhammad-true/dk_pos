import 'package:flutter/material.dart';

import 'package:dk_pos/features/kitchen_board/presentation/kitchen_ui_preferences.dart';

/// Нижняя панель: размер кнопок и текста на экране кухни.
Future<KitchenUiScale?> showKitchenUiSettingsSheet(
  BuildContext context, {
  required KitchenUiScale initial,
}) {
  return showModalBottomSheet<KitchenUiScale>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _KitchenUiSettingsSheet(initial: initial),
  );
}

class _KitchenUiSettingsSheet extends StatefulWidget {
  const _KitchenUiSettingsSheet({required this.initial});

  final KitchenUiScale initial;

  @override
  State<_KitchenUiSettingsSheet> createState() => _KitchenUiSettingsSheetState();
}

class _KitchenUiSettingsSheetState extends State<_KitchenUiSettingsSheet> {
  late double _buttonScale;
  late double _buttonTextScale;
  late double _itemTextScale;

  @override
  void initState() {
    super.initState();
    _buttonScale = widget.initial.buttonScale;
    _buttonTextScale = widget.initial.buttonTextScale;
    _itemTextScale = widget.initial.itemTextScale;
  }

  KitchenUiScale get _draft => KitchenUiScale(
        buttonScale: _buttonScale,
        buttonTextScale: _buttonTextScale,
        itemTextScale: _itemTextScale,
      ).clamped();

  void _applyPreset(KitchenUiScale preset) {
    setState(() {
      _buttonScale = preset.buttonScale;
      _buttonTextScale = preset.buttonTextScale;
      _itemTextScale = preset.itemTextScale;
    });
  }

  Future<void> _save() async {
    final scale = _draft;
    await KitchenUiPreferences.save(scale);
    if (!mounted) return;
    Navigator.of(context).pop(scale);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Размер кнопок и текста',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Настройки сохраняются на этом планшете. Подберите удобный размер для «Принять» и «Готово».',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
          _PreviewButtons(scale: _draft),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Применить'),
          ),
        ],
      ),
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
    final baseMinHeight = compact ? 46.0 : 52.0;
    final minHeight = baseMinHeight * scale.buttonScale;
    final fontSize = (compact ? 14.0 : 15.0) * scale.buttonTextScale;
    final iconSize = 16.0 * scale.buttonTextScale;

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
                  child: SizedBox(
                    height: minHeight,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.pan_tool_alt_rounded, size: iconSize),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, minHeight),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8 * scale.buttonScale,
                        ),
                      ),
                      label: Text(
                        'Повар · Принять',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: minHeight,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: Icon(Icons.check_circle_rounded, size: iconSize),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        minimumSize: Size(0, minHeight),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8 * scale.buttonScale,
                        ),
                      ),
                      label: Text(
                        'Повар · Готово',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
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
