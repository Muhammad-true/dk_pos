import 'package:flutter/material.dart';

import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/shared/shared.dart';

class PosMenuItemCard extends StatelessWidget {
  const PosMenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
    required this.onConfigure,
  });

  final PosMenuItem item;
  final VoidCallback onAdd;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.mediaUrl(item.imagePath);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
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
                    url.isEmpty
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  scheme.surfaceContainerHighest,
                                  scheme.surfaceContainerHigh,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.lunch_dining_rounded,
                              size: 72,
                              color: scheme.secondary,
                            ),
                          )
                        : LayoutBuilder(
                              builder: (context, constraints) {
                                final dpr = MediaQuery.devicePixelRatioOf(context);
                                final pxW =
                                    (constraints.maxWidth * dpr).round().clamp(1, 4096);
                                final pxH =
                                    (constraints.maxHeight * dpr).round().clamp(1, 4096);
                                // Одна сторона — пропорции как на сайте (object-fit: contain).
                                final decodeSide = pxW > pxH ? pxW : pxH;
                                return ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: RobustNetworkImage(
                                    url: url,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                    cacheWidth: decodeSide,
                                    filterQuality: FilterQuality.high,
                                    errorWidget: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            scheme.surfaceContainerHighest,
                                            scheme.surfaceContainerHigh,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: scheme.secondary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
