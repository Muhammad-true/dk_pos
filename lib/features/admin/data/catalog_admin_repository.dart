import 'package:dk_pos/features/admin/data/admin_category_row.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_remote_data_source.dart';

class CatalogAdminRepository {
  CatalogAdminRepository(this._remote);

  final CatalogAdminRemoteDataSource _remote;

  Future<List<AdminCategoryRow>> fetchCategories() => _remote.fetchCategories();

  Future<AdminCategoryRow> createCategory({
    required String nameRu,
    String? nameTj,
    String? nameEn,
    String? subtitleRu,
    String? subtitleTj,
    String? subtitleEn,
    required int sortOrder,
    int? parentId,
  }) {
    return _remote.createCategory(
      nameRu: nameRu,
      nameTj: nameTj,
      nameEn: nameEn,
      subtitleRu: subtitleRu,
      subtitleTj: subtitleTj,
      subtitleEn: subtitleEn,
      sortOrder: sortOrder,
      parentId: parentId,
    );
  }
}
