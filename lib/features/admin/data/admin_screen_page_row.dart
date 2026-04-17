import 'package:dk_pos/features/admin/data/admin_category_row.dart';

class AdminScreenPageRow {
  const AdminScreenPageRow({
    required this.id,
    required this.pageType,
    required this.sortOrder,
    required this.itemsCount,
    this.comboId,
    this.config,
    this.listTitle,
    this.secondListTitle,
  });

  final int id;
  final String pageType;
  final int sortOrder;
  final int itemsCount;
  final int? comboId;
  final Map<String, dynamic>? config;
  final AdminCategoryTranslations? listTitle;
  final AdminCategoryTranslations? secondListTitle;

  factory AdminScreenPageRow.fromJson(Map<String, dynamic> j) {
    AdminCategoryTranslations? t(dynamic raw) {
      if (raw is! Map<String, dynamic>) return null;
      return AdminCategoryTranslations.fromJson(raw);
    }

    return AdminScreenPageRow(
      id: (j['id'] as num).toInt(),
      pageType: j['pageType']?.toString() ?? 'split',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      itemsCount: (j['itemsCount'] as num?)?.toInt() ?? 0,
      comboId: (j['comboId'] as num?)?.toInt(),
      config: j['config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(j['config'] as Map)
          : null,
      listTitle: t(j['listTitle']),
      secondListTitle: t(j['secondListTitle']),
    );
  }
}
