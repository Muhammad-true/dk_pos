import 'package:flutter/material.dart';

/// Целое число с цифровой клавиатуры (кол-во шт / г).
class PosIntegerInputController {
  PosIntegerInputController({int initial = 0}) {
    if (initial > 0) raw = initial.toString();
  }

  String raw = '';

  int get value {
    final n = int.tryParse(raw);
    return n != null && n > 0 ? n : 0;
  }

  double get valueAsDouble => value.toDouble();

  void appendDigit(String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
    if (raw == '0') {
      raw = digit;
    } else {
      raw += digit;
    }
  }

  void backspace() {
    if (raw.isEmpty) return;
    raw = raw.substring(0, raw.length - 1);
  }

  void clear() => raw = '';

  void setValue(int amount) {
    raw = amount > 0 ? amount.toString() : '';
  }

  String get display => raw.isEmpty ? '0' : raw;
}

/// Цифровая клавиатура как на экране «Наличные».
class PosNumericKeypad extends StatelessWidget {
  const PosNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDot,
    this.onPreset,
    this.onClear,
    this.presetLabel = 'Ровно',
    this.showDot = true,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onDot;
  final VoidCallback? onPreset;
  final VoidCallback? onClear;
  final String presetLabel;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digitStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
              FilledButton.tonal(
                onPressed: () => onDigit(d),
                child: Text(d, style: digitStyle),
              ),
            if (showDot && onDot != null)
              FilledButton.tonal(
                onPressed: onDot,
                child: Text('.', style: digitStyle),
              )
            else if (onPreset != null)
              FilledButton.tonal(
                onPressed: onPreset,
                child: Text(
                  presetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              const SizedBox.shrink(),
            FilledButton.tonal(
              onPressed: () => onDigit('0'),
              child: Text('0', style: digitStyle),
            ),
            FilledButton.tonal(
              onPressed: onBackspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        if ((onPreset != null && showDot) || onClear != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (onPreset != null && showDot)
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onPreset,
                    child: Text(presetLabel),
                  ),
                ),
              if (onPreset != null && showDot && onClear != null) const SizedBox(width: 8),
              if (onClear != null)
                Expanded(
                  child: TextButton(
                    onPressed: onClear,
                    child: const Text('Очистить'),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
