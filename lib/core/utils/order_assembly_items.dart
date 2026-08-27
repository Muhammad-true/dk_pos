import 'package:dk_pos/core/utils/order_line_key.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';

String _kitchenLineStatus(LocalKitchenQueueItem item) =>
    item.kitchenLineStatus.toLowerCase();

int _readyAtMs(LocalKitchenQueueItem item) {
  final raw = item.kitchenReadyAtIso?.trim();
  if (raw == null || raw.isEmpty) return 0;
  return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
}

bool wasOrderHandedOut({String? handedOutAtIso}) {
  final raw = handedOutAtIso?.trim();
  return raw != null && raw.isNotEmpty;
}

/// Есть признаки дозаказа по строкам.
bool isFollowUpAssemblyRound(List<LocalKitchenQueueItem> items) {
  if (items.isEmpty) return false;
  if (items.any((i) => isFollowUpOrderLineKey(i.lineKey ?? ''))) return true;
  final hasReady = items.any((i) => _kitchenLineStatus(i) == 'ready');
  final hasOpen = items.any(
    (i) => _kitchenLineStatus(i) == 'pending' || _kitchenLineStatus(i) == 'accepted',
  );
  return hasReady && hasOpen;
}

List<LocalKitchenQueueItem> _filterPostHandoutRoundItems(
  List<LocalKitchenQueueItem> items,
) {
  final hasFu = items.any((i) => isFollowUpOrderLineKey(i.lineKey ?? ''));

  if (hasFu) {
    final fuLines = items
        .where((i) => isFollowUpOrderLineKey(i.lineKey ?? ''))
        .toList(growable: false);
    final openLines = items
        .where(
          (i) =>
              _kitchenLineStatus(i) == 'pending' ||
              _kitchenLineStatus(i) == 'accepted',
        )
        .toList(growable: false);
    if (openLines.isNotEmpty) {
      final keys = {
        ...fuLines.map((i) => i.lineKey ?? ''),
        ...openLines.map((i) => i.lineKey ?? ''),
      };
      return items
          .where((i) => keys.contains(i.lineKey ?? ''))
          .toList(growable: false);
    }
    return fuLines.isNotEmpty ? fuLines : items;
  }

  final openLines = items
      .where((i) => _kitchenLineStatus(i) != 'ready')
      .toList(growable: false);
  if (openLines.isNotEmpty) return openLines;

  var maxMs = 0;
  for (final item in items) {
    final ms = _readyAtMs(item);
    if (ms > maxMs) maxMs = ms;
  }
  if (maxMs == 0) return items;

  final latest = items
      .where((i) => _readyAtMs(i) == maxMs)
      .toList(growable: false);
  return latest.isNotEmpty ? latest : items;
}

/// До первой выдачи — весь заказ; после выдачи — только новый круг дозаказа.
List<LocalKitchenQueueItem> filterAssemblyRoundItems(
  List<LocalKitchenQueueItem> items, {
  String? handedOutAtIso,
}) {
  if (items.isEmpty) return items;
  if (!wasOrderHandedOut(handedOutAtIso: handedOutAtIso)) return items;
  if (!isFollowUpAssemblyRound(items)) return items;
  return _filterPostHandoutRoundItems(items);
}

bool shouldShowFollowUpAssemblyLabel({
  required List<LocalKitchenQueueItem> items,
  String? handedOutAtIso,
}) {
  if (!wasOrderHandedOut(handedOutAtIso: handedOutAtIso)) return false;
  return isFollowUpAssemblyRound(items);
}
