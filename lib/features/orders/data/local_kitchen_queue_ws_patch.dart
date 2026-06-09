import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

/// Патч одного заказа для станции кухни из WS `kitchen.queue_changed`.
class LocalKitchenStationPatch {
  const LocalKitchenStationPatch({
    required this.orderId,
    required this.kitchenStationId,
    this.preparing,
    this.waitingOthers,
    this.removeFromPreparing = false,
    this.removeFromWaiting = false,
  });

  final String orderId;
  final int kitchenStationId;
  final LocalKitchenQueueOrder? preparing;
  final LocalKitchenQueueOrder? waitingOthers;
  final bool removeFromPreparing;
  final bool removeFromWaiting;

  static LocalKitchenStationPatch? tryParse(Map<String, dynamic> json) {
    final orderId = json['orderId']?.toString() ?? json['order_id']?.toString() ?? '';
    if (orderId.isEmpty) return null;
    final stationRaw = json['kitchenStationId'] ?? json['kitchen_station_id'];
    final stationId = stationRaw is int
        ? stationRaw
        : int.tryParse(stationRaw?.toString() ?? '') ?? 0;

    LocalKitchenQueueOrder? parseOrder(dynamic raw) {
      if (raw is! Map<String, dynamic>) return null;
      return LocalKitchenQueueOrder.fromJson(raw);
    }

    return LocalKitchenStationPatch(
      orderId: orderId,
      kitchenStationId: stationId,
      preparing: parseOrder(json['preparing']),
      waitingOthers: parseOrder(json['waitingOthers'] ?? json['waiting_others']),
      removeFromPreparing:
          json['removeFromPreparing'] == true || json['remove_from_preparing'] == true,
      removeFromWaiting:
          json['removeFromWaiting'] == true || json['remove_from_waiting'] == true,
    );
  }
}

List<LocalKitchenStationPatch> parseKitchenStationPatches(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(LocalKitchenStationPatch.tryParse)
      .whereType<LocalKitchenStationPatch>()
      .toList(growable: false);
}

List<LocalKitchenStationPatch> kitchenStationPatchesForUser({
  required List<LocalKitchenStationPatch> patches,
  required int? kitchenStationId,
}) {
  if (kitchenStationId == null || kitchenStationId < 1) return const [];
  return patches
      .where(
        (p) => p.kitchenStationId <= 0 || p.kitchenStationId == kitchenStationId,
      )
      .toList(growable: false);
}

LocalKitchenQueueSnapshot applyKitchenStationPatches(
  LocalKitchenQueueSnapshot snapshot,
  List<LocalKitchenStationPatch> patches,
) {
  if (patches.isEmpty) return snapshot;

  var preparing = List<LocalKitchenQueueOrder>.from(snapshot.preparing);
  var waitingOthers = List<LocalKitchenQueueOrder>.from(snapshot.waitingOthers);

  for (final patch in patches) {
    final orderId = patch.orderId;
    if (patch.removeFromPreparing) {
      preparing = preparing.where((o) => o.id != orderId).toList(growable: false);
    }
    if (patch.removeFromWaiting) {
      waitingOthers =
          waitingOthers.where((o) => o.id != orderId).toList(growable: false);
    }
    final prep = patch.preparing;
    if (prep != null) {
      preparing = _upsertKitchenQueueOrder(preparing, prep);
      waitingOthers =
          waitingOthers.where((o) => o.id != orderId).toList(growable: false);
    }
    final wait = patch.waitingOthers;
    if (wait != null) {
      waitingOthers = _upsertKitchenQueueOrder(waitingOthers, wait);
      preparing = preparing.where((o) => o.id != orderId).toList(growable: false);
    }
  }

  return LocalKitchenQueueSnapshot(
    preparing: preparing,
    waitingOthers: waitingOthers,
    readyForPickup: snapshot.readyForPickup,
  );
}

List<LocalKitchenQueueOrder> _upsertKitchenQueueOrder(
  List<LocalKitchenQueueOrder> list,
  LocalKitchenQueueOrder order,
) {
  final idx = list.indexWhere((o) => o.id == order.id);
  if (idx >= 0) {
    final next = List<LocalKitchenQueueOrder>.from(list);
    next[idx] = order;
    return next;
  }
  return [...list, order];
}

String _kitchenItemsSignature(LocalKitchenQueueOrder order) {
  final parts = order.items
      .map(
        (e) =>
            '${e.lineKey ?? e.menuItemId}:${e.quantity}:${e.kitchenLineStatus.trim().toLowerCase()}',
      )
      .toList(growable: false)
    ..sort();
  return parts.join(';');
}

/// Сравнение очереди с учётом статусов строк (для WS-патчей и озвучки).
bool kitchenSnapshotItemsChanged(
  LocalKitchenQueueSnapshot prev,
  LocalKitchenQueueSnapshot next,
) {
  bool sectionChanged(
    List<LocalKitchenQueueOrder> a,
    List<LocalKitchenQueueOrder> b,
  ) {
    if (a.length != b.length) return true;
    final bById = {for (final o in b) o.id: o};
    for (final o in a) {
      final other = bById[o.id];
      if (other == null) return true;
      if (o.status != other.status) return true;
      if (_kitchenItemsSignature(o) != _kitchenItemsSignature(other)) return true;
    }
    return false;
  }

  return sectionChanged(prev.preparing, next.preparing) ||
      sectionChanged(prev.waitingOthers, next.waitingOthers) ||
      sectionChanged(prev.readyForPickup, next.readyForPickup);
}
