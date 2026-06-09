import 'package:flutter/material.dart';

import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';

/// Заголовок секции очереди (полоска + текст) — стиль кассы / сборки.
class PosQueueSectionLabel extends StatelessWidget {
  const PosQueueSectionLabel({
    super.key,
    required this.label,
    required this.tone,
    this.count,
  });

  final String label;
  final Color tone;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: PosQueueLayout.sectionBarWidth(context),
          height: PosQueueLayout.sectionBarHeight(context),
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: PosQueueLayout.sectionGap(context)),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: tone,
              fontSize: PosQueueLayout.sectionFont(context),
            ),
          ),
        ),
        if (count != null && count! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
          ),
      ],
    );
  }
}
