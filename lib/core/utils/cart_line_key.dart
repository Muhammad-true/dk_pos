import 'package:dk_pos/shared/models/pos_menu_models.dart';

/// Ключ строки заказа/корзины (как `computeOrderLineKey` в POS backend).
String computeCartLineKey({
  required String menuItemId,
  required List<PosCartModifier> modifiers,
  required double unitPrice,
  required double catalogBasePrice,
}) {
  final mid = menuItemId.trim();
  final ids = modifiers
      .map((m) => m.optionId)
      .where((id) => id > 0)
      .toList()
    ..sort();
  if (ids.isNotEmpty) {
    return '$mid:${ids.join(',')}';
  }
  if ((unitPrice - catalogBasePrice).abs() > 0.001) {
    return '$mid::${unitPrice.toStringAsFixed(2)}';
  }
  return mid;
}
