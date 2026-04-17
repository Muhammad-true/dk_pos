import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_remote_data_source.dart';

class MenuItemsAdminRemoteDataSourceImpl implements MenuItemsAdminRemoteDataSource {
  MenuItemsAdminRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<Map<String, dynamic>>> fetchItemsRaw() async {
    final res = await _http.get('api/menu/admin/items');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['items'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> body) async {
    final res = await _http.post('api/menu/admin/items', body: body);
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final item = data['item'];
    if (item is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return item;
  }

  @override
  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> body) async {
    final res = await _http.patch('api/menu/items/$id', body: body);
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
  Future<void> deleteItem(String id) async {
    final res = await _http.delete('api/menu/items/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
