import 'package:flutter/material.dart';

import 'package:dk_pos/shared/shared.dart';

import 'pos_product_image.dart';

class PosMenuItemCard extends StatelessWidget {
  const PosMenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onConfigure,
    this.onToggleSoldOut,
  });

  final PosMenuItem item;
  final void Function(Rect sourceGlobalRect) onAdd;
  final VoidCallback onConfigure;
  final VoidCallback? onToggleSoldOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final soldOut = item.soldOutToday;
    final showConfigure = !soldOut &&
        (item.hasModifiers ||
            (item.composition?.trim().isNotEmpty ?? false) ||
            (item.description?.trim().isNotEmpty ?? false));

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: soldOut ? scheme.surfaceContainerHighest.withValues(alpha: 0.85) : null,
      child: InkWell(
        onTap: soldOut
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Закончилось сегодня')),
                );
              }
            : () {
                final box = context.findRenderObject() as RenderBox?;
                final rect = box != null && box.hasSize
                    ? (box.localToGlobal(Offset.zero) & box.size)
                    : Rect.zero;
                onAdd(rect);
              },
        onLongPress: onToggleSoldOut, // null — не мешает drag/hold сетки
        child: Opacity(
          opacity: soldOut ? 0.72 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerLowest,
                  scheme.surfaceContainerLow,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 8,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PosProductImage(
                        imagePath: item.imagePath,
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      ),
                      if (soldOut)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Закончилось\nсегодня',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: item.hasModifiers && !soldOut
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: scheme.onPrimaryContainer,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (!soldOut)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD92D20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.priceText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showConfigure)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: OutlinedButton.icon(
                      onPressed: onConfigure,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: Text(item.hasModifiers ? 'Настроить' : 'Состав'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
