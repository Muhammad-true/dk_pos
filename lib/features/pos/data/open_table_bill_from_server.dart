import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';

/// Человекочитаемый тип заказа для счёта (в БД с сайта часто `pickup` / `delivery` / `parking`).
String openTableBillOrderTypeLabelRu(String raw) {
  final low = raw.trim().toLowerCase();
  if (low == 'dinein' || low == 'dine_in' || low == 'dine-in') return 'На месте';
  if (low == 'on_site' || low == 'onsite') return 'На месте';
  if (low == 'delivery') return 'Доставка';
  if (low == 'pickup') return 'Самовывоз';
  if (low == 'takeaway' || low == 'take_away' || low == 'to_go') return 'Самовывоз';
  if (low == 'parking') return 'Парковка';
  return raw.trim().isEmpty ? 'На месте' : raw.trim();
}

/// Сборка [PosTableBill] из ответа GET /open-table-bills.
PosTableBill posTableBillFromServerDto(LocalOpenTableBillDto d) {
  final parsed = parsePosTableLabel(d.tableLabel);
  final created = d.createdAtIso != null && d.createdAtIso!.isNotEmpty
      ? DateTime.tryParse(d.createdAtIso!)?.toLocal()
      : null;
  final src = (d.orderSource ?? 'pos').toLowerCase().trim();
  final baseType = openTableBillOrderTypeLabelRu(d.orderType);
  final typeLabel =
      src == 'website' ? 'Онлайн · $baseType' : baseType;
  final tableLabel = d.tableLabel.trim();
  final phoneFromApi = d.customerPhone?.trim();
  final phoneFromLabel = parseDeliveryPhoneFromTableLabel(tableLabel);
  final customerPhone = (phoneFromApi != null && phoneFromApi.isNotEmpty)
      ? phoneFromApi
      : phoneFromLabel;
  final isDelivery =
      d.isDelivery || typeLabel.toLowerCase().contains('доставк');
  return PosTableBill(
    id: d.id,
    lines: d.lines
        .map(
          (l) => PosTableBillLine(
            name: l.name,
            quantity: l.quantity,
            lineTotal: l.lineTotal,
            menuItemId: l.menuItemId,
            lineKey: l.lineKey,
            unitPrice: l.unitPrice,
            kitchenLineStatus: l.kitchenLineStatus,
            kitchenStationId: l.kitchenStationId,
          ),
        )
        .toList(growable: false),
    total: d.total,
    orderTypeLabel: typeLabel,
    tableNumber: parsed.number,
    tableZone: parsed.zone,
    createdAt: created ?? DateTime.now(),
    isPaid: false,
    paymentMethod: null,
    orderStatus: d.status,
    tableLabel: tableLabel,
    customerPhone: customerPhone,
    isDelivery: isDelivery,
    createdByUsername: d.createdByUsername,
    createdByRole: d.createdByRole,
    terminalId: d.terminalId,
    isWaiterOrder: d.isWaiterOrder,
    isTakeaway: d.isTakeaway,
    isCashierOrder: d.isCashierOrder,
  );
}
