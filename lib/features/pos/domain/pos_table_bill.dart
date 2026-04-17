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
  });

  final String name;
  final int quantity;
  final double lineTotal;

  @override
  List<Object?> get props => [name, quantity, lineTotal];
}

/// Счёт: стол / тип заказа, оплата сразу или отложена.
class PosTableBill extends Equatable {
  const PosTableBill({
    required this.id,
    required this.lines,
    required this.total,
    required this.orderTypeLabel,
    required this.createdAt,
    this.tableNumber,
    this.tableZone,
    this.isPaid = false,
    this.paymentMethod,
  });

  final String id;
  final List<PosTableBillLine> lines;
  final double total;
  final String orderTypeLabel;
  final int? tableNumber;
  /// Для «на месте»: зал или веранда (если стол задан).
  final PosTableZone? tableZone;
  final DateTime createdAt;
  final bool isPaid;
  final String? paymentMethod;

  String get tableSummary {
    if (tableNumber != null) {
      final z = tableZone;
      if (z != null) return '${z.shortLabel} • стол $tableNumber';
      return 'Стол $tableNumber';
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
      tableNumber: tableNumber,
      tableZone: tableZone,
      createdAt: createdAt,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  List<Object?> get props => [
        id,
        lines,
        total,
        orderTypeLabel,
        tableNumber,
        tableZone,
        createdAt,
        isPaid,
        paymentMethod,
      ];
}
