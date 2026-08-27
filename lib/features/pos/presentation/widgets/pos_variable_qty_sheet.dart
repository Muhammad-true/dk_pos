import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/utils/variable_sale_qty.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_numeric_keypad.dart';
import 'package:dk_pos/shared/shared.dart';

double _dialogWidth(BuildContext context, double max) {
  final w = MediaQuery.sizeOf(context).width - 48;
  return w < max ? w : max;
}

/// Сразу спрашиваем количество (диалог + цифры как при наличных).
Future<void> showPosVariableQtySheet(
  BuildContext context, {
  required PosMenuItem item,
  List<PosCartModifier> modifiers = const [],
  double? unitPrice,
}) {
  return showPosVariableQtyDialog(
    context,
    item: item,
    modifiers: modifiers,
    unitPrice: unitPrice,
  );
}

Future<void> showPosVariableQtyDialog(
  BuildContext context, {
  required PosMenuItem item,
  List<PosCartModifier> modifiers = const [],
  double? unitPrice,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _PosVariableQtyDialog(
      item: item,
      modifiers: modifiers,
      unitPrice: unitPrice,
    ),
  );
}

/// Панель выбора кол-ва (для sheet модификаторов).
class PosVariableQtyPickerPanel extends StatefulWidget {
  const PosVariableQtyPickerPanel({
    super.key,
    required this.item,
    required this.onQtyChanged,
    this.initialQty,
  });

  final PosMenuItem item;
  final ValueChanged<double> onQtyChanged;
  final double? initialQty;

  @override
  State<PosVariableQtyPickerPanel> createState() =>
      _PosVariableQtyPickerPanelState();
}

class _PosVariableQtyPickerPanelState extends State<PosVariableQtyPickerPanel> {
  late final VariableSaleQty _base;
  late final PosIntegerInputController _input;

  @override
  void initState() {
    super.initState();
    _base = VariableSaleQty.fromMenuItem(
      enabled: widget.item.variableSaleQtyEnabled,
      measure: widget.item.saleMeasure,
      defaultQty: widget.item.defaultSaleQty,
    );
    final start = widget.initialQty ?? _base.defaultQty;
    _input = PosIntegerInputController(initial: start.round());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onQtyChanged(_input.valueAsDouble);
    });
  }

  List<int> get _presets {
    if (_base.isGram) return [150, 200, 250, 300];
    return [4, 6, 8, 10, 12];
  }

  void _notify() {
    final v = _input.valueAsDouble;
    if (v > 0) widget.onQtyChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSuffix = _base.isGram ? 'г' : 'шт';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Количество (${_base.isGram ? 'граммы' : 'штуки'})',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Введите количество',
            suffixText: unitSuffix,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Text(
            _input.display,
            textAlign: TextAlign.right,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in _presets)
              ActionChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                padding: EdgeInsets.zero,
                label: Text(
                  _base.isGram ? '$p г' : '$p шт',
                  style: theme.textTheme.labelMedium,
                ),
                onPressed: () => setState(() {
                  _input.setValue(p);
                  _notify();
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        PosNumericKeypad(
          compact: true,
          showDot: false,
          clearLabel: 'Стереть',
          presetLabel: 'Базовое (${_base.defaultQty.round()} $unitSuffix)',
          onDigit: (d) => setState(() {
            _input.appendDigit(d);
            _notify();
          }),
          onBackspace: () => setState(() {
            _input.backspace();
            _notify();
          }),
          onPreset: () => setState(() {
            _input.setValue(_base.defaultQty.round());
            _notify();
          }),
          onClear: () => setState(() {
            _input.clear();
            _notify();
          }),
        ),
      ],
    );
  }
}

class _PosVariableQtyDialog extends StatefulWidget {
  const _PosVariableQtyDialog({
    required this.item,
    this.modifiers = const [],
    this.unitPrice,
  });

  final PosMenuItem item;
  final List<PosCartModifier> modifiers;
  final double? unitPrice;

