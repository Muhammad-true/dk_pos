import 'package:flutter/material.dart';

import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';

/// Крупный блок заказа для кухни: номер, тип и стол (хорошо читается издалека).
class KitchenOrderNumberBadge extends StatelessWidget {
  const KitchenOrderNumberBadge({
    super.key,
    required this.displayNumber,
    required this.tone,
    this.textScale = 1,
    this.compact,
    this.orderTypeLabel,
    this.tableHeadline,
  });

  /// Уже с префиксом Д-/С- при необходимости.
  final String displayNumber;
  final Color tone;
  final double textScale;
  final bool? compact;

  /// Доставка / Самовывоз / В зале.
  final String? orderTypeLabel;

  /// Стол 7, Зал · стол 3 и т.п.
  final String? tableHeadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompact = compact ?? PosQueueLayout.shortestSide(context) < 600;
    final isLargeTablet = PosQueueLayout.shortestSide(context) >= 900;
    final number = displayNumber.trim();

    final numberSize =
        (isLargeTablet ? 58.0 : (isCompact ? 42.0 : 52.0)) * textScale;
    final typeSize =
        (isLargeTablet ? 22.0 : (isCompact ? 17.0 : 20.0)) * textScale;
    final tableSize =
        (isLargeTablet ? 38.0 : (isCompact ? 28.0 : 34.0)) * textScale;
    final labelSize =
        (isLargeTablet ? 14.0 : (isCompact ? 12.0 : 13.0)) * textScale;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 20,
        vertical: isCompact ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone, width: isCompact ? 2.5 : 3),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ЗАКАЗ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: scheme.onSurfaceVariant,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: isCompact ? 6 : 8),
                    if (number.isEmpty)
                      Text(
                        '—',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      Text(
                        number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: numberSize,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                  ],
                ),
              ),
              if (orderTypeLabel != null) ...[
                SizedBox(width: isCompact ? 10 : 12),
                _KitchenTypePill(
                  label: orderTypeLabel!,
                  tone: tone,
                  fontSize: typeSize,
                  compact: isCompact,
                ),
              ],
            ],
          ),
          if (tableHeadline != null) ...[
            SizedBox(height: isCompact ? 12 : 14),
            Row(
              children: [
                Icon(
                  Icons.table_restaurant_rounded,
                  color: tone,
                  size: tableSize * 0.9,
                ),
                SizedBox(width: isCompact ? 8 : 10),
                Expanded(
                  child: Text(
                    tableHeadline!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: tableSize,
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KitchenTypePill extends StatelessWidget {
  const _KitchenTypePill({
    required this.label,
    required this.tone,
    required this.fontSize,
    required this.compact,
  });

  final String label;
  final Color tone;
  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDelivery = label == 'Доставка';
    final isPickup = label == 'Самовывоз';
    final icon = isDelivery
        ? Icons.delivery_dining_rounded
        : isPickup
            ? Icons.shopping_bag_outlined
            : Icons.restaurant_rounded;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize * 1.15, color: tone),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: tone,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
