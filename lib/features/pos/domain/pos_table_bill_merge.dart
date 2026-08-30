import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

/// Объединяет строки по названию позиции (суммируются количество и сумма).
List<PosTableBillLine> mergePosTableBillLines(
  List<PosTableBillLine> a,
  List<PosTableBillLine> b,
) {
  final map = <String, PosTableBillLine>{};

  void add(PosTableBillLine l) {
    final mergeKey = _lineMergeKey(l);
    final prev = map[mergeKey];
    if (prev == null) {
      map[mergeKey] = l;
    } else {
      map[mergeKey] = PosTableBillLine(
        name: l.name,
        quantity: prev.quantity + l.quantity,
        lineTotal: prev.lineTotal + l.lineTotal,
        menuItemId: prev.menuItemId ?? l.menuItemId,
        lineKey: prev.lineKey ?? l.lineKey,
        unitPrice: prev.unitPrice ?? l.unitPrice,
        kitchenLineStatus: prev.kitchenLineStatus ?? l.kitchenLineStatus,
        kitchenStationId: prev.kitchenStationId ?? l.kitchenStationId,
      );
    }
  }

  for (final l in a) {
    add(l);
  }
  for (final l in b) {
    add(l);
  }
  final out = map.values.toList();
  out.sort((x, y) => x.name.compareTo(y.name));
  return out;
}

String _lineMergeKey(PosTableBillLine l) {
  final lineKey = (l.lineKey ?? '').trim();
  if (lineKey.isNotEmpty) return 'k:$lineKey';
  final menuItemId = (l.menuItemId ?? '').trim();
  if (menuItemId.isNotEmpty) return 'm:$menuItemId';
  return 'n:${l.name}';
}

/// Дополняет открытый счёт стола новым заказом (тот же id и дата создания).
PosTableBill mergePosTableBills(PosTableBill open, PosTableBill incoming) {
  final mergedLines = mergePosTableBillLines(open.lines, incoming.lines);
  final subtotal = mergedLines.fold<double>(0, (s, l) => s + l.lineTotal);
  final total = subtotal + open.deliveryFee;
  return PosTableBill(
    id: open.id,
    lines: mergedLines,
    total: total,
    orderTypeLabel: open.orderTypeLabel,
    orderNumber: open.orderNumber,
    tableNumber: open.tableNumber,
    tableZone: open.tableZone,
    createdAt: open.createdAt,
    // Дозаказ к оплаченной сессии: сам заказ остаётся paid; новые позиции
    // уходят в тот же order_id (оплата доплаты — отдельно из счетов, если появится).
    isPaid: open.isPaid,
    paymentMethod: open.paymentMethod,
    orderStatus: open.orderStatus.isEmpty ? 'new' : open.orderStatus,
    tableLabel: open.tableLabel,
    customerPhone: open.customerPhone,
    isDelivery: open.isDelivery,
    createdByUsername: open.createdByUsername,
    createdByRole: open.createdByRole,
    terminalId: open.terminalId,
    isWaiterOrder: open.isWaiterOrder,
    isTakeaway: open.isTakeaway,
    isCashierOrder: open.isCashierOrder,
    isOnlineOrder: open.isOnlineOrder,
    subtotal: subtotal,
    discountAmount: open.discountAmount,
    deliveryFee: open.deliveryFee,
    handedOutAt: open.handedOutAt,
    tableSessionPhase: open.tableSessionPhase ?? 'active',
    tableSessionEndsAt: open.tableSessionEndsAt,
    tableSessionGraceMinutes: open.tableSessionGraceMinutes,
    dto: open.dto,
  );
}
