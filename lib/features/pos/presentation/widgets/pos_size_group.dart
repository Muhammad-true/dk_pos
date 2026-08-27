import 'package:dk_pos/shared/shared.dart';

/// Хвост размера в имени: «Маргарита 25 см» → base + label.
final _sizeTailRe = RegExp(
  r'^(.*?)\s+(25|30|35)\s*(?:см|cm)?\s*$',
  caseSensitive: false,
);

class PosSizeTail {
  const PosSizeTail({required this.baseName, required this.sizeLabel, required this.sizeCm});

  final String baseName;
  final String sizeLabel;
  final int sizeCm;
}

PosSizeTail? parsePosSizeTail(String name) {
  final m = _sizeTailRe.firstMatch(name.trim());
  if (m == null) return null;
  final base = (m.group(1) ?? '').trim();
  if (base.isEmpty) return null;
  final cm = int.tryParse(m.group(2) ?? '');
  if (cm == null) return null;
  return PosSizeTail(baseName: base, sizeLabel: '$cm см', sizeCm: cm);
}

/// Одна плитка каталога: одиночный товар или группа размеров.
class PosCatalogTile {
  PosCatalogTile.single(PosMenuItem item)
      : sizes = [item],
        baseName = item.name;

  PosCatalogTile.group({
    required this.baseName,
    required this.sizes,
  }) : assert(sizes.length >= 2);

  final String baseName;
  final List<PosMenuItem> sizes;

  bool get isGroup => sizes.length >= 2;

  PosMenuItem get representative => sizes.first;

  /// Карточка для сетки: имя без размера, цена «от min».
  PosMenuItem get displayItem {
    if (!isGroup) return representative;
    final minP = sizes.map((e) => e.price).reduce((a, b) => a < b ? a : b);
    final minText = sizes
        .where((e) => e.price == minP)
        .map((e) => e.priceText)
        .firstWhere((t) => t.trim().isNotEmpty, orElse: () => minP.toStringAsFixed(0));
    return representative.copyWith(
      name: baseName,
      price: minP,
      priceText: 'от $minText',
    );
  }
}

/// Группирует товары одной категории по базовому имени + 25/30/35.
List<PosCatalogTile> groupPosMenuItems(List<PosMenuItem> items) {
  if (items.isEmpty) return const [];
  final singles = <PosMenuItem>[];
  final buckets = <String, List<({PosMenuItem item, PosSizeTail tail})>>{};

  for (final item in items) {
    final tail = parsePosSizeTail(item.name);
    if (tail == null) {
      singles.add(item);
      continue;
    }
    final key = '${item.categoryId}\t${tail.baseName.toLowerCase()}';
    buckets.putIfAbsent(key, () => []).add((item: item, tail: tail));
  }

  final out = <PosCatalogTile>[];
  final usedIds = <String>{};

  for (final item in items) {
    if (usedIds.contains(item.id)) continue;
    final tail = parsePosSizeTail(item.name);
    if (tail == null) {
      usedIds.add(item.id);
      out.add(PosCatalogTile.single(item));
      continue;
    }
    final key = '${item.categoryId}\t${tail.baseName.toLowerCase()}';
    final bucket = buckets[key] ?? [];
    if (bucket.length < 2) {
      usedIds.add(item.id);
      out.add(PosCatalogTile.single(item));
      continue;
    }
    bucket.sort((a, b) => a.tail.sizeCm.compareTo(b.tail.sizeCm));
    for (final e in bucket) {
      usedIds.add(e.item.id);
    }
    out.add(
      PosCatalogTile.group(
        baseName: tail.baseName,
        sizes: bucket.map((e) => e.item).toList(),
      ),
    );
  }
  return out;
}
