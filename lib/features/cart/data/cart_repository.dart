import 'package:dk_pos/shared/shared.dart';

import '../bloc/cart_state.dart';

class _CheckData {
  _CheckData({required this.ordinal})
      : lines = <String, CartLine>{},
        orderTypeIndex = -1,
        tableLabel = null;

  final int ordinal;
  Map<String, CartLine> lines;
  int orderTypeIndex;
  String? tableLabel;
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

  String _lineKey(PosMenuItem item) => '${item.id}::${item.price.toStringAsFixed(2)}';

  void add(PosMenuItem item, {double? unitPrice}) {
    final d = _checks[_activeId];
    if (d == null) return;
    final effectiveItem = unitPrice != null
        ? item.copyWith(
            price: unitPrice,
            priceText: unitPrice.toStringAsFixed(
              unitPrice == unitPrice.roundToDouble() ? 0 : 2,
            ),
          )
        : item;
    final key = _lineKey(effectiveItem);
    final existing = d.lines[key];
    if (existing != null) {
      d.lines[key] = CartLine(item: effectiveItem, quantity: existing.quantity + 1);
    } else {
      d.lines[key] = CartLine(item: effectiveItem, quantity: 1);
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
      d.lines[lineKey] = CartLine(item: line.item, quantity: line.quantity - 1);
    }
  }

  void clearActive() {
    final d = _checks[_activeId];
    if (d == null) return;
    d.lines.clear();
    // После очистки/оформления требуем явный новый выбор типа заказа.
    d.orderTypeIndex = -1;
  }

  void resetAll() {
    _checks.clear();
    _nextOrdinal = 1;
    final id = _newId();
    _checks[id] = _CheckData(ordinal: _nextOrdinal++);
    _activeId = id;
  }
}
