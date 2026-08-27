import 'package:flutter/material.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_size_group.dart';
import 'package:dk_pos/shared/shared.dart';

enum CustomerDisplayViewMode { idle, menu, payment }

CustomerDisplayViewMode parseCustomerDisplayViewMode(String? raw) {
  return CustomerDisplayViewMode.values.asNameMap()[raw?.trim()] ??
      CustomerDisplayViewMode.idle;
}

class CustomerDisplayThemeSnapshot {
  const CustomerDisplayThemeSnapshot({
    this.mode = PosScreenTheme.light,
    this.accentColor = const Color(0xFFE4002B),
  });

  final PosScreenTheme mode;
  final Color accentColor;

  Map<String, dynamic> toJson() => {
        'mode': mode == PosScreenTheme.dark ? 'dark' : 'light',
        'accentHex': encodeColorHex(accentColor),
      };

  factory CustomerDisplayThemeSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerDisplayThemeSnapshot();
    final mode = json['mode']?.toString().trim() == 'dark'
        ? PosScreenTheme.dark
        : PosScreenTheme.light;
    return CustomerDisplayThemeSnapshot(
      mode: mode,
      accentColor: parseCustomAccentColor(json['accentHex']?.toString()),
    );
  }

  factory CustomerDisplayThemeSnapshot.fromPosTheme(PosThemeSettings settings) {
    return CustomerDisplayThemeSnapshot(
      mode: settings.mode,
      accentColor: settings.accentColor,
    );
  }
}

class CustomerDisplayMenuSnapshot {
  const CustomerDisplayMenuSnapshot({
    this.breadcrumb = const [],
    this.pathIds = const [],
    this.rootCategories = const [],
    this.categories = const [],
    this.products = const [],
    this.catalogScrollOffset = 0,
    this.catalogScrollProgress = 0,
    this.catalogScrollIndex = 0,
    this.categoryScrollProgress = 0,
  });

  final List<String> breadcrumb;
  final List<int> pathIds;
  final List<CustomerDisplayMenuCategoryData> rootCategories;
  final List<CustomerDisplayMenuCategoryData> categories;
  final List<CustomerDisplayMenuProductData> products;
  final double catalogScrollOffset;

  /// Доля прокрутки каталога кассы 0..1 (главный способ синхронизации).
  final double catalogScrollProgress;

  /// Индекс первого видимого товара на кассе (для точного совпадения).
  final int catalogScrollIndex;

  /// Доля прокрутки корневых категорий кассы 0..1.
  final double categoryScrollProgress;

  bool get isEmpty =>
      breadcrumb.isEmpty &&
      rootCategories.isEmpty &&
      categories.isEmpty &&
      products.isEmpty;

  CustomerDisplayMenuSnapshot copyWith({
    List<String>? breadcrumb,
    List<int>? pathIds,
    List<CustomerDisplayMenuCategoryData>? rootCategories,
    List<CustomerDisplayMenuCategoryData>? categories,
    List<CustomerDisplayMenuProductData>? products,
    double? catalogScrollOffset,
    double? catalogScrollProgress,
    int? catalogScrollIndex,
    double? categoryScrollProgress,
  }) {
    return CustomerDisplayMenuSnapshot(
      breadcrumb: breadcrumb ?? this.breadcrumb,
      pathIds: pathIds ?? this.pathIds,
      rootCategories: rootCategories ?? this.rootCategories,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      catalogScrollOffset: catalogScrollOffset ?? this.catalogScrollOffset,
      catalogScrollProgress:
          catalogScrollProgress ?? this.catalogScrollProgress,
      catalogScrollIndex: catalogScrollIndex ?? this.catalogScrollIndex,
      categoryScrollProgress:
          categoryScrollProgress ?? this.categoryScrollProgress,
    );
  }

  Map<String, dynamic> toJson() => {
        'breadcrumb': breadcrumb,
        'pathIds': pathIds,
        'rootCategories': rootCategories.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'products': products.map((e) => e.toJson()).toList(),
        'catalogScrollOffset': catalogScrollOffset,
        'catalogScrollProgress': catalogScrollProgress,
        'catalogScrollIndex': catalogScrollIndex,
        'categoryScrollProgress': categoryScrollProgress,
      };

  factory CustomerDisplayMenuSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerDisplayMenuSnapshot();
    List<CustomerDisplayMenuCategoryData> parseCats(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => CustomerDisplayMenuCategoryData.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(growable: false);
    }

