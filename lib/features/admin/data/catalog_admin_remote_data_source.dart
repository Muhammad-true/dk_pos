import 'package:dk_pos/features/admin/data/admin_category_row.dart';

abstract class CatalogAdminRemoteDataSource {
  Future<List<AdminCategoryRow>> fetchCategories();

  Future<AdminCategoryRow> createCategory({
    required String nameRu,
    String? nameTj,
    String? nameEn,
    String? subtitleRu,
    String? subtitleTj,
    String? subtitleEn,
    required int sortOrder,
    int? parentId,
  });
}
