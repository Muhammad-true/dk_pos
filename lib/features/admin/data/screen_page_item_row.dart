import 'package:dk_pos/features/admin/data/admin_category_row.dart';

/// Строка `screen_page_items` + имя товара (API GET page detail).
class ScreenPageItemRow {
  const ScreenPageItemRow({
    required this.id,
    required this.menuItemId,
    required this.role,
    required this.sortOrder,
    required this.name,
  });

  final int id;
  final String menuItemId;
  final String role;
  final int sortOrder;
  final AdminCategoryTranslations name;

  factory ScreenPageItemRow.fromJson(Map<String, dynamic> j) {
    final n = j['name'];
    return ScreenPageItemRow(
      id: (j['id'] as num).toInt(),
      menuItemId: j['menuItemId']?.toString() ?? '',
      role: j['role']?.toString() ?? 'list',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      name: n is Map<String, dynamic>
          ? AdminCategoryTranslations.fromJson(n)
          : const AdminCategoryTranslations(ru: ''),
    );
  }
}
