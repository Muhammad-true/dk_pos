import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

/// Объединяет строки по названию позиции (суммируются количество и сумма).
List<PosTableBillLine> mergePosTableBillLines(
  List<PosTableBillLine> a,
  List<PosTableBillLine> b,
) {
  final map = <String, PosTableBillLine>{};

  void add(PosTableBillLine l) {
    final prev = map[l.name];
    if (prev == null) {
      map[l.name] = l;
    } else {
      map[l.name] = PosTableBillLine(
        name: l.name,
        quantity: prev.quantity + l.quantity,
        lineTotal: prev.lineTotal + l.lineTotal,
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

/// Дополняет открытый счёт стола новым заказом (тот же id и дата создания).
PosTableBill mergePosTableBills(PosTableBill open, PosTableBill incoming) {
  final mergedLines = mergePosTableBillLines(open.lines, incoming.lines);
  final total = mergedLines.fold<double>(0, (s, l) => s + l.lineTotal);
  return PosTableBill(
    id: open.id,
    lines: mergedLines,
    total: total,
    orderTypeLabel: open.orderTypeLabel,
    tableNumber: open.tableNumber,
    tableZone: open.tableZone,
    createdAt: open.createdAt,
    isPaid: false,
    paymentMethod: null,
  );
}
