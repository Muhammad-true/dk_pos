import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

/// Разбор строки стола с кассы (`Зал • стол 3`, `Веранда • стол 17`, `Стол 5`).
({PosTableZone? zone, int? number}) parsePosTableLabel(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return (zone: null, number: null);

  final mZ = RegExp(
    r'^(Зал|Веранда)\s*•\s*стол\s*(\d+)\s*$',
    caseSensitive: false,
  ).firstMatch(s);
  if (mZ != null) {
    final z = mZ.group(1)!.toLowerCase();
    final zone = z.contains('веранд') ? PosTableZone.veranda : PosTableZone.hall;
    final n = int.tryParse(mZ.group(2)!);
    return (zone: zone, number: n);
  }

  final mS = RegExp(r'^Стол\s*(\d+)\s*$', caseSensitive: false).firstMatch(s);
  if (mS != null) {
    final n = int.tryParse(mS.group(1)!);
    return (zone: PosTableZone.hall, number: n);
  }

  return (zone: null, number: null);
}
