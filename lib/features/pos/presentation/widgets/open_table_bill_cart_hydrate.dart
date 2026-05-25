import 'package:dk_pos/core/utils/cart_line_key.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/shared/shared.dart';

/// Результат подстановки открытого счёта в корзину (и база для дельты на сервер).
class OpenBillHydrateResult {
  const OpenBillHydrateResult({
    required this.cartLines,
    required this.baselineQtyByLineKey,
    required this.skippedLines,
    this.kitchenQtyLockedByLineKey = const {},
  });

  final Map<String, CartLine> cartLines;
  final Map<String, int> baselineQtyByLineKey;
  final int skippedLines;

  /// Ключ строки корзины → `true`, если позиция кухни уже в статусе «готово» (нельзя менять кол-во).
  final Map<String, bool> kitchenQtyLockedByLineKey;
}

PosMenuItem? findMenuItemById(List<PosCategory> roots, String id) {
  for (final c in roots) {
    for (final it in c.items) {
      if (it.id == id) return it;
    }
    final nested = findMenuItemById(c.children, id);
    if (nested != null) return nested;
  }
  return null;
}

String _priceTextForLine(double price) {
  final rounded = price.roundToDouble();
  if ((price - rounded).abs() < 0.000001) {
    return rounded.toStringAsFixed(0);
  }
  return price.toStringAsFixed(2);
}

/// Строки счёта с [PosTableBillLine.menuItemId] → строки корзины и снимок количеств (ключ как в [CartLine.lineKey]).
OpenBillHydrateResult hydrateOpenTableBillIntoCartLines({
  required List<PosCategory> menuRoots,
  required PosTableBill bill,
}) {
  final lines = <String, CartLine>{};
  var skipped = 0;
  final kitchenQtyLockedByLineKey = <String, bool>{};

  for (final bl in bill.lines) {
    final mid = bl.menuItemId?.trim();
    if (mid == null || mid.isEmpty) {
      skipped++;
      continue;
    }
    final template = findMenuItemById(menuRoots, mid);
    if (template == null) {
      skipped++;
      continue;
    }
    final up = bl.unitPrice ?? template.price;
    final item = template.copyWith(
      price: up,
      priceText: _priceTextForLine(up),
    );
    final key = computeCartLineKey(
      menuItemId: item.id,
      modifiers: const [],
      unitPrice: up,
      catalogBasePrice: template.baseCatalogPrice,
    );
    final isKitchen = bl.isKitchenLine;
    final st = (bl.kitchenLineStatus ?? '').toLowerCase().trim();
    final locked = isKitchen && st == 'ready';
    kitchenQtyLockedByLineKey[key] = locked;
    lines[key] = CartLine(item: item, quantity: bl.quantity);
  }

  final baseline = <String, int>{};
  for (final e in lines.entries) {
    baseline[e.key] = e.value.quantity;
  }

  return OpenBillHydrateResult(
    cartLines: lines,
    baselineQtyByLineKey: baseline,
    skippedLines: skipped,
    kitchenQtyLockedByLineKey: kitchenQtyLockedByLineKey,
  );
}
