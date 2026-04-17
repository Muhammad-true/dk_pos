int _parseInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class PosMenuItem {
  const PosMenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceText,
    required this.price,
    this.description,
    this.imagePath,
    this.saleUnit = 'шт',
    this.composition,
  });

  final String id;
  final int categoryId;
  final String name;
  final String priceText;
  final double price;
  final String? description;
  final String? imagePath;
  /// Единица продажи/учёта (шт, порц., л…) — для отображения и будущего склада.
  final String saleUnit;
  /// Состав (если задан в БД).
  final String? composition;

  factory PosMenuItem.fromJson(Map<String, dynamic> json) {
    final unit = json['sale_unit']?.toString().trim();
    return PosMenuItem(
      id: json['id']?.toString() ?? '',
      categoryId: _parseInt(json['category_id']),
      name: json['name']?.toString() ?? '',
      priceText: json['price_text']?.toString() ?? '',
      price: _parseDouble(json['price']),
      description: json['description']?.toString(),
      imagePath: json['image_path']?.toString(),
      saleUnit: (unit == null || unit.isEmpty) ? 'шт' : unit,
      composition: json['composition']?.toString(),
    );
  }
}

/// Узел каталога: подкатегории [children] и товары [items] на этом уровне.
class PosCategory {
  const PosCategory({
    required this.id,
    required this.name,
    this.subtitle,
    required this.sortOrder,
    this.children = const [],
    this.items = const [],
  });

  final int id;
  final String name;
  final String? subtitle;
  final int sortOrder;
  final List<PosCategory> children;
  final List<PosMenuItem> items;

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <PosMenuItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) {
          items.add(PosMenuItem.fromJson(e));
        }
      }
    }
    final rawChildren = json['children'];
    final children = <PosCategory>[];
    if (rawChildren is List) {
      for (final e in rawChildren) {
        if (e is Map<String, dynamic>) {
          children.add(PosCategory.fromJson(e));
        }
      }
    }
    return PosCategory(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      sortOrder: _parseInt(json['sort_order']),
      children: children,
      items: items,
    );
  }
}
