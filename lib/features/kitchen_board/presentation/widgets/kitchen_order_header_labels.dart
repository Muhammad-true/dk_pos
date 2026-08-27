import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';

bool kitchenOrderLooksLikeDelivery(LocalKitchenQueueOrder order) {
  final low = (order.orderType ?? '').trim().toLowerCase();
  if (low.contains('доставк') || low == 'delivery') return true;
  final label = order.tableLabel?.trim() ?? '';
  return label.isNotEmpty && tableLabelLooksLikeDelivery(label);
}

bool kitchenOrderLooksLikePickup(LocalKitchenQueueOrder order) {
  final low = (order.orderType ?? '').trim().toLowerCase();
  return low.contains('самовывоз') ||
      low.contains('с собой') ||
      low == 'pickup' ||
      low == 'takeaway' ||
      low == 'take_away' ||
      low == 'to_go';
}

/// Есть реальный стол зала/веранды — важнее старого типа «с собой».
bool kitchenHasHallTableLabel(LocalKitchenQueueOrder order) {
  if (kitchenOrderLooksLikeDelivery(order)) return false;
  final label = order.tableLabel?.trim() ?? '';
  if (label.isEmpty || tableLabelLooksLikeDelivery(label)) return false;
  return parsePosTableLabel(label).number != null;
}

/// Номер заказа с префиксом Д-/С- для кухни.
String kitchenOrderDisplayNumber(LocalKitchenQueueOrder order) {
  final number = order.number.trim();
  if (number.isEmpty) return number;
  if (kitchenOrderLooksLikeDelivery(order)) return 'Д-$number';
  // После назначения стола на «с собой» показываем обычный номер зала.
  if (kitchenHasHallTableLabel(order)) return number;
  if (kitchenOrderLooksLikePickup(order)) return 'С-$number';
  return number;
}

/// Крупная подпись типа: Доставка, Самовывоз, В зале.
String? kitchenOrderTypeHeadlineRu(LocalKitchenQueueOrder order) {
  if (kitchenOrderLooksLikeDelivery(order)) return 'Доставка';
  if (kitchenTableHeadlineRu(order) != null) return 'В зале';
  if (kitchenOrderLooksLikePickup(order)) return 'Самовывоз';
  final low = (order.orderType ?? '').trim().toLowerCase();
  if (low.contains('зал') ||
      low == 'hall' ||
      low.contains('стол') ||
      low == 'dine_in' ||
      low.contains('на месте')) {
    return 'В зале';
  }
  return null;
}

/// Крупная подпись стола для заказов в зале.
String? kitchenTableHeadlineRu(LocalKitchenQueueOrder order) {
  if (kitchenOrderLooksLikeDelivery(order)) return null;
  final label = order.tableLabel?.trim() ?? '';
  if (label.isEmpty || tableLabelLooksLikeDelivery(label)) return null;

  final parsed = parsePosTableLabel(label);
  if (parsed.number != null) {
    if (parsed.zone == PosTableZone.veranda) {
      return 'Веранда · стол ${parsed.number}';
    }
    if (parsed.zone == PosTableZone.hall) {
      return 'Зал · стол ${parsed.number}';
    }
    return 'Стол ${parsed.number}';
  }

  // Без распознанного номера стол не показываем для «с собой».
  if (kitchenOrderLooksLikePickup(order)) return null;

  if (label.length <= 28) return label;
  return null;
}
