import 'package:flutter/material.dart';
import 'package:dk_digitial_menu/models/tv_layout_config.dart';

/// Палитра по умолчанию для конструкторов ТВ и очереди.
const List<String> kAdminColorPresets = [
  '#FFFFFF',
  '#F5F5F5',
  '#E0E0E0',
  '#9E9E9E',
  '#424242',
  '#1A1A1A',
  '#000000',
  '#E4002B',
  '#C41E3A',
  '#E53935',
  '#FF5252',
  '#FF6F00',
  '#EF6C00',
  '#FFD54F',
  '#FFC107',
  '#2E7D32',
  '#43A047',
  '#00897B',
  '#1565C0',
  '#1976D2',
  '#7B1FA2',
  '#8E24AA',
  '#5D4037',
  '#795548',
  '#B8F5D9',
  '#24B47E',
  '#0A3D24',
  '#111318',
  '#FFD447',
  '#FF8A65',
  '#81D4FA',
  '#CE93D8',
];

String normalizeAdminHexColor(String? raw, {String fallback = '#FFFFFF'}) {
  var x = (raw ?? '').trim().toUpperCase();
  if (x.isEmpty) return fallback;
  if (!x.startsWith('#')) x = '#$x';
  if (RegExp(r'^#[0-9A-F]{6}$').hasMatch(x)) return x;
  return fallback;
}

Color adminHexToColor(String? hex, {Color fallback = Colors.grey}) {
  return parseTvLayoutHexColor(normalizeAdminHexColor(hex)) ?? fallback;
}

String colorToAdminHex(Color color) {
  final r = (color.r * 255.0).round().clamp(0, 255);
  final g = (color.g * 255.0).round().clamp(0, 255);
  final b = (color.b * 255.0).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Выбор цвета: превью, палитра и диалог с ползунками (без ввода hex вручную).
class AdminColorPickerField extends StatelessWidget {
  const AdminColorPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.palette = kAdminColorPresets,
    this.allowClear = false,
    this.onClear,
    this.compact = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> palette;
  final bool allowClear;
  final VoidCallback? onClear;
  final bool compact;

  Future<void> _openPicker(BuildContext context) async {
    final initial = value.trim().isEmpty
        ? Colors.white
        : adminHexToColor(normalizeAdminHexColor(value));
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _AdminColorPickerDialog(
        initial: initial,
        palette: palette,
      ),
    );
    if (picked != null) onChanged(colorToAdminHex(picked));
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.trim().isEmpty;
    final hex = isEmpty ? null : normalizeAdminHexColor(value);
    final color = isEmpty ? const Color(0xFFE2E8F0) : adminHexToColor(hex!);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.palette_outlined, color: Colors.white70, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEmpty ? 'Из темы' : hex!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openPicker(context),
                          icon: const Icon(Icons.colorize_rounded, size: 18),
                          label: const Text('Выбрать цвет'),
                        ),
                        if (allowClear && onClear != null)
                          TextButton(
                            onPressed: onClear,
                            child: const Text('Сбросить'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in palette)
                  _PresetChip(
                    hex: preset,
                    selected: !isEmpty && hex == normalizeAdminHexColor(preset),
                    onTap: () => onChanged(normalizeAdminHexColor(preset)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hex,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: adminHexToColor(hex),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFFE4002B) : Colors.black26,
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminColorPickerDialog extends StatefulWidget {
  const _AdminColorPickerDialog({
    required this.initial,
    required this.palette,
  });

  final Color initial;
  final List<String> palette;

  @override
  State<_AdminColorPickerDialog> createState() => _AdminColorPickerDialogState();
}

class _AdminColorPickerDialogState extends State<_AdminColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final hex = colorToAdminHex(_color);
    return AlertDialog(
      title: const Text('Выбор цвета'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Text(
                hex,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _color.computeLuminance() > 0.55 ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Оттенок', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _hsv.hue,
              min: 0,
              max: 360,
              divisions: 360,
              label: _hsv.hue.round().toString(),
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            Text('Насыщенность', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _hsv.saturation,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            Text('Яркость', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _hsv.value,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
            const SizedBox(height: 8),
            Text('Быстрый выбор', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in widget.palette)
                  _PresetChip(
                    hex: preset,
                    selected: hex == normalizeAdminHexColor(preset),
                    onTap: () => setState(() {
                      _hsv = HSVColor.fromColor(adminHexToColor(preset));
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
