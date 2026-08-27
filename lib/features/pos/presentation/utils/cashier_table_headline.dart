import 'package:flutter/material.dart';

import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';

/// Ярко-красный номер стола на карточках кассы.
const Color kCashierTableNumberRed = Color(0xFFC62828);

/// Краткий заголовок стола для шапки карточки кассы («Зал 7», «Без стола»).
String cashierTableHeadline(String? tableLabel) {
  final raw = (tableLabel ?? '').trim();
  if (raw.isEmpty) return 'Без стола';

  final parsed = parsePosTableLabel(raw);
  if (parsed.number != null) {
    final zone = parsed.zone;
    if (zone != null) return '${zone.shortLabel} ${parsed.number}';
    return 'Стол ${parsed.number}';
  }

  if (tableLabelLooksLikeDelivery(raw)) {
    return 'Доставка';
  }

  final low = raw.toLowerCase();
  if (low.contains('позже') || low == 'стол?' || low.contains('не указан')) {
    return 'Без стола';
  }

  // Уже короткая строка — показываем как есть.
  if (raw.length <= 18) return raw;
  return '${raw.substring(0, 16)}…';
}

/// Есть ли осмысленный номер стола (не «позже» / пусто).
bool cashierHasAssignedTable(String? tableLabel) {
  final raw = (tableLabel ?? '').trim();
  if (raw.isEmpty) return false;
  return parsePosTableLabel(raw).number != null;
}

Color cashierTableHeadlineColor(
  ColorScheme scheme, {
  required bool assigned,
}) {
  if (!assigned) return scheme.onSurfaceVariant;
  return kCashierTableNumberRed;
}
