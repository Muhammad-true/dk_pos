import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

/// Патч одного заказа для кассы из WS `cashier.board_changed`.
class LocalCashierBoardPatch {
  const LocalCashierBoardPatch({
    required this.orderId,
    this.incoming,
    this.active,
    this.openTableBill,
    this.removeFromIncoming = false,
    this.removeFromActive = false,
    this.removeOpenTableBill = false,
  });

  final String orderId;
  final LocalCashierBoardOrder? incoming;
  final LocalCashierBoardOrder? active;
  final LocalOpenTableBillDto? openTableBill;
  final bool removeFromIncoming;
  final bool removeFromActive;
  final bool removeOpenTableBill;

  static LocalCashierBoardPatch? tryParse(Map<String, dynamic> json) {
    final orderId = json['orderId']?.toString() ?? json['order_id']?.toString() ?? '';
    if (orderId.isEmpty) return null;

    LocalCashierBoardOrder? parseBoard(dynamic raw) {
      if (raw is! Map<String, dynamic>) return null;
      return LocalCashierBoardOrder.fromJson(raw);
    }

    return LocalCashierBoardPatch(
      orderId: orderId,
      incoming: parseBoard(json['incoming']),
      active: parseBoard(json['active']),
      openTableBill: _parseOpenTableBillDto(json['openTableBill'] ?? json['open_table_bill']),
      removeFromIncoming:
          json['removeFromIncoming'] == true || json['remove_from_incoming'] == true,
      removeFromActive:
          json['removeFromActive'] == true || json['remove_from_active'] == true,
      removeOpenTableBill:
          json['removeOpenTableBill'] == true || json['remove_open_table_bill'] == true,
    );
  }
}

List<LocalCashierBoardPatch> parseCashierBoardPatches(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(LocalCashierBoardPatch.tryParse)
      .whereType<LocalCashierBoardPatch>()
      .toList(growable: false);
}

List<LocalCashierBoardOrder> applyCashierIncomingPatches(
  List<LocalCashierBoardOrder> current,
  List<LocalCashierBoardPatch> patches,
) {
  return _applyCashierSectionPatches(
    current,
    patches,
    remove: (p) => p.removeFromIncoming,
    upsert: (p) => p.incoming,
  );
}

List<LocalCashierBoardOrder> applyCashierActivePatches(
  List<LocalCashierBoardOrder> current,
  List<LocalCashierBoardPatch> patches,
) {
  return _applyCashierSectionPatches(
    current,
    patches,
    remove: (p) => p.removeFromActive,
    upsert: (p) => p.active,
  );
}

List<LocalCashierBoardOrder> _applyCashierSectionPatches(
  List<LocalCashierBoardOrder> current,
  List<LocalCashierBoardPatch> patches, {
  required bool Function(LocalCashierBoardPatch) remove,
  required LocalCashierBoardOrder? Function(LocalCashierBoardPatch) upsert,
}) {
  if (patches.isEmpty) return current;
  var list = List<LocalCashierBoardOrder>.from(current);
  for (final patch in patches) {
    final orderId = patch.orderId;
    if (remove(patch)) {
      list = list.where((o) => o.order.id != orderId).toList(growable: false);
    }
    final row = upsert(patch);
    if (row != null) {
      list = _upsertCashierBoardOrder(list, row);
    }
  }
  return list;
}

List<LocalCashierBoardOrder> _upsertCashierBoardOrder(
  List<LocalCashierBoardOrder> list,
  LocalCashierBoardOrder row,
) {
  final idx = list.indexWhere((o) => o.order.id == row.order.id);
  if (idx >= 0) {
    final next = List<LocalCashierBoardOrder>.from(list);
    next[idx] = row;
    return next;
  }
  return [...list, row];
}

LocalOpenTableBillDto? _parseOpenTableBillDto(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;

  int? parseNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  LocalOpenTableBillLineDto parseLine(Map<String, dynamic> m) {
    final q = m['quantity'];
    final qty = q is int ? q : int.tryParse(q?.toString() ?? '') ?? 0;
    final lt = m['lineTotal'] ?? m['line_total'];
    final total = lt is num ? lt.toDouble() : double.tryParse(lt?.toString() ?? '') ?? 0.0;
    final upRaw = m['unitPrice'] ?? m['unit_price'];
    final up = upRaw is num
        ? upRaw.toDouble()
        : double.tryParse(upRaw?.toString() ?? '');
    final midRaw = m['menuItemId'] ?? m['menu_item_id'];
    final mid = midRaw?.toString().trim();
    final lkRaw = m['lineKey'] ?? m['line_key'];
    final lk = lkRaw?.toString().trim();
    return LocalOpenTableBillLineDto(
      name: m['name']?.toString() ?? '',
      quantity: qty,
      lineTotal: total,
      menuItemId: mid != null && mid.isNotEmpty ? mid : null,
      lineKey: lk != null && lk.isNotEmpty ? lk : null,
      unitPrice: up,
      kitchenLineStatus:
          m['kitchenLineStatus']?.toString() ?? m['kitchen_line_status']?.toString(),
      kitchenStationId: parseNullableInt(m['kitchenStationId'] ?? m['kitchen_station_id']),
    );
  }

  final linesRaw = raw['lines'];
  final lines = <LocalOpenTableBillLineDto>[];
  if (linesRaw is List) {
    for (final lr in linesRaw) {
      if (lr is Map<String, dynamic>) {
        lines.add(parseLine(lr));
      } else if (lr is Map) {
        lines.add(parseLine(Map<String, dynamic>.from(lr)));
      }
    }
  }

  final totalRaw = raw['total'] ?? raw['totalPrice'];
  final total = totalRaw is num
      ? totalRaw.toDouble()
      : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;

  final id = raw['id']?.toString() ?? '';
  if (id.isEmpty) return null;

  return LocalOpenTableBillDto(
    id: id,
    number: raw['number']?.toString() ?? '',
    status: raw['status']?.toString() ?? '',
    total: total,
    orderType: raw['orderType']?.toString() ?? raw['order_type']?.toString() ?? 'На месте',
    tableLabel: raw['tableLabel']?.toString() ?? raw['table_label']?.toString() ?? '',
    isDelivery: raw['isDelivery'] == true || raw['is_delivery'] == true,
    customerPhone: raw['customerPhone']?.toString() ?? raw['customer_phone']?.toString(),
    orderSource: raw['orderSource']?.toString() ?? raw['order_source']?.toString(),
    createdAtIso: raw['createdAt']?.toString() ?? raw['created_at']?.toString(),
    createdByUsername:
        raw['createdByUsername']?.toString() ?? raw['created_by_username']?.toString(),
    createdByRole: raw['createdByRole']?.toString() ?? raw['created_by_role']?.toString(),
    terminalId: raw['terminalId']?.toString() ?? raw['terminal_id']?.toString(),
    isWaiterOrder: raw['isWaiterOrder'] == true || raw['is_waiter_order'] == true,
    isTakeaway: raw['isTakeaway'] == true || raw['is_takeaway'] == true,
    isCashierOrder: raw['isCashierOrder'] == true || raw['is_cashier_order'] == true,
    lines: lines,
  );
}
