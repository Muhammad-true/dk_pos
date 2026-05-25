import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/shared/shared.dart';

/// Настройка блюда перед добавлением в корзину (модификаторы из global sync).
Future<void> showPosModifierSheet(
  BuildContext context, {
  required PosMenuItem item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _PosModifierSheetBody(item: item),
  );
}

class _PosModifierSheetBody extends StatefulWidget {
  const _PosModifierSheetBody({required this.item});

  final PosMenuItem item;

  @override
  State<_PosModifierSheetBody> createState() => _PosModifierSheetBodyState();
}

class _PosModifierSheetBodyState extends State<_PosModifierSheetBody> {
  final Set<int> _selected = {};

  List<PosCartModifier> get _selectedModifiers {
    final out = <PosCartModifier>[];
    for (final g in widget.item.modifierGroups) {
      for (final o in g.options) {
        if (_selected.contains(o.id)) {
          out.add(PosCartModifier(
            optionId: o.id,
            name: o.name,
            priceDelta: o.priceDelta,
          ));
        }
      }
    }
    return out;
  }

  double get _unitPrice {
    final extra = _selectedModifiers.fold<double>(0, (s, m) => s + m.priceDelta);
    return widget.item.baseCatalogPrice + extra;
  }

  void _toggle(PosModifierGroup group, PosModifierOption option) {
    setState(() {
      final oid = option.id;
      final sameGroup = group.options.map((o) => o.id).toList();
      if (group.kind == 'remove') {
        if (_selected.contains(oid)) {
          _selected.remove(oid);
        } else {
          for (final id in sameGroup) {
            _selected.remove(id);
          }
          if (sameGroup.where(_selected.contains).length < group.maxSelect) {
            _selected.add(oid);
          }
        }
      } else {
        if (_selected.contains(oid)) {
          _selected.remove(oid);
        } else if (sameGroup.where(_selected.contains).length < group.maxSelect) {
          _selected.add(oid);
        }
      }
    });
  }

  void _addToCart() {
    final mods = _selectedModifiers;
    context.read<CartBloc>().add(
          CartItemAdded(widget.item, unitPrice: _unitPrice, modifiers: mods),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${_unitPrice.toStringAsFixed(_unitPrice == _unitPrice.roundToDouble() ? 0 : 2)} сом.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in widget.item.modifierGroups) ...[
                    Text(
                      '${g.name} (${g.kind == 'remove' ? 'убрать' : 'добавить'})',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in g.options)
                          FilterChip(
                            label: Text(
                              o.priceDelta > 0
                                  ? '${o.name} +${o.priceDelta.toStringAsFixed(0)}'
                                  : o.name,
                            ),
                            selected: _selected.contains(o.id),
                            onSelected: (_) => _toggle(g, o),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: _addToCart,
            child: const Text('В корзину'),
          ),
        ],
      ),
    );
  }
}
