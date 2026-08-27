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
      if (raw is! Map) return null;
      return LocalKitchenQueueOrder.fromJson(Map<String, dynamic>.from(raw));
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
      .whereType<Map>()
      .map((e) => LocalKitchenStationPatch.tryParse(Map<String, dynamic>.from(e)))
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
    queueRevision: snapshot.queueRevision,
  );
}

bool _kitchenItemHasSaleQtyFields(LocalKitchenQueueItem item) {
  final m = (item.saleMeasure ?? '').trim().toLowerCase();
  return item.actualQty != null &&
      item.actualQty! > 0 &&
      (m == 'pcs' || m == 'gram' || m == 'g');
}

LocalKitchenQueueItem _mergeKitchenQueueItem(
  LocalKitchenQueueItem? prev,
  LocalKitchenQueueItem incoming,
) {
  if (prev == null) return incoming;
  if (_kitchenItemHasSaleQtyFields(incoming)) return incoming;
  if (!_kitchenItemHasSaleQtyFields(prev)) return incoming;
  // Порция из прошлого снимка; имя берём с сервера, если оно уже с количеством.
  final keepName = _kitchenItemDisplayNameIsBetter(incoming.name, prev.name)
      ? incoming.name
      : prev.name;
  return LocalKitchenQueueItem(
    menuItemId: incoming.menuItemId,
    name: keepName,
    quantity: incoming.quantity,
    lineKey: incoming.lineKey ?? prev.lineKey,
    saleMeasure: prev.saleMeasure ?? incoming.saleMeasure,
    actualQty: prev.actualQty ?? incoming.actualQty,
    defaultSaleQty: prev.defaultSaleQty ?? incoming.defaultSaleQty,
    kitchenLineStatus: incoming.kitchenLineStatus,
    kitchenAcceptedByUserId: incoming.kitchenAcceptedByUserId,
    kitchenAcceptedByUsername: incoming.kitchenAcceptedByUsername,
    kitchenAcceptedAtIso: incoming.kitchenAcceptedAtIso,
    kitchenReadyByUserId: incoming.kitchenReadyByUserId,
    kitchenReadyByUsername: incoming.kitchenReadyByUsername,
    kitchenReadyAtIso: incoming.kitchenReadyAtIso,
    kitchenStationId: incoming.kitchenStationId ?? prev.kitchenStationId,
    kitchenStationName: incoming.kitchenStationName ?? prev.kitchenStationName,
  );
}

LocalKitchenQueueOrder _mergeKitchenQueueOrder(
  LocalKitchenQueueOrder prev,
  LocalKitchenQueueOrder incoming,
) {
  final prevByKey = <String, LocalKitchenQueueItem>{
    for (final item in prev.items)
      (item.lineKey ?? item.menuItemId): item,
  };
  final mergedItems = incoming.items
      .map(
        (item) => _mergeKitchenQueueItem(
          prevByKey[item.lineKey ?? item.menuItemId],
          item,
        ),
      )
      .toList(growable: false);
  return LocalKitchenQueueOrder(
    id: incoming.id,
    number: incoming.number.isNotEmpty ? incoming.number : prev.number,
    // Смена/сброс стола с кассы: всегда берём значение из патча (null = стол снят).
    orderType: incoming.orderType ?? prev.orderType,
    tableLabel: incoming.tableLabel,
    status: incoming.status,
    totalPrice: incoming.totalPrice,
    items: mergedItems,
    handOutSource: incoming.handOutSource ?? prev.handOutSource,
    handedOutAtIso: incoming.handedOutAtIso ?? prev.handedOutAtIso,
  );
}

List<LocalKitchenQueueOrder> _upsertKitchenQueueOrder(
  List<LocalKitchenQueueOrder> list,
  LocalKitchenQueueOrder order,
) {
  final idx = list.indexWhere((o) => o.id == order.id);
  if (idx >= 0) {
    final next = List<LocalKitchenQueueOrder>.from(list);
    next[idx] = _mergeKitchenQueueOrder(list[idx], order);
    return next;
  }
  return [...list, order];
}

String _kitchenItemsSignature(LocalKitchenQueueOrder order) {
  final parts = order.items
      .map(
        (e) =>
            '${e.lineKey ?? e.menuItemId}:${e.quantity}:${e.actualQty ?? ''}:${e.saleMeasure ?? ''}:${e.name}:${e.kitchenLineStatus.trim().toLowerCase()}',
      )
      .toList(growable: false)
    ..sort();
  return parts.join(';');
}

bool _kitchenItemDisplayNameIsBetter(String incoming, String prev) {
  final a = incoming.trim();
  final b = prev.trim();
  if (a.isEmpty) return false;
  if (b.isEmpty) return true;
  if (RegExp(r'^\d+\s*[×xх]\s', caseSensitive: false).hasMatch(a)) {
    return true;
  }
  if (RegExp(r'\d+\s*(шт|штук|pcs|г|g)\s*$', caseSensitive: false).hasMatch(a)) {
    return true;
  }
  return a.length > b.length;
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
      // Смена стола с кассы — только tableLabel, позиции те же.
      if ((o.tableLabel ?? '') != (other.tableLabel ?? '')) return true;
      if ((o.orderType ?? '') != (other.orderType ?? '')) return true;
      if ((o.number) != (other.number)) return true;
      if (_kitchenItemsSignature(o) != _kitchenItemsSignature(other)) return true;
    }
    return false;
  }

  return sectionChanged(prev.preparing, next.preparing) ||
      sectionChanged(prev.waitingOthers, next.waitingOthers) ||
      sectionChanged(prev.readyForPickup, next.readyForPickup);
}
