import 'package:flutter/material.dart';

import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_bill_visual_style.dart';

PosBillVisualStyle posCashierOrderVisualStyle(
  LocalCashierBoardOrder order,
  ColorScheme scheme,
) {
  final src = (order.orderSource ?? 'pos').toLowerCase();
  if (src == 'website') {
    return const PosBillVisualStyle(
      accent: Color(0xFF7B1FA2),
      surfaceTint: Color(0xFFF3E5F5),
      icon: Icons.language_rounded,
      categoryLabel: 'Онлайн',
    );
  }
  final type = (order.orderType ?? '').toLowerCase();
  final label = (order.tableLabel ?? '').trim();
  final parsed = parsePosTableLabel(label);
  if (parsed.number != null) {
    final zone = parsed.zone;
    final accent = switch (zone) {
      PosTableZone.hall => const Color(0xFFB8956C),
      PosTableZone.veranda => const Color(0xFF2D8B7E),
      null => const Color(0xFF8D6E63),
    };
    return PosBillVisualStyle(
      accent: accent,
      surfaceTint: accent.withValues(alpha: 0.14),
      icon: zone == PosTableZone.veranda
          ? Icons.deck_rounded
          : Icons.table_restaurant_rounded,
      categoryLabel: 'Стол',
    );
  }
  if (type.contains('доставк') ||
      type.contains('delivery') ||
      label.toLowerCase().contains('доставк')) {
    return const PosBillVisualStyle(
      accent: Color(0xFF2E7D32),
      surfaceTint: Color(0xFFE8F5E9),
      icon: Icons.delivery_dining_rounded,
      categoryLabel: 'Доставка',
    );
  }
  if (type.contains('самовывоз') ||
      type.contains('с собой') ||
      type.contains('pickup') ||
      type.contains('takeaway') ||
      type.contains('to_go')) {
    return const PosBillVisualStyle(
      accent: Color(0xFFE65100),
      surfaceTint: Color(0xFFFFF3E0),
      icon: Icons.shopping_bag_rounded,
      categoryLabel: 'Самовывоз',
    );
  }
  if (label.isEmpty &&
      (type.contains('на месте') ||
          type.contains('зал') ||
          type.contains('dine') ||
          type.isEmpty)) {
    return const PosBillVisualStyle(
      accent: Color(0xFF5C6BC0),
      surfaceTint: Color(0xFFE8EAF6),
      icon: Icons.schedule_rounded,
      categoryLabel: 'Стол позже',
    );
  }
  return PosBillVisualStyle(
    accent: scheme.primary,
    surfaceTint: scheme.surfaceContainer,
    icon: Icons.receipt_long_rounded,
    categoryLabel: (order.orderType ?? '').trim().isEmpty
        ? 'Заказ'
        : order.orderType!.trim(),
  );
}
