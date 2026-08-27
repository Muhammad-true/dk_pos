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

/// Ввод суммы в [TextEditingController] без системной клавиатуры (планшет / Windows).
void posAppendMoneyDigit(TextEditingController ctrl, String digit) {
  if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
  final t = ctrl.text;
  if (t == '0') {
    ctrl.text = digit;
  } else {
    ctrl.text = '$t$digit';
  }
  ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
}

void posAppendMoneyDot(TextEditingController ctrl) {
  final t = ctrl.text;
  if (t.contains('.') || t.contains(',')) return;
  ctrl.text = t.isEmpty ? '0.' : '$t.';
  ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
}

void posMoneyBackspace(TextEditingController ctrl) {
  final t = ctrl.text;
  if (t.isEmpty) return;
  ctrl.text = t.substring(0, t.length - 1);
  ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
}

void posMoneyClear(TextEditingController ctrl) {
  ctrl.clear();
}

void posMoneySetAmount(TextEditingController ctrl, double amount) {
  if (!amount.isFinite || amount < 0) {
    ctrl.clear();
    return;
  }
  final cents = (amount * 100).round();
  ctrl.text = cents % 100 == 0
      ? '${cents ~/ 100}'
      : (cents / 100.0).toStringAsFixed(2);
  ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
}

/// Цифровая клавиатура для кассы / планшета (без системной клавиатуры Windows).
class PosNumericKeypad extends StatelessWidget {
  const PosNumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDot,
    this.onPreset,
    this.onClear,
    this.presetLabel = 'Ровно',
    this.clearLabel = 'C',
    this.showDot = true,
    /// Крупнее кнопки — удобнее пальцем на планшете.
    this.compact = false,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onDot;
  final VoidCallback? onPreset;
  final VoidCallback? onClear;
  final String presetLabel;
  /// Подпись кнопки очистки (`C` / `Стереть`).
  final String clearLabel;
  final bool showDot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final digitStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 17 : 22,
    );
    final aspect = compact ? 2.05 : 1.45;
    final gap = compact ? 5.0 : 8.0;
    final keyPadV = compact ? 4.0 : 10.0;
    final emphasizePadV = compact ? 8.0 : 14.0;

    Widget keyBtn({
      required Widget child,
      required VoidCallback? onPressed,
      bool emphasize = false,
    }) {
      if (emphasize) {
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: emphasizePadV),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          ),
          child: child,
        );
      }
      return FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: keyPadV),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        ),
        child: child,
      );
    }

    final clearInGrid = onClear != null && (!showDot || onDot == null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // «Ровно» сверху — на планшете нижний ряд часто обрезается и не ловит тап.
        if (onPreset != null) ...[
          if (compact && onClear != null && showDot && onDot != null)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: keyBtn(
                    emphasize: true,
                    onPressed: onPreset,
                    child: Text(
                      presetLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: keyBtn(
                    onPressed: onClear,
                    child: Text(
                      clearLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: clearLabel.length > 1 ? 12 : null,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            keyBtn(
              emphasize: true,
              onPressed: onPreset,
              child: Text(
                presetLabel,
                style: (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          SizedBox(height: gap),
        ],
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: aspect,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
              keyBtn(
                onPressed: () => onDigit(d),
                child: Text(d, style: digitStyle),
              ),
            if (showDot && onDot != null)
              keyBtn(
                onPressed: onDot,
                child: Text('.', style: digitStyle),
              )
            else if (clearInGrid)
              keyBtn(
                onPressed: onClear,
                child: Text(
                  clearLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact
                        ? (clearLabel.length > 1 ? 12 : 16)
                        : null,
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            keyBtn(
              onPressed: () => onDigit('0'),
              child: Text('0', style: digitStyle),
            ),
            keyBtn(
              onPressed: onBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: compact ? 20 : 24,
              ),
            ),
          ],
        ),
        // Некомпактный режим: «Очистить» отдельной строкой под сеткой.
        if (!compact && onClear != null && showDot && onDot != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            child: const Text('Очистить'),
          ),
        ],
      ],
    );
  }
}

/// Поле суммы + [PosNumericKeypad] (для одного поля в диалоге).
class PosMoneyKeypadInput extends StatelessWidget {
  const PosMoneyKeypadInput({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.presetAmount,
    this.presetLabel = 'Ровно',
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final double? presetAmount;
  final String presetLabel;
  final VoidCallback? onChanged;
  final bool autofocus;

  void _notify() => onChanged?.call();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autofocus: autofocus,
          readOnly: true,
          showCursor: true,
          keyboardType: TextInputType.none,
          onTap: () {},
          onChanged: (_) => _notify(),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText ?? '0',
            border: const OutlineInputBorder(),
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 10),
        PosNumericKeypad(
          onDigit: (d) {
            posAppendMoneyDigit(controller, d);
            _notify();
          },
          onDot: () {
            posAppendMoneyDot(controller);
            _notify();
          },
          onBackspace: () {
            posMoneyBackspace(controller);
            _notify();
          },
          onClear: () {
            posMoneyClear(controller);
            _notify();
          },
          onPreset: presetAmount != null
              ? () {
                  posMoneySetAmount(controller, presetAmount!);
                  _notify();
                }
              : null,
          presetLabel: presetLabel,
        ),
      ],
    );
  }
}
