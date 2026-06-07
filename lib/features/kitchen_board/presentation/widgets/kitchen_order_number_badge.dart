import 'package:flutter/material.dart';

import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';

/// Крупный номер заказа для кухни и экрана очереди (хорошо читается издалека).
class KitchenOrderNumberBadge extends StatelessWidget {
  const KitchenOrderNumberBadge({
    super.key,
    required this.displayNumber,
    required this.tone,
    this.textScale = 1,
    this.compact,
  });

  /// Уже с префиксом Д-/С- при необходимости.
  final String displayNumber;
  final Color tone;
  final double textScale;
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompact = compact ?? PosQueueLayout.shortestSide(context) < 600;
    final isLargeTablet = PosQueueLayout.shortestSide(context) >= 900;
    final number = displayNumber.trim();
    if (number.isEmpty) {
      return Text(
        '—',
        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      );
    }

    final numberSize = (isLargeTablet ? 48.0 : (isCompact ? 34.0 : 42.0)) * textScale;
    final labelSize = (isLargeTablet ? 13.0 : (isCompact ? 11.0 : 12.0)) * textScale;

    return Container(
      constraints: BoxConstraints(minWidth: isCompact ? 88 : 104),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone, width: isCompact ? 2.5 : 3),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ЗАКАЗ',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: labelSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: scheme.onSurfaceVariant,
              height: 1,
            ),
          ),
          SizedBox(height: isCompact ? 4 : 6),
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
    );
  }
}
