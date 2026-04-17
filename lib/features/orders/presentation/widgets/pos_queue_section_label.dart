import 'package:flutter/material.dart';

import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';

/// Заголовок секции очереди (полоска + текст) — стиль кассы / сборки.
class PosQueueSectionLabel extends StatelessWidget {
  const PosQueueSectionLabel({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
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
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
                fontSize: PosQueueLayout.sectionFont(context),
              ),
        ),
      ],
    );
  }
}
