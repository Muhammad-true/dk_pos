import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

/// Патч общей очереди (ТВ / QueueBoard) из WS `tvQueuePatches`.
class LocalTvDisplayQueuePatch {
  const LocalTvDisplayQueuePatch({
    required this.orderId,
    this.preparing,
    this.ready,
    this.removeFromPreparing = false,
    this.removeFromReady = false,
  });

  final String orderId;
  final LocalKitchenQueueOrder? preparing;
  final LocalKitchenQueueOrder? ready;
  final bool removeFromPreparing;
  final bool removeFromReady;

  static LocalTvDisplayQueuePatch? tryParse(Map<String, dynamic> json) {
    final orderId =
        json['orderId']?.toString() ?? json['order_id']?.toString() ?? '';
    if (orderId.isEmpty) return null;

    LocalKitchenQueueOrder? parseOrder(dynamic raw) {
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);
      return LocalKitchenQueueOrder.fromJson(map);
    }

    return LocalTvDisplayQueuePatch(
      orderId: orderId,
      preparing: parseOrder(json['preparing']),
      ready: parseOrder(json['ready']),
      removeFromPreparing: json['removeFromPreparing'] == true ||
          json['remove_from_preparing'] == true,
      removeFromReady:
          json['removeFromReady'] == true || json['remove_from_ready'] == true,
    );
  }
}

List<LocalTvDisplayQueuePatch> parseTvDisplayQueuePatches(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => LocalTvDisplayQueuePatch.tryParse(Map<String, dynamic>.from(e)))
      .whereType<LocalTvDisplayQueuePatch>()
      .toList(growable: false);
}

List<LocalKitchenQueueOrder> _applySection(
  List<LocalKitchenQueueOrder> current,
  List<LocalTvDisplayQueuePatch> patches, {
  required bool preparingSection,
}) {
  if (patches.isEmpty) return current;
  var list = List<LocalKitchenQueueOrder>.from(current);
  for (final patch in patches) {
    final orderId = patch.orderId;
    final remove =
        preparingSection ? patch.removeFromPreparing : patch.removeFromReady;
    if (remove) {
      list = list.where((o) => o.id != orderId).toList(growable: false);
    }
    final upsert = preparingSection ? patch.preparing : patch.ready;
    if (upsert != null && upsert.id.isNotEmpty) {
      final idx = list.indexWhere((o) => o.id == upsert.id);
      if (idx >= 0) {
        list[idx] = upsert;
      } else {
        list = [...list, upsert];
      }
    }
  }
  return list;
}

/// Применяет `tvQueuePatches` к снимку общей очереди (preparing / ready).
LocalKitchenQueueSnapshot applyTvDisplayQueuePatches(
  LocalKitchenQueueSnapshot snapshot,
  List<LocalTvDisplayQueuePatch> patches, {
  int? queueRevision,
}) {
  if (patches.isEmpty) return snapshot;
  return LocalKitchenQueueSnapshot(
    preparing: _applySection(
      snapshot.preparing,
      patches,
      preparingSection: true,
    ),
    waitingOthers: snapshot.waitingOthers,
    readyForPickup: _applySection(
      snapshot.readyForPickup,
      patches,
      preparingSection: false,
    ),
    queueRevision: queueRevision ?? snapshot.queueRevision,
  );
}
