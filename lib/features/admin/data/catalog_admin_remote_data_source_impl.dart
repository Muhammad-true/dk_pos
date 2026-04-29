import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/admin_category_row.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_remote_data_source.dart';

class CatalogAdminRemoteDataSourceImpl implements CatalogAdminRemoteDataSource {
  CatalogAdminRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<AdminCategoryRow>> fetchCategories() async {
    final res = await _http.get('api/menu/categories');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['categories'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminCategoryRow.fromJson)
        .toList();
  }

  @override
  Future<AdminCategoryRow> createCategory({
    required String nameRu,
    String? nameTj,
    String? nameEn,
    String? subtitleRu,
    String? subtitleTj,
    String? subtitleEn,
    required int sortOrder,
    int? parentId,
  }) async {
    final name = <String, dynamic>{'ru': nameRu};
    if (nameTj != null && nameTj.isNotEmpty) name['tj'] = nameTj;
    if (nameEn != null && nameEn.isNotEmpty) name['en'] = nameEn;

    Map<String, dynamic>? subtitle;
    final sr = subtitleRu?.trim() ?? '';
    if (sr.isNotEmpty) {
      subtitle = {'ru': sr};
      if (subtitleTj != null && subtitleTj.isNotEmpty) {
        subtitle['tj'] = subtitleTj;
      }
      if (subtitleEn != null && subtitleEn.isNotEmpty) {
        subtitle['en'] = subtitleEn;
      }
    }

    final body = <String, dynamic>{
      'name': name,
      'sort_order': sortOrder,
    };
    if (subtitle != null) body['subtitle'] = subtitle;
    if (parentId != null) body['parent_id'] = parentId;

    final res = await _http.post('api/menu/categories', body: body);
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final c = data['category'];
    if (c is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return AdminCategoryRow.fromJson(c);
  }

  @override
  Future<void> updateCategorySortOrder({
    required int id,
    required int sortOrder,
  }) async {
    final res = await _http.patch(
      'api/menu/categories/$id',
      body: {'sort_order': sortOrder},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  @override
  Future<void> updateCategoryTv1Page({
    required int id,
    int? tv1Page,
  }) async {
    final res = await _http.patch(
      'api/menu/categories/$id',
      body: <String, dynamic>{'tv1_page': tv1Page},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
