import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/admin_combo_row.dart';

class CombosAdminRepository {
  CombosAdminRepository(this._http);

  final HttpClient _http;

  Future<List<AdminComboRow>> fetchCombos() async {
    final res = await _http.get('api/combos');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['combos'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminComboRow.fromJson)
        .toList();
  }

  Future<int> createCombo(Map<String, dynamic> body) async {
    final res = await _http.post('api/combos', body: body);
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return (data['id'] as num).toInt();
  }

  Future<Map<String, dynamic>> fetchComboDetail(int id) async {
    final res = await _http.get('api/combos/$id');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  Future<void> patchCombo(int id, Map<String, dynamic> body) async {
    final res = await _http.patch('api/combos/$id', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  Future<void> addComboItem(int comboId, String menuItemId, {int quantity = 1}) async {
    final res = await _http.post(
      'api/combos/$comboId/items',
      body: {
        'menu_item_id': menuItemId,
        'quantity': quantity,
      },
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  Future<void> deleteComboItem(int comboId, int itemRowId) async {
    final res = await _http.delete('api/combos/$comboId/items/$itemRowId');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  Future<void> deleteCombo(int id) async {
    final res = await _http.delete('api/combos/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
