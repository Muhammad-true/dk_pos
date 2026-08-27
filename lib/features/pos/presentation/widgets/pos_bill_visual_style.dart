import 'package:flutter/material.dart';

import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_bill_channel_chips.dart';

class PosBillVisualStyle {
  const PosBillVisualStyle({
    required this.accent,
    required this.surfaceTint,
    required this.icon,
    required this.categoryLabel,
  });

  final Color accent;
  final Color surfaceTint;
  final IconData icon;
  final String categoryLabel;
}

PosBillVisualStyle posBillVisualStyle(PosTableBill bill, ColorScheme scheme) {
  if (bill.isOnlineBill) {
    return const PosBillVisualStyle(
      accent: Color(0xFF7B1FA2),
      surfaceTint: Color(0xFFF3E5F5),
      icon: Icons.language_rounded,
      categoryLabel: 'Онлайн',
    );
  }
  if (bill.tableNumber != null) {
    final zone = bill.tableZone;
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
  if (bill.isDelivery || bill.orderTypeLabel.toLowerCase().contains('доставк')) {
    return const PosBillVisualStyle(
      accent: Color(0xFF2E7D32),
      surfaceTint: Color(0xFFE8F5E9),
      icon: Icons.delivery_dining_rounded,
      categoryLabel: 'Доставка',
    );
  }
  if (isTakeawayBillChannel(bill)) {
    return const PosBillVisualStyle(
      accent: Color(0xFFE65100),
      surfaceTint: Color(0xFFFFF3E0),
      icon: Icons.shopping_bag_rounded,
      categoryLabel: 'Самовывоз',
    );
  }
  return PosBillVisualStyle(
    accent: scheme.primary,
    surfaceTint: scheme.surfaceContainer,
    icon: Icons.receipt_long_rounded,
    categoryLabel: bill.orderTypeLabel.trim().isEmpty ? 'Заказ' : bill.orderTypeLabel,
  );
}
