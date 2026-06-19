import 'package:dk_pos/shared/models/pos_menu_models.dart';

/// Ключ строки заказа/корзины (как `computeOrderLineKey` в POS backend).
String computeCartLineKey({
  required String menuItemId,
  required List<PosCartModifier> modifiers,
  required double unitPrice,
  required double catalogBasePrice,
  double? actualQty,
  double? defaultSaleQty,
}) {
  final mid = menuItemId.trim();
  final ids = modifiers
      .map((m) => m.optionId)
      .where((id) => id > 0)
      .toList()
    ..sort();
  var key = ids.isNotEmpty ? '$mid:${ids.join(',')}' : mid;
  if ((unitPrice - catalogBasePrice).abs() > 0.001 && ids.isEmpty) {
    key = '$mid::${unitPrice.toStringAsFixed(2)}';
  }
  final a = actualQty;
  final d = defaultSaleQty;
  if (a != null && d != null && d > 0 && (a - d).abs() > 0.001) {
    key = '$key@q${a.toStringAsFixed(a == a.roundToDouble() ? 0 : 2)}';
  }
  return key;
}
