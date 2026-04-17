import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';

/// Сборка [PosTableBill] из ответа GET /open-table-bills.
PosTableBill posTableBillFromServerDto(LocalOpenTableBillDto d) {
  final parsed = parsePosTableLabel(d.tableLabel);
  final created = d.createdAtIso != null && d.createdAtIso!.isNotEmpty
      ? DateTime.tryParse(d.createdAtIso!)?.toLocal()
      : null;
  return PosTableBill(
    id: d.id,
    lines: d.lines
        .map(
          (l) => PosTableBillLine(
            name: l.name,
            quantity: l.quantity,
            lineTotal: l.lineTotal,
          ),
        )
        .toList(growable: false),
    total: d.total,
    orderTypeLabel: d.orderType,
    tableNumber: parsed.number,
    tableZone: parsed.zone,
    createdAt: created ?? DateTime.now(),
    isPaid: false,
    paymentMethod: null,
  );
}
