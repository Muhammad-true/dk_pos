import 'package:equatable/equatable.dart';
import 'package:dk_pos/shared/models/pos_menu_models.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

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

/// Ключ для проверки «стол занят» (активная сессия / неоплаченный счёт).
extension PosTableZoneOccupiedKey on PosTableZone {
  String occupiedKey(int tableNumber) => '$name-$tableNumber';
}

const _activeTableStatuses = {
  'new',
  'cooking',
  'awaiting_expeditor',
  'ready',
};

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
    this.modifiers = const [],
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

  final List<PosCartModifier> modifiers;

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
        modifiers,
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
    this.isOnlineOrder = false,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.deliveryFee = 0,
    this.deliveryCourier,
    this.deliveryMethod,
    this.deliveryZone,
    this.dto,
    this.handedOutAt,
    this.tableSessionPhase,
    this.tableSessionEndsAt,
    this.tableSessionGraceMinutes,
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

  /// Заказ с сайта / Telegram (после «Принять» на кассе).
  final bool isOnlineOrder;

  /// Сумма позиций до скидки (если с сервера нет — равна [total]).
  final double subtotal;

  final double discountAmount;

  /// Стоимость собственной доставки, уже включённая в [total].
  /// Для такси «по счётчику» остаётся 0: оно оплачивается отдельно.
  final double deliveryFee;

  final String? deliveryCourier;
  final String? deliveryMethod;
  final String? deliveryZone;
  final LocalOpenTableBillDto? dto;

  final DateTime? handedOutAt;

  /// `active` | `handed_out` | null
  final String? tableSessionPhase;

  final DateTime? tableSessionEndsAt;
  final int? tableSessionGraceMinutes;

  bool get hasDiscount => discountAmount > 0.009;

  bool get hasDeliveryFee => deliveryFee > 0.009;

  /// Промокод с сервера (если скидка применена через промо).
  String? get promoCode => dto?.promoCode;

  bool get hasPromoDiscount => hasDiscount;

  double get promoDiscountAmount => discountAmount;

  double get subtotalBeforeDiscount =>
      subtotal > 0.009 ? subtotal : total + discountAmount;

  bool get isHandedOutUnpaid =>
      !isPaid && orderStatus.trim().toLowerCase() == 'done';

  bool get isOnlineBill =>
      isOnlineOrder || orderTypeLabel.toLowerCase().contains('онлайн');

  bool get hasTableAssignment =>
      (tableNumber != null && tableZone != null) || tableLabel.trim().isNotEmpty;

  /// Стол занят этим заказом на карте кассы — только неоплаченные.
  /// Оплаченный заказ сохраняет [tableLabel] для кухни и истории, но стол свободен.
  bool get occupiesTable {
    if (isPaid) return false;
    if (!hasTableAssignment) return false;
    final st = orderStatus.trim().toLowerCase();
    if (st == 'cancelled') return false;
    if (_activeTableStatuses.contains(st)) return true;
    if (st.isEmpty) {
      // Локальный счёт сразу после оформления — ещё без статуса с сервера.
      return true;
    }
    final phase = (tableSessionPhase ?? '').trim().toLowerCase();
    if (phase == 'active') return true;
    if (st == 'done' || phase == 'handed_out') {
      final ends = tableSessionEndsAt;
      if (ends != null) return DateTime.now().isBefore(ends);
      final ho = handedOutAt;
      if (ho == null) return false;
      final grace = tableSessionGraceMinutes ?? 8;
      return DateTime.now().isBefore(ho.add(Duration(minutes: grace)));
    }
    return false;
  }

  bool get isHandedOutSession {
    final phase = (tableSessionPhase ?? '').trim().toLowerCase();
    if (phase == 'handed_out') return true;
    return orderStatus.trim().toLowerCase() == 'done' && occupiesTable;
  }

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
    if (orderTypeLabel == 'На месте') return 'Без стола';
    return orderTypeLabel;
  }

  PosTableBill copyWith({
    bool? isPaid,
    String? paymentMethod,
    int? tableNumber,
    PosTableZone? tableZone,
    String? tableLabel,
    String? orderTypeLabel,
    String? orderStatus,
    String? tableSessionPhase,
    DateTime? handedOutAt,
    DateTime? tableSessionEndsAt,
    int? tableSessionGraceMinutes,
    bool clearTable = false,
  }) {
    final nextType = orderTypeLabel ?? this.orderTypeLabel;
    final typeLow = nextType.toLowerCase();
    final nextDelivery = typeLow.contains('доставк') || typeLow.contains('delivery');
    final nextTakeaway = typeLow.contains('самовывоз') ||
        typeLow.contains('с собой') ||
        typeLow.contains('pickup') ||
        typeLow.contains('takeaway') ||
        typeLow.contains('to_go');
    return PosTableBill(
      id: id,
      lines: lines,
      total: total,
      orderTypeLabel: nextType,
      orderNumber: orderNumber,
      tableNumber: clearTable ? null : (tableNumber ?? this.tableNumber),
      tableZone: clearTable ? null : (tableZone ?? this.tableZone),
      createdAt: createdAt,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderStatus: orderStatus ?? this.orderStatus,
      tableLabel: clearTable ? '' : (tableLabel ?? this.tableLabel),
      customerPhone: customerPhone,
      isDelivery: orderTypeLabel != null ? nextDelivery : isDelivery,
      createdByUsername: createdByUsername,
      createdByRole: createdByRole,
      terminalId: terminalId,
      isWaiterOrder: isWaiterOrder,
      isTakeaway: orderTypeLabel != null ? nextTakeaway : isTakeaway,
      isCashierOrder: isCashierOrder,
      isOnlineOrder: isOnlineOrder,
      subtotal: subtotal,
      discountAmount: discountAmount,
      deliveryFee: deliveryFee,
      deliveryCourier: deliveryCourier,
      deliveryMethod: deliveryMethod,
      deliveryZone: deliveryZone,
      dto: dto,
      handedOutAt: handedOutAt ?? this.handedOutAt,
      tableSessionPhase:
          clearTable ? null : (tableSessionPhase ?? this.tableSessionPhase),
      tableSessionEndsAt:
          clearTable ? null : (tableSessionEndsAt ?? this.tableSessionEndsAt),
      tableSessionGraceMinutes:
          tableSessionGraceMinutes ?? this.tableSessionGraceMinutes,
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
        isOnlineOrder,
        subtotal,
        discountAmount,
        deliveryFee,
        deliveryCourier,
        deliveryMethod,
        deliveryZone,
        handedOutAt,
        tableSessionPhase,
        tableSessionEndsAt,
        tableSessionGraceMinutes,
      ];
}