  @override
  State<_PosVariableQtyDialog> createState() => _PosVariableQtyDialogState();
}

class _PosVariableQtyDialogState extends State<_PosVariableQtyDialog> {
  late final VariableSaleQty _base;
  late final PosIntegerInputController _input;
  late double _actualQty;

  @override
  void initState() {
    super.initState();
    _base = VariableSaleQty.fromMenuItem(
      enabled: widget.item.variableSaleQtyEnabled,
      measure: widget.item.saleMeasure,
      defaultQty: widget.item.defaultSaleQty,
    );
    _actualQty = _base.defaultQty;
    _input = PosIntegerInputController(initial: _base.defaultQty.round());
  }

  double get _modExtra =>
      widget.modifiers.fold<double>(0, (s, m) => s + m.priceDelta);

  double get _catalogBase => widget.item.baseCatalogPrice;

  double get _unitPrice {
    final qty = _actualQty > 0 ? _actualQty : _base.defaultQty;
    final scaled = VariableSaleQty(
      enabled: true,
      measure: _base.measure,
      defaultQty: _base.defaultQty,
      actualQty: qty,
    ).scaledPrice(_catalogBase);
    return widget.unitPrice ?? (scaled + _modExtra);
  }

  void _syncQtyFromInput() {
    final v = _input.valueAsDouble;
    setState(() => _actualQty = v > 0 ? v : _base.defaultQty);
  }

  void _addToCart() {
    final qty = _actualQty > 0 ? _actualQty : _base.defaultQty;
    final sale = VariableSaleQty(
      enabled: true,
      measure: _base.measure,
      defaultQty: _base.defaultQty,
      actualQty: qty,
    );
    context.read<CartBloc>().add(
          CartItemAdded(
            widget.item,
            unitPrice: _unitPrice,
            modifiers: widget.modifiers,
            actualQty: sale.actualQty,
            defaultSaleQty: sale.defaultQty,
            saleMeasure: sale.measure,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitSuffix = _base.isGram ? 'г' : 'шт';
    final canAdd = _input.value > 0 || _actualQty > 0;

    final maxContentH = MediaQuery.sizeOf(context).height * 0.62;

    return AlertDialog(
      backgroundColor: scheme.surfaceContainerLow,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      title: Text(
        widget.item.name,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: _dialogWidth(context, 400),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentH),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Цена за ${_base.defaultQty.round()} $unitSuffix: '
                  '${_catalogBase.toStringAsFixed(_catalogBase == _catalogBase.roundToDouble() ? 0 : 2)} сомони',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Итого: ${_unitPrice.toStringAsFixed(_unitPrice == _unitPrice.roundToDouble() ? 0 : 2)} сомони',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Сколько ${_base.isGram ? 'грамм' : 'штук'}?',
                    suffixText: unitSuffix,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    _input.display,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final p in (_base.isGram
                        ? [150, 200, 250, 300]
                        : [4, 6, 8, 10, 12]))
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        padding: EdgeInsets.zero,
                        label: Text(
                          _base.isGram ? '$p г' : '$p шт',
                          style: theme.textTheme.labelMedium,
                        ),
                        onPressed: () {
                          setState(() {
                            _input.setValue(p);
                            _actualQty = p.toDouble();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                PosNumericKeypad(
                  compact: true,
                  showDot: false,
                  clearLabel: 'Стереть',
                  presetLabel:
                      'Базовое (${_base.defaultQty.round()} $unitSuffix)',
                  onDigit: (d) {
                    setState(() => _input.appendDigit(d));
                    _syncQtyFromInput();
                  },
                  onBackspace: () {
                    setState(() => _input.backspace());
                    _syncQtyFromInput();
                  },
                  onPreset: () {
                    setState(() {
                      _input.setValue(_base.defaultQty.round());
                      _actualQty = _base.defaultQty;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _input.clear();
                      _actualQty = _base.defaultQty;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: canAdd ? _addToCart : null,
          child: const Text('В корзину'),
        ),
      ],
    );
  }
}
