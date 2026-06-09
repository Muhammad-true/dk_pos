/// Маркер дозаказа строки на сервере (`orderLineFollowUp.js`).
const orderFollowUpLineKeyMarker = '~fu~';

/// Базовый ключ строки без суффикса дозаказа (`menuId~fu~2` → `menuId`).
String baseOrderLineKey(String lineKey) {
  final key = lineKey.trim();
  if (key.isEmpty) return key;
  final idx = key.indexOf(orderFollowUpLineKeyMarker);
  if (idx >= 0) return key.substring(0, idx);
  return key;
}

bool isFollowUpOrderLineKey(String lineKey) =>
    lineKey.contains(orderFollowUpLineKeyMarker);
