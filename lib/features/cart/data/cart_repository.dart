import 'package:dk_pos/core/utils/cart_line_key.dart';
import 'package:dk_pos/core/utils/variable_sale_qty.dart';
import 'package:dk_pos/shared/shared.dart';

import '../bloc/cart_state.dart';
import '../domain/cart_payment_adjustment.dart';

class _CheckData {
  _CheckData({required this.ordinal})
      : lines = <String, CartLine>{},
        orderTypeIndex = -1,
        tableLabel = null,
        paymentAdjustment = null;

  final int ordinal;
  Map<String, CartLine> lines;
  int orderTypeIndex;
  String? tableLabel;
  CartPaymentAdjustment? paymentAdjustment;
}

/// Локальная корзина: несколько открытых чеков (вкладок), один активный.
class CartRepository {
  CartRepository() {
    final id = _newId();
    _checks[id] = _CheckData(ordinal: _nextOrdinal++);
    _activeId = id;
  }

  final Map<String, _CheckData> _checks = {};
  String _activeId = '';
  int _nextOrdinal = 1;

  String _newId() => 'ck-${DateTime.now().microsecondsSinceEpoch}';

  String get activeCheckId => _activeId;

  Map<String, CartLine> get activeLines =>
      Map<String, CartLine>.from(_checks[_activeId]?.lines ?? {});

  int get activeOrderTypeIndex => _checks[_activeId]?.orderTypeIndex ?? -1;

  CartPaymentAdjustment? get activePaymentAdjustment =>
      _checks[_activeId]?.paymentAdjustment;

  void setPaymentAdjustmentForActive(CartPaymentAdjustment? value) {
    final d = _checks[_activeId];
    if (d == null) return;
    d.paymentAdjustment = value;
  }

  List<CartCheckInfo> get checkSummaries {
    final list = <CartCheckInfo>[];
    for (final e in _checks.entries) {
      final d = e.value;
      final n = d.lines.values.fold<int>(0, (s, l) => s + l.quantity);
      list.add(CartCheckInfo(
        id: e.key,
        ordinal: d.ordinal,
        tableLabel: d.tableLabel,
        itemCount: n,
      ));
    }
    list.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return list;
  }

  void switchCheck(String id) {
    if (_checks.containsKey(id)) {
      _activeId = id;
    }
  }

  /// Новый пустой чек, переключение на него.
  void createCheck() {
    final id = _newId();
    _checks[id] = _CheckData(ordinal: _nextOrdinal++);
    _activeId = id;
  }

  /// Удалить чек. Нельзя удалить последний. Возвращает `false`, если отказ.
  bool removeCheck(String id) {
    if (_checks.length <= 1) return false;
    if (!_checks.containsKey(id)) return false;
    _checks.remove(id);
    if (_activeId == id) {
      _activeId = _checks.keys.first;
    }
    return true;
  }

  void setTableLabelForActive(String? label) {
    final d = _checks[_activeId];
    if (d == null) return;
    d.tableLabel = label;
  }

  void setOrderTypeIndexForActive(int index) {
    final d = _checks[_activeId];
    if (d == null) return;
    d.orderTypeIndex = index.clamp(-1, 2);
  }

  void add(
    PosMenuItem item, {
    double? unitPrice,
    List<PosCartModifier> modifiers = const [],
    double? actualQty,
    double? defaultSaleQty,
    String? saleMeasure,
  }) {
    final d = _checks[_activeId];
    if (d == null) return;

    final modExtra =
        modifiers.fold<double>(0, (s, m) => s + m.priceDelta);
    final sale = item.variableSaleQtyEnabled
        ? VariableSaleQty.fromMenuItem(
            enabled: true,
            measure: saleMeasure ?? item.saleMeasure,
            defaultQty: defaultSaleQty ?? item.defaultSaleQty,
            actualQty: actualQty,
          )
        : null;
    final up = unitPrice ??
        ((sale != null ? sale.scaledPrice(item.baseCatalogPrice) : item.baseCatalogPrice) +
            modExtra);

    final effectiveItem = item.copyWith(
      price: up,
      priceText: up == up.roundToDouble()
          ? up.toStringAsFixed(0)
          : up.toStringAsFixed(2),
    );

    final key = computeCartLineKey(
      menuItemId: item.id,
      modifiers: modifiers,
      unitPrice: up,
      catalogBasePrice: item.baseCatalogPrice,
      actualQty: sale?.actualQty,
      defaultSaleQty: sale?.defaultQty,
    );

    final existing = d.lines[key];
    if (existing != null) {
      d.lines[key] = CartLine(
        item: effectiveItem,
        quantity: existing.quantity + 1,
        modifiers: modifiers,
        saleMeasure: sale?.measure,
        defaultSaleQty: sale?.defaultQty,
        actualQty: sale?.actualQty,
      );
    } else {
      d.lines[key] = CartLine(
        item: effectiveItem,
        quantity: 1,
        modifiers: modifiers,
        saleMeasure: sale?.measure,
        defaultSaleQty: sale?.defaultQty,
        actualQty: sale?.actualQty,
      );
    }
  }

  void decrement(String lineKey) {
    final d = _checks[_activeId];
    if (d == null) return;
    final line = d.lines[lineKey];
    if (line == null) return;
    if (line.quantity <= 1) {
      d.lines.remove(lineKey);
    } else {
      d.lines[lineKey] = CartLine(
        item: line.item,
        quantity: line.quantity - 1,
        modifiers: line.modifiers,
        saleMeasure: line.saleMeasure,
        defaultSaleQty: line.defaultSaleQty,
        actualQty: line.actualQty,
      );
    }
  }

  void clearActive() {
    final d = _checks[_activeId];
    if (d == null) return;
    d.lines.clear();
    d.orderTypeIndex = -1;
    d.paymentAdjustment = null;
  }

  void replaceActiveLines(Map<String, CartLine> lines) {
    final d = _checks[_activeId];
    if (d == null) return;
    d.lines
      ..clear()
      ..addAll(lines);
  }

  void resetAll() {
    _checks.clear();
    _nextOrdinal = 1;
    final id = _newId();
    _checks[id] = _CheckData(ordinal: _nextOrdinal++);
    _activeId = id;
  }
}
