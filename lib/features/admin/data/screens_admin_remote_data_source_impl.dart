import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/screens_admin_remote_data_source.dart';

class ScreensAdminRemoteDataSourceImpl implements ScreensAdminRemoteDataSource {
  ScreensAdminRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<Map<String, dynamic>>> fetchScreensRaw({bool activeOnly = false}) async {
    final res = await _http.get(
      'api/screens',
      query: activeOnly ? {'active_only': '1'} : null,
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> createScreen(Map<String, dynamic> body) async {
    final res = await _http.post('api/screens', body: body);
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> updateScreen(int id, Map<String, dynamic> body) async {
    final res = await _http.patch('api/screens/$id', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> mergeScreenConfig(int id, Map<String, dynamic> configPatch) async {
    return updateScreen(id, {
      'config': configPatch,
      'config_merge': true,
    });
  }

  @override
  Future<void> deleteScreen(int id) async {
    final res = await _http.delete('api/screens/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchScreenPagesRaw(int screenId) async {
    final res = await _http.get('api/screens/$screenId/pages');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['pages'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> addScreenPage(
    int screenId, {
    required String pageType,
    int sortOrder = 0,
    int? comboId,
  }) async {
    final body = <String, dynamic>{
      'page_type': pageType,
      'sort_order': sortOrder,
    };
    if (comboId != null) body['combo_id'] = comboId;
    final res = await _http.post(
      'api/screens/$screenId/pages',
      body: body,
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<void> deleteScreenPage(int screenId, int pageId) async {
    final res = await _http.delete('api/screens/$screenId/pages/$pageId');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchScreenPageDetailRaw(int screenId, int pageId) async {
    final res = await _http.get('api/screens/$screenId/pages/$pageId');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> patchScreenPage(
    int screenId,
    int pageId,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.patch('api/screens/$screenId/pages/$pageId', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> addScreenPageItem(
    int screenId,
    int pageId,
    Map<String, dynamic> body,
  ) async {
    final res = await _http.post(
      'api/screens/$screenId/pages/$pageId/items',
      body: body,
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  @override
  Future<void> deleteScreenPageItem(int screenId, int pageId, int itemRowId) async {
    final res = await _http.delete(
      'api/screens/$screenId/pages/$pageId/items/$itemRowId',
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
