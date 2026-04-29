import 'package:dk_pos/features/admin/data/admin_category_row.dart';

class AdminMenuVolumeVariant {
  const AdminMenuVolumeVariant({
    required this.label,
    required this.priceText,
  });

  final String label;
  final String priceText;

  factory AdminMenuVolumeVariant.fromJson(Map<String, dynamic> j) {
    return AdminMenuVolumeVariant(
      label: j['label']?.toString() ?? j['volume']?.toString() ?? '',
      priceText:
          j['priceText']?.toString() ?? j['price_text']?.toString() ?? '',
    );
  }
}

class AdminMenuItemRow {
  const AdminMenuItemRow({
    required this.id,
    required this.categoryId,
    this.kitchenStationId,
    this.kitchenStationName,
    this.kitchenStationType,
    this.comboId,
    required this.category,
    required this.price,
    required this.sortOrder,
    required this.isAvailable,
    required this.name,
    required this.priceText,
    this.description,
    this.composition,
    this.imagePath,
    required this.saleUnitId,
    required this.unitName,
    this.sku,
    this.barcode,
    required this.trackStock,
    required this.allowCustomPrice,
    this.tvVolumeVariants = const [],
    this.tv1Page,
  });

  final String id;
  final int categoryId;
  final int? kitchenStationId;
  final String? kitchenStationName;
  final String? kitchenStationType;
  final int? comboId;
  final AdminCategoryTranslations category;
  final double price;
  final int sortOrder;
  final int isAvailable;
  final AdminCategoryTranslations name;
  final AdminCategoryTranslations priceText;
  final AdminCategoryTranslations? description;
  final AdminCategoryTranslations? composition;
  final String? imagePath;
  final int saleUnitId;
  final AdminCategoryTranslations unitName;
  final String? sku;
  final String? barcode;
  final int trackStock;
  final int allowCustomPrice;
  final List<AdminMenuVolumeVariant> tvVolumeVariants;

  /// Номер слайда карусели ТВ1 (1, 2, …) или null — не показывать на ТВ1.
  final int? tv1Page;

  /// Подпись единицы для списка (локаль зависит от запроса единиц / данных строки).
  String get saleUnitDisplay => unitName.ru;

  /// Все варианты цен для ТВ / комбо (RU): объёмы или основная цена.
  String get displayPriceLineRu {
    if (tvVolumeVariants.isEmpty) return priceText.ru;
    return tvVolumeVariants
        .map((v) => '${v.label}: ${v.priceText}')
        .join(' · ');
  }

  static List<AdminMenuVolumeVariant> _tvVolumeVariantsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <AdminMenuVolumeVariant>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final v = AdminMenuVolumeVariant.fromJson(Map<String, dynamic>.from(e));
      if (v.label.isNotEmpty && v.priceText.isNotEmpty) out.add(v);
    }
    return out;
  }

  factory AdminMenuItemRow.fromJson(Map<String, dynamic> j) {
    final unit = j['unit'];
    Map<String, dynamic> unitNameMap = {};
    if (unit is Map) {
      final n = unit['name'];
      if (n is Map) {
        unitNameMap = Map<String, dynamic>.from(n);
      }
    }
    return AdminMenuItemRow(
      id: j['id']?.toString() ?? '',
      categoryId: (j['category_id'] as num).toInt(),
      kitchenStationId: (j['kitchen_station_id'] as num?)?.toInt(),
      kitchenStationName: j['kitchen_station'] is Map
          ? (j['kitchen_station']['name']?.toString())
          : null,
      kitchenStationType: j['kitchen_station'] is Map
          ? (j['kitchen_station']['type']?.toString())
          : null,
      comboId: (j['combo_id'] as num?)?.toInt(),
      category: AdminCategoryTranslations.fromJson(
        Map<String, dynamic>.from(j['category'] as Map),
      ),
      price: (j['price'] as num).toDouble(),
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      isAvailable: (j['is_available'] as num?)?.toInt() ?? 1,
      name: AdminCategoryTranslations.fromJson(
        Map<String, dynamic>.from(j['name'] as Map),
      ),
      priceText: AdminCategoryTranslations.fromJson(
        Map<String, dynamic>.from(j['price_text'] as Map),
      ),
      description: j['description'] != null
          ? AdminCategoryTranslations.fromJson(
              Map<String, dynamic>.from(j['description'] as Map),
            )
          : null,
      composition: j['composition'] != null
          ? AdminCategoryTranslations.fromJson(
              Map<String, dynamic>.from(j['composition'] as Map),
            )
          : null,
      imagePath: j['image_path']?.toString(),
      saleUnitId: (j['sale_unit_id'] as num?)?.toInt() ?? 0,
      unitName: AdminCategoryTranslations.fromJson(unitNameMap),
      sku: j['sku']?.toString(),
      barcode: j['barcode']?.toString(),
      trackStock: (j['track_stock'] as num?)?.toInt() ?? 1,
      allowCustomPrice: (j['allow_custom_price'] as num?)?.toInt() ?? 0,
      tvVolumeVariants: _tvVolumeVariantsFromJson(j['tv_volume_variants']),
      tv1Page: () {
        final v = j['tv1_page'] ?? j['tv1Page'];
        if (v == null) return null;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }(),
    );
  }
}
