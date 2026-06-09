import 'package:flutter/material.dart';

import 'package:dk_pos/shared/shared.dart';

import 'pos_product_image.dart';

class PosMenuItemCard extends StatelessWidget {
  const PosMenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onConfigure,
  });

  final PosMenuItem item;
  final void Function(Rect sourceGlobalRect) onAdd;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          final rect = box != null && box.hasSize
              ? (box.localToGlobal(Offset.zero) & box.size)
              : Rect.zero;
          onAdd(rect);
        },
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
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: OutlinedButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Добавка'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
