import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_catalog_grid/pos_catalog_grid_cubit.dart';
import 'package:dk_pos/app/pos_catalog_grid/pos_catalog_grid_settings.dart';
import 'package:dk_pos/core/layout/window_layout.dart';

/// Конструктор сетки каталога: размер карточки, авто/ручные колонки, предпросмотр.
class PosCatalogGridSettingsEditor extends StatelessWidget {
  const PosCatalogGridSettingsEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCatalogGridCubit, PosCatalogGridSettings>(
      builder: (context, grid) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final preview = _CatalogGridPreview.compute(context, grid);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Сетка товаров',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Подберите размер карточек и число колонок. '
              'В режиме «Авто» колонки считаются по ширине экрана.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Размер карточки',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PosCatalogCardSize.values.map((size) {
                return ChoiceChip(
                  label: Text(size.label),
                  selected: grid.cardSize == size,
                  onSelected: (_) => context
                      .read<PosCatalogGridCubit>()
                      .setCardSize(size),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Колонки',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Авто')),
                ButtonSegment(value: false, label: Text('Вручную')),
              ],
              selected: {grid.useAutoColumns},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                context.read<PosCatalogGridCubit>().setUseAutoColumns(s.first);
              },
            ),
            if (!grid.useAutoColumns) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${grid.manualColumnCount}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'колонок',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Slider(
                value: grid.manualColumnCount.toDouble(),
                min: 2,
                max: 8,
                divisions: 6,
                label: '${grid.manualColumnCount}',
                onChanged: (v) => context
                    .read<PosCatalogGridCubit>()
                    .setManualColumnCount(v.round()),
              ),
            ],
            const SizedBox(height: 14),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Предпросмотр на этом экране',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview.summaryLine,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MiniGridPreview(
                      columnCount: preview.columnCount,
                      cardSize: grid.cardSize,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogGridPreview {
  const _CatalogGridPreview({
    required this.columnCount,
    required this.catalogPaneWidth,
    required this.sideCategoryNav,
  });

  final int columnCount;
  final double catalogPaneWidth;
  final bool sideCategoryNav;

  String get summaryLine {
    final nav = sideCategoryNav ? ', разделы сбоку' : ', разделы сверху';
    return 'Получится $columnCount кол. '
        '(ширина каталога ≈ ${catalogPaneWidth.round()} px$nav)';
  }

  static _CatalogGridPreview compute(
    BuildContext context,
    PosCatalogGridSettings grid,
  ) {
    final screenW = MediaQuery.sizeOf(context).width;
    final layout = WindowLayout(width: screenW);
    final docked = layout.dockPosCart;
    const appendCart = 400.0;
    final cartW = docked
        ? (screenW >= WindowLayout.posCartDockBreakpoint
            ? WindowLayout.posCartPanelWidth
            : appendCart)
        : 0.0;
    final catalogW = docked
        ? layout.posCatalogPaneWidthBesideCart(screenW, cartW)
        : screenW;
    final side = layout.posSideCategoryNavForCatalogPane(catalogW);
    final cols = grid.columnsFor(
      catalogPaneWidth: catalogW,
      sideCategoryNav: side,
    );
    return _CatalogGridPreview(
      columnCount: cols,
      catalogPaneWidth: catalogW,
      sideCategoryNav: side,
    );
  }
}

class _MiniGridPreview extends StatelessWidget {
  const _MiniGridPreview({
    required this.columnCount,
    required this.cardSize,
  });

  final int columnCount;
  final PosCatalogCardSize cardSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = columnCount.clamp(2, 8);
    final aspect = cardSize.aspectRatio;

    return AspectRatio(
      aspectRatio: n / (1 / aspect * 0.45 + 0.2),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: n,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: aspect,
        ),
        itemCount: n * 2,
        itemBuilder: (_, i) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                    child: Icon(
                      Icons.lunch_dining_rounded,
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      '•••',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
