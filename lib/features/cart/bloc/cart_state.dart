import 'package:equatable/equatable.dart';

import 'package:dk_pos/shared/shared.dart';

class CartLine extends Equatable {
  const CartLine({required this.item, required this.quantity});

  final PosMenuItem item;
  final int quantity;

  String get lineKey => '${item.id}::${item.price.toStringAsFixed(2)}';
  double get lineTotal => item.price * quantity;

  @override
  List<Object?> get props => [lineKey, quantity];
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
  });

  final List<CartCheckInfo> checks;
  final String activeCheckId;

  /// Строки **активного** чека.
  final Map<String, CartLine> lines;

  /// -1 — не выбран, 0 — с собой, 1 — на месте, 2 — доставка.
  final int activeOrderTypeIndex;

  List<CartLine> get sortedLines {
    final list = lines.values.toList();
    list.sort((a, b) => a.item.name.compareTo(b.item.name));
    return list;
  }

  int get itemCount => lines.values.fold(0, (s, l) => s + l.quantity);

  double get total => lines.values.fold(0.0, (s, l) => s + l.lineTotal);

  bool get isEmpty => lines.isEmpty;

  bool get hasMultipleChecks => checks.length > 1;

  @override
  List<Object?> get props => [checks, activeCheckId, lines, activeOrderTypeIndex];
}
