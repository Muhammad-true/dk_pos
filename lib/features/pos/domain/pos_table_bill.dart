import 'package:equatable/equatable.dart';

/// Зона обслуживания (зал / веранда) — номера столов могут совпадать в разных зонах.
enum PosTableZone {
  hall,
  veranda,
}

extension PosTableZoneLabel on PosTableZone {
  String get shortLabel => switch (this) {
        PosTableZone.hall => 'Зал',
        PosTableZone.veranda => 'Веранда',
      };
}

/// Ключ для проверки «стол занят» (открытый неоплаченный счёт).
extension PosTableZoneOccupiedKey on PosTableZone {
  String occupiedKey(int tableNumber) => '$name-$tableNumber';
}

/// Строка счёта (снимок на момент оформления).
class PosTableBillLine extends Equatable {
  const PosTableBillLine({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.menuItemId,
    this.lineKey,
    this.unitPrice,
    this.kitchenLineStatus,
    this.kitchenStationId,
  });

  final String name;
  final int quantity;
  final double lineTotal;
  /// С сервера open-table-bills — для подстановки в корзину.
  final String? menuItemId;
  /// Ключ строки в order_items (как в корзине).
  final String? lineKey;
  final double? unitPrice;

  /// С сервера: этап строки кухни (`pending` / `accepted` / `ready`).
  final String? kitchenLineStatus;

  /// С сервера: станция кухни; `null` — позиция без очереди кухни (напитки, витрина).
  final int? kitchenStationId;

  bool get isKitchenLine =>
      kitchenStationId != null && kitchenStationId! > 0;

  /// Кухня уже приняла в работу — при убирании из счёта нужна причина.
  bool get needsRemovalReason {
    if (!isKitchenLine) return false;
    final st = (kitchenLineStatus ?? 'pending').toLowerCase().trim();
    return st == 'accepted' || st == 'ready';
  }

  @override
  List<Object?> get props => [
        name,
        quantity,
        lineTotal,
        menuItemId,
        lineKey,
        unitPrice,
        kitchenLineStatus,
        kitchenStationId,
      ];
}

/// Счёт: стол / тип заказа, оплата сразу или отложена.
class PosTableBill extends Equatable {
  const PosTableBill({
    required this.id,
    required this.lines,
    required this.total,
    required this.orderTypeLabel,
    required this.createdAt,
    this.orderNumber = '',
    this.tableNumber,
    this.tableZone,
    this.isPaid = false,
    this.paymentMethod,
    this.orderStatus = '',
    this.tableLabel = '',
    this.customerPhone,
    this.isDelivery = false,
    this.createdByUsername,
    this.createdByRole,
    this.terminalId,
    this.isWaiterOrder = false,
    this.isTakeaway = false,
    this.isCashierOrder = false,
  });

  final String id;
  final List<PosTableBillLine> lines;
  final double total;
  final String orderTypeLabel;
  final String orderNumber;
  final int? tableNumber;
  /// Для «на месте»: зал или веранда (если стол задан).
  final PosTableZone? tableZone;
  final DateTime createdAt;
  final bool isPaid;
  final String? paymentMethod;

  /// Статус заказа с сервера (`new`, `cooking`, `ready`, `done`, …).
  final String orderStatus;

  /// Сырая метка с сервера (`table_label`), в т.ч. «Доставка · тел: …».
  final String tableLabel;

  /// Телефон клиента для доставки (из table_label или API).
  final String? customerPhone;

  final bool isDelivery;

  /// Имя пользователя, создавшего заказ (официант / кассир).
  final String? createdByUsername;

  final String? createdByRole;

  /// Терминал кассы (`POS_TERMINAL_ID`).
  final String? terminalId;

  final bool isWaiterOrder;
  final bool isTakeaway;
  final bool isCashierOrder;

  bool get isHandedOutUnpaid =>
      !isPaid && orderStatus.trim().toLowerCase() == 'done';

  /// Номер для UI: префикс Д-/С- для доставки и самовывоза (как на доске кассы).
  String get displayOrderNumber {
    final clean = orderNumber.trim();
    if (clean.isEmpty) return '';
    final low = orderTypeLabel.toLowerCase();
    if (isDelivery || low.contains('доставк')) return 'Д-$clean';
    if (isTakeaway ||
        low.contains('самовывоз') ||
        low.contains('с собой') ||
        low.contains('pickup') ||
        low.contains('takeaway')) {
      return 'С-$clean';
    }
    return clean;
  }

  String get tableSummary {
    if (tableNumber != null) {
      final z = tableZone;
      if (z != null) return '${z.shortLabel} • стол $tableNumber';
      return 'Стол $tableNumber';
    }
    final delivery =
        isDelivery || orderTypeLabel.toLowerCase().contains('доставк');
    if (delivery) {
      final phone = customerPhone?.trim();
      if (phone != null && phone.isNotEmpty) {
        return 'Доставка · тел. получателя $phone';
      }
      return 'Доставка';
    }
    if (orderTypeLabel == 'На месте') return 'Стол не указан';
    return orderTypeLabel;
  }

  PosTableBill copyWith({
    bool? isPaid,
    String? paymentMethod,
  }) {
    return PosTableBill(
      id: id,
      lines: lines,
      total: total,
      orderTypeLabel: orderTypeLabel,
      orderNumber: orderNumber,
      tableNumber: tableNumber,
      tableZone: tableZone,
      createdAt: createdAt,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderStatus: orderStatus,
      tableLabel: tableLabel,
      customerPhone: customerPhone,
      isDelivery: isDelivery,
      createdByUsername: createdByUsername,
      createdByRole: createdByRole,
      terminalId: terminalId,
      isWaiterOrder: isWaiterOrder,
      isTakeaway: isTakeaway,
      isCashierOrder: isCashierOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        lines,
        total,
        orderTypeLabel,
        orderNumber,
        tableNumber,
        tableZone,
        createdAt,
        isPaid,
        paymentMethod,
        orderStatus,
        tableLabel,
        customerPhone,
        isDelivery,
        createdByUsername,
        createdByRole,
        terminalId,
        isWaiterOrder,
        isTakeaway,
        isCashierOrder,
      ];
}