    final crumbs = json['breadcrumb'];
    final pathRaw = json['pathIds'];
    return CustomerDisplayMenuSnapshot(
      breadcrumb: crumbs is List
          ? crumbs.map((e) => e.toString()).toList(growable: false)
          : const [],
      pathIds: pathRaw is List
          ? pathRaw.map((e) => (e as num).toInt()).toList(growable: false)
          : const [],
      rootCategories: parseCats(json['rootCategories']),
      categories: parseCats(json['categories']),
      products: parseProducts(json['products']),
      catalogScrollOffset:
          (json['catalogScrollOffset'] as num?)?.toDouble() ?? 0,
      catalogScrollProgress:
          (json['catalogScrollProgress'] as num?)?.toDouble() ?? 0,
      catalogScrollIndex: (json['catalogScrollIndex'] as num?)?.toInt() ?? 0,
      categoryScrollProgress:
          (json['categoryScrollProgress'] as num?)?.toDouble() ?? 0,
    );
  }

  static List<CustomerDisplayMenuProductData> parseProducts(dynamic prods) {
    if (prods is! List) return const [];
    return prods
        .whereType<Map>()
        .map(
          (e) => CustomerDisplayMenuProductData.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  static CustomerDisplayMenuSnapshot fromMenuState(
    MenuState menu, {
    double catalogScrollOffset = 0,
    double catalogScrollProgress = 0,
    int catalogScrollIndex = 0,
    double categoryScrollProgress = 0,
  }) {
    final crumbs = menu.breadcrumbLine.isEmpty
        ? const <String>[]
        : menu.breadcrumbLine.split(' › ');

    return CustomerDisplayMenuSnapshot(
      breadcrumb: crumbs,
      pathIds: List<int>.from(menu.pathIds),
      catalogScrollOffset: catalogScrollOffset,
      catalogScrollProgress: catalogScrollProgress,
      catalogScrollIndex: catalogScrollIndex,
      categoryScrollProgress: categoryScrollProgress,
      rootCategories: menu.categoryRoots
          .map(
            (c) => CustomerDisplayMenuCategoryData(
              id: c.id,
              name: c.name,
              subtitle: c.subtitle,
            ),
          )
          .toList(growable: false),
      categories: menu.currentChildCategories
          .map(
            (c) => CustomerDisplayMenuCategoryData(
              id: c.id,
              name: c.name,
              subtitle: c.subtitle,
            ),
          )
          .toList(growable: false),
      products: _productsForCustomerDisplay(menu.currentItems),
    );
  }

  /// Пиццы 25/30/35 → одна карточка с размерами; остальное без изменений.
  static List<CustomerDisplayMenuProductData> _productsForCustomerDisplay(
    List<PosMenuItem> items,
  ) {
    if (items.isEmpty) return const [];
    return groupPosMenuItems(items)
        .map((tile) {
          if (!tile.isGroup) {
            final item = tile.representative;
            return CustomerDisplayMenuProductData(
              id: item.id,
              name: item.name,
              priceText: item.priceText,
              price: item.price,
              imagePath: item.imagePath,
            );
          }
          final display = tile.displayItem;
          return CustomerDisplayMenuProductData(
            id: tile.representative.id,
            name: tile.baseName,
            priceText: display.priceText,
            price: display.price,
            imagePath: display.imagePath,
            sizes: [
              for (final s in tile.sizes)
                CustomerDisplayMenuProductSizeData(
                  id: s.id,
                  label: parsePosSizeTail(s.name)?.sizeLabel ?? s.name,
                  priceText: s.priceText,
                  price: s.price,
                ),
            ],
          );
        })
        .toList(growable: false);
  }
}

class CustomerDisplayMenuCategoryData {
  const CustomerDisplayMenuCategoryData({
    required this.id,
    required this.name,
    this.subtitle,
  });

  final int id;
  final String name;
  final String? subtitle;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (subtitle != null && subtitle!.trim().isNotEmpty) 'subtitle': subtitle,
      };

  factory CustomerDisplayMenuCategoryData.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayMenuCategoryData(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
    );
  }
}

class CustomerDisplayMenuProductSizeData {
  const CustomerDisplayMenuProductSizeData({
    required this.id,
    required this.label,
    required this.priceText,
    required this.price,
  });

  final String id;
  final String label;
  final String priceText;
  final double price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'priceText': priceText,
        'price': price,
      };

  factory CustomerDisplayMenuProductSizeData.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerDisplayMenuProductSizeData(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      priceText: json['priceText']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CustomerDisplayMenuProductData {
  const CustomerDisplayMenuProductData({
    required this.id,
    required this.name,
    required this.priceText,
    required this.price,
    this.imagePath,
    this.sizes = const [],
  });

  final String id;
  final String name;
  final String priceText;
  final double price;
  final String? imagePath;

  /// Размеры пиццы (25/30/35) — одна карточка вместо трёх товаров.
  final List<CustomerDisplayMenuProductSizeData> sizes;

  bool get hasSizeVariants => sizes.length >= 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'priceText': priceText,
        'price': price,
        if (imagePath != null && imagePath!.trim().isNotEmpty)
          'imagePath': imagePath,
        if (sizes.isNotEmpty) 'sizes': sizes.map((e) => e.toJson()).toList(),
      };

  factory CustomerDisplayMenuProductData.fromJson(Map<String, dynamic> json) {
    final sizesRaw = json['sizes'];
    final sizes = sizesRaw is List
        ? sizesRaw
            .whereType<Map>()
            .map(
              (e) => CustomerDisplayMenuProductSizeData.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <CustomerDisplayMenuProductSizeData>[];
    return CustomerDisplayMenuProductData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceText: json['priceText']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imagePath: json['imagePath']?.toString(),
      sizes: sizes,
    );
  }
}

PosMenuItem? findPosMenuItemById(List<PosCategory> roots, String id) {
  for (final root in roots) {
    final found = _findPosMenuItemInCategory(root, id);
    if (found != null) return found;
  }
  return null;
}

PosMenuItem? _findPosMenuItemInCategory(PosCategory category, String id) {
  for (final item in category.items) {
    if (item.id == id) return item;
  }
  for (final child in category.children) {
    final found = _findPosMenuItemInCategory(child, id);
    if (found != null) return found;
  }
  return null;
}

/// Импульс «товар добавлен в корзину» для анимации на экране клиента.
class CustomerDisplayCartAddPulse {
  const CustomerDisplayCartAddPulse({
    required this.seq,
    required this.name,
    this.imagePath,
  });

  final int seq;
  final String name;
  final String? imagePath;

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'name': name,
        if (imagePath != null && imagePath!.trim().isNotEmpty)
          'imagePath': imagePath,
      };

  factory CustomerDisplayCartAddPulse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CustomerDisplayCartAddPulse(seq: 0, name: '');
    }
    return CustomerDisplayCartAddPulse(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imagePath: json['imagePath']?.toString(),
    );
  }
}
