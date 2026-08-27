import 'package:flutter/material.dart';

import 'package:dk_pos/shared/shared.dart';

import 'pos_product_image.dart';
import 'pos_size_group.dart';

/// Модалка выбора размера (25/30/35) с ценой.
Future<PosMenuItem?> showPosSizeGroupDialog(
  BuildContext context, {
  required PosCatalogTile tile,
}) {
  if (!tile.isGroup) return Future.value(tile.representative);

  return showDialog<PosMenuItem>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _PosSizeGroupDialog(tile: tile),
  );
}

class _PosSizeGroupDialog extends StatefulWidget {
  const _PosSizeGroupDialog({required this.tile});

  final PosCatalogTile tile;

  @override
  State<_PosSizeGroupDialog> createState() => _PosSizeGroupDialogState();
}

class _PosSizeGroupDialogState extends State<_PosSizeGroupDialog> {
  late PosMenuItem _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.tile.sizes.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tile = widget.tile;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tile.baseName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: PosProductImage(
                imagePath: _selected.imagePath ?? tile.representative.imagePath,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Размер',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in tile.sizes)
                  ChoiceChip(
                    label: Text(
                      '${parsePosSizeTail(s.name)?.sizeLabel ?? s.name} · ${s.priceText}',
                    ),
                    selected: s.id == _selected.id,
                    onSelected: (_) => setState(() => _selected = s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _selected.priceText,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
