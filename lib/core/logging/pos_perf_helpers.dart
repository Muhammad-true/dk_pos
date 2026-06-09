import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

String _cashierBoardOrderItemsSignature(LocalCashierBoardOrder row) {
  final parts = row.order.items
      .map(
        (it) =>
            '${it.menuItemId}:${it.quantity}:${it.kitchenLineStatus.trim().toLowerCase()}',
      )
      .toList(growable: false)
    ..sort();
  return parts.join(';');
}

/// Сигнатура списка заказов кассы — для пропуска лишних setState.
String cashierBoardSignature(List<LocalCashierBoardOrder> rows) {
  if (rows.isEmpty) return '';
  final buf = StringBuffer();
  for (final row in rows) {
    buf
      ..write(row.order.id)
      ..write(':')
      ..write(row.order.status)
      ..write(':')
      ..write(row.order.totalPrice)
      ..write(':')
      ..write(row.requiresPayment ? '1' : '0')
      ..write(':')
      ..write(row.needsCashierAck ? '1' : '0')
      ..write(':')
      ..write(_cashierBoardOrderItemsSignature(row))
      ..write('|');
  }
  return buf.toString();
}

bool kitchenSnapshotChanged(
  LocalKitchenQueueSnapshot prev,
  LocalKitchenQueueSnapshot next,
) {
  return _orderIds(prev.preparing) != _orderIds(next.preparing) ||
      _orderIds(prev.waitingOthers) != _orderIds(next.waitingOthers) ||
      _orderIds(prev.readyForPickup) != _orderIds(next.readyForPickup) ||
      _orderStatuses(prev.preparing) != _orderStatuses(next.preparing) ||
      _orderStatuses(prev.waitingOthers) != _orderStatuses(next.waitingOthers) ||
      _orderStatuses(prev.readyForPickup) != _orderStatuses(next.readyForPickup);
}

String _orderIds(List<LocalKitchenQueueOrder> rows) =>
    rows.map((e) => e.id).join(',');

String _orderStatuses(List<LocalKitchenQueueOrder> rows) =>
    rows.map((e) => '${e.id}:${e.status}').join(',');
