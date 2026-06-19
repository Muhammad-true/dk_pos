import 'package:dk_pos/core/utils/variable_sale_qty.dart';

int _parseInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// Выбранный модификатор в корзине (как на сайте).
class PosCartModifier {
  const PosCartModifier({
    required this.optionId,
    required this.name,
    required this.priceDelta,
  });

  final int optionId;
  final String name;
  final double priceDelta;

  Map<String, dynamic> toJson() => {
        'option_id': optionId,
        'name': name,
        'price_delta': priceDelta,
      };
}

class PosModifierOption {
  const PosModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
  });

  final int id;
  final String name;
  final double priceDelta;

  factory PosModifierOption.fromJson(Map<String, dynamic> json) {
    return PosModifierOption(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      priceDelta: _parseDouble(json['price_delta']),
    );
  }
}

class PosModifierGroup {
  const PosModifierGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.maxSelect,
    required this.options,
  });

  final int id;
  final String name;
  final String kind;
  final int maxSelect;
  final List<PosModifierOption> options;

  factory PosModifierGroup.fromJson(Map<String, dynamic> json) {
    final optsRaw = json['options'];
    final options = <PosModifierOption>[];
    if (optsRaw is List) {
      for (final o in optsRaw) {
        if (o is Map<String, dynamic>) {
          final parsed = PosModifierOption.fromJson(o);
          if (parsed.id > 0) options.add(parsed);
        }
      }
    }
    return PosModifierGroup(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      kind: (json['kind']?.toString() ?? 'add').toLowerCase(),
      maxSelect: _parseInt(json['max_select']) > 0
          ? _parseInt(json['max_select'])
          : ((json['kind']?.toString() == 'remove') ? 3 : 5),
      options: options,
    );
  }
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
    this.allowCustomPrice = false,
    this.variableSaleQtyEnabled = false,
    this.saleMeasure,
    this.defaultSaleQty,
    this.modifierGroups = const [],
    this.catalogBasePrice,
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
  /// Разрешен ручной ввод цены на кассе.
  final bool allowCustomPrice;
  final bool variableSaleQtyEnabled;
  final String? saleMeasure;
  final double? defaultSaleQty;
  final List<PosModifierGroup> modifierGroups;

  /// Базовая цена из каталога (для ключа строки при ручной цене).
  final double? catalogBasePrice;

  double get baseCatalogPrice => catalogBasePrice ?? price;

  bool get hasModifiers =>
      modifierGroups.any((g) => g.options.isNotEmpty);

  VariableSaleQty get variableSale =>
      VariableSaleQty.fromMenuItem(
        enabled: variableSaleQtyEnabled,
        measure: saleMeasure,
        defaultQty: defaultSaleQty,
      );

  PosMenuItem copyWith({
    String? id,
    int? categoryId,
    String? name,
    String? priceText,
    double? price,
    String? description,
    String? imagePath,
    String? saleUnit,
    String? composition,
    bool? allowCustomPrice,
    bool? variableSaleQtyEnabled,
    String? saleMeasure,
    double? defaultSaleQty,
    List<PosModifierGroup>? modifierGroups,
    double? catalogBasePrice,
  }) {
    return PosMenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priceText: priceText ?? this.priceText,
      price: price ?? this.price,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      saleUnit: saleUnit ?? this.saleUnit,
      composition: composition ?? this.composition,
      allowCustomPrice: allowCustomPrice ?? this.allowCustomPrice,
      variableSaleQtyEnabled:
          variableSaleQtyEnabled ?? this.variableSaleQtyEnabled,
      saleMeasure: saleMeasure ?? this.saleMeasure,
      defaultSaleQty: defaultSaleQty ?? this.defaultSaleQty,
      modifierGroups: modifierGroups ?? this.modifierGroups,
      catalogBasePrice: catalogBasePrice ?? this.catalogBasePrice,
    );
  }

  factory PosMenuItem.fromJson(Map<String, dynamic> json) {
    final unit = json['sale_unit']?.toString().trim();
    final price = _parseDouble(json['price']);
    final groupsRaw = json['modifier_groups'];
    final groups = <PosModifierGroup>[];
    if (groupsRaw is List) {
      for (final g in groupsRaw) {
        if (g is Map<String, dynamic>) {
          final parsed = PosModifierGroup.fromJson(g);
          if (parsed.options.isNotEmpty) groups.add(parsed);
        }
      }
    }
    return PosMenuItem(
      id: json['id']?.toString() ?? '',
      categoryId: _parseInt(json['category_id']),
      name: json['name']?.toString() ?? '',
      priceText: json['price_text']?.toString() ?? '',
      price: price,
      description: json['description']?.toString(),
      imagePath: json['image_path']?.toString(),
      saleUnit: (unit == null || unit.isEmpty) ? 'шт' : unit,
      composition: json['composition']?.toString(),
      allowCustomPrice:
          json['allow_custom_price'] == 1 || json['allowCustomPrice'] == true,
      variableSaleQtyEnabled:
          json['variable_sale_qty_enabled'] == 1 ||
          json['variableSaleQtyEnabled'] == true,
      saleMeasure: json['sale_measure']?.toString(),
      defaultSaleQty: () {
        final raw = json['default_sale_qty'];
        if (raw == null) return null;
        final n = VariableSaleQty.parseQty(raw, -1);
        return n > 0 ? n : null;
      }(),
      modifierGroups: groups,
      catalogBasePrice: price,
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
      final seenIds = <String>{};
      for (final e in rawItems) {
        if (e is Map<String, dynamic>) {
          final parsed = PosMenuItem.fromJson(e);
          final id = parsed.id.trim();
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          items.add(parsed);
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
