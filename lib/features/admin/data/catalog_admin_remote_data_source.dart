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

  Future<void> updateCategorySortOrder({
    required int id,
    required int sortOrder,
  });

  /// Локальный слайд ТВ1 для категории (`tv1_page`); `null` — снять с карусели.
  Future<void> updateCategoryTv1Page({
    required int id,
    int? tv1Page,
  });
}
