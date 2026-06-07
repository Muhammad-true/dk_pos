import 'package:flutter/material.dart';

import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

bool isWaiterBillChannel(PosTableBill bill) {
  if (bill.isWaiterOrder) return true;
  final v = bill.orderTypeLabel.toLowerCase();
  return v.contains('официант') || v.contains('waiter');
}

bool isTakeawayBillChannel(PosTableBill bill) {
  if (bill.isTakeaway) return true;
  final v = bill.orderTypeLabel.toLowerCase();
  return v.contains('самовывоз') ||
      v.contains('с собой') ||
      v.contains('pickup') ||
      v.contains('takeaway') ||
      v.contains('to_go') ||
      v.contains('парковк') ||
      v.contains('parking');
}

bool isCashierBillChannel(PosTableBill bill) {
  if (bill.isCashierOrder) return true;
  if (isWaiterBillChannel(bill)) return false;
  final role = (bill.createdByRole ?? '').toLowerCase();
  if (role == 'cashier' || role == 'admin' || role == 'expeditor') {
    return true;
  }
  final terminal = bill.terminalId?.trim();
  return terminal != null && terminal.isNotEmpty;
}

class _ChannelChipStyle {
  const _ChannelChipStyle({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
    this.detail,
  });

  final String label;
  final String? detail;
  final Color bg;
  final Color fg;
  final IconData icon;
}

/// Бейджи канала заказа: официант, касса, самовывоз, доставка.
class PosBillChannelChips extends StatelessWidget {
  const PosBillChannelChips({super.key, required this.bill});

  final PosTableBill bill;

  static const _waiterBg = Color(0xFFEDE7F6);
  static const _waiterFg = Color(0xFF4527A0);
  static const _cashierBg = Color(0xFFE3F2FD);
  static const _cashierFg = Color(0xFF1565C0);
  static const _takeawayBg = Color(0xFFFFF3E0);
  static const _takeawayFg = Color(0xFFE65100);
  static const _deliveryBg = Color(0xFFE8F5E9);
  static const _deliveryFg = Color(0xFF2E7D32);

  List<_ChannelChipStyle> _styles() {
    final out = <_ChannelChipStyle>[];
    if (isWaiterBillChannel(bill)) {
      final name = bill.createdByUsername?.trim();
      out.add(
        _ChannelChipStyle(
          label: 'Официант',
          detail: name != null && name.isNotEmpty ? name : null,
          bg: _waiterBg,
          fg: _waiterFg,
          icon: Icons.room_service_rounded,
        ),
      );
    } else if (isCashierBillChannel(bill)) {
      final terminal = bill.terminalId?.trim();
      final name = bill.createdByUsername?.trim();
      final detail = (terminal != null && terminal.isNotEmpty)
          ? terminal
          : (name != null && name.isNotEmpty ? name : null);
      out.add(
        _ChannelChipStyle(
          label: 'Касса',
          detail: detail,
          bg: _cashierBg,
          fg: _cashierFg,
          icon: Icons.point_of_sale_rounded,
        ),
      );
    }
    if (isTakeawayBillChannel(bill)) {
      out.add(
        const _ChannelChipStyle(
          label: 'Самовывоз',
          bg: _takeawayBg,
          fg: _takeawayFg,
          icon: Icons.shopping_bag_rounded,
        ),
      );
    }
    if (bill.isDelivery ||
        bill.orderTypeLabel.toLowerCase().contains('доставк')) {
      final phone = bill.customerPhone?.trim();
      out.add(
        _ChannelChipStyle(
          label: 'Доставка',
          detail: phone != null && phone.isNotEmpty ? phone : null,
          bg: _deliveryBg,
          fg: _deliveryFg,
          icon: Icons.delivery_dining_rounded,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final chips = _styles();
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final style in chips) _Chip(style),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.style);

  final _ChannelChipStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = style.detail != null && style.detail!.isNotEmpty
        ? '${style.label} · ${style.detail}'
        : style.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: style.fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
