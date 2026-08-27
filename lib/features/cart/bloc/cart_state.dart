import 'package:equatable/equatable.dart';

import 'package:dk_pos/core/utils/cart_line_key.dart';
import 'package:dk_pos/core/utils/variable_sale_qty.dart';
import 'package:dk_pos/features/cart/domain/cart_payment_adjustment.dart';
import 'package:dk_pos/shared/shared.dart';

class CartLine extends Equatable {
  const CartLine({
    required this.item,
    required this.quantity,
    this.modifiers = const [],
    this.saleMeasure,
    this.defaultSaleQty,
    this.actualQty,
  });

  final PosMenuItem item;
  final int quantity;
  final List<PosCartModifier> modifiers;
  final String? saleMeasure;
  final double? defaultSaleQty;
  final double? actualQty;

  String get lineKey => computeCartLineKey(
        menuItemId: item.id,
        modifiers: modifiers,
        unitPrice: item.price,
        catalogBasePrice: item.baseCatalogPrice,
        actualQty: actualQty,
        defaultSaleQty: defaultSaleQty,
      );

  double get lineTotal => item.price * quantity;

  String get displayName {
    final modLabel = modifiers
        .map(PosCartModifier.formatLabel)
        .where((n) => n.isNotEmpty)
        .join(', ');
    final baseName =
        modLabel.isNotEmpty ? '${item.name} ($modLabel)' : item.name;
    if (actualQty != null && defaultSaleQty != null && saleMeasure != null) {
      return VariableSaleQty(
        enabled: true,
        measure: saleMeasure!,
        defaultQty: defaultSaleQty!,
        actualQty: actualQty!,
      ).displayName(baseName, quantity: quantity);
    }
    return quantity > 1 ? '$quantity× $baseName' : baseName;
  }

  @override
  List<Object?> get props => [
        lineKey,
        quantity,
        item.price,
        item.name,
        modifiers,
        saleMeasure,
        defaultSaleQty,
        actualQty,
      ];
}

/// Метаданные открытого чека (вкладка на кассе).
class CartCheckInfo extends Equatable {
  const CartCheckInfo({
    required this.id,
    required this.ordinal,
    this.tableLabel,
    this.itemCount = 0,
  });

  final String id;
  final int ordinal;

  /// Подпись из выбора стола; иначе в UI показываем «Клиент N».
  final String? tableLabel;

  /// Сумма количеств позиций в этом чеке (для подсказки и закрытия вкладки).
  final int itemCount;

  String get displayLabel => tableLabel ?? 'Клиент $ordinal';

  @override
  List<Object?> get props => [id, ordinal, tableLabel, itemCount];
}

class CartState extends Equatable {
  const CartState({
    this.checks = const [],
    this.activeCheckId = '',
    this.lines = const {},
    this.activeOrderTypeIndex = -1,
    this.paymentAdjustment,
  });

  final List<CartCheckInfo> checks;
  final String activeCheckId;

  /// Строки **активного** чека.
  final Map<String, CartLine> lines;

  /// -1 — не выбран, 0 — с собой, 1 — на месте, 2 — доставка.
  final int activeOrderTypeIndex;

  final CartPaymentAdjustment? paymentAdjustment;

  List<CartLine> get sortedLines {
    final list = lines.values.toList();
    list.sort((a, b) => a.item.name.compareTo(b.item.name));
    return list;
  }

  int get itemCount => lines.values.fold(0, (s, l) => s + l.quantity);

  double get total => lines.values.fold(0.0, (s, l) => s + l.lineTotal);

  double get payableTotal => paymentAdjustment?.payableAmount ?? total;

  bool get isEmpty => lines.isEmpty;

  bool get hasMultipleChecks => checks.length > 1;

  /// Отпечаток корзины для синхронизации с экраном клиента.
  String get customerDisplayCartKey {
    final parts = <String>[
      activeCheckId,
      't:$activeOrderTypeIndex',
      'n:${lines.length}',
      'q:$itemCount',
      'sum:$total',
      'pay:$payableTotal',
      'disc:${paymentAdjustment?.totalDiscount ?? 0}',
    ];
    for (final line in sortedLines) {
      parts.add('${line.lineKey}:${line.quantity}:${line.lineTotal}');
    }
    return parts.join('|');
  }

  @override
  List<Object?> get props =>
      [checks, activeCheckId, lines, activeOrderTypeIndex, paymentAdjustment];
}
