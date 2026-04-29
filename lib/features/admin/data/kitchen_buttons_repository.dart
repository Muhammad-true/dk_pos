import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/kitchen_button_row.dart';

class KitchenButtonsRepository {
  KitchenButtonsRepository(this._http);

  final HttpClient _http;

  Future<List<KitchenButtonRow>> fetchButtons() async {
    final res = await _http.get('api/kitchen-buttons');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['buttons'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(KitchenButtonRow.fromJson)
        .toList();
  }

  Future<KitchenButtonRow> createButton({
    required String name,
    required String colorHex,
    int sortOrder = 0,
    int isActive = 1,
  }) async {
    final res = await _http.post(
      'api/kitchen-buttons',
      body: {
        'name': name,
        'color_hex': colorHex,
        'sort_order': sortOrder,
        'is_active': isActive,
      },
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic> || data['button'] is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return KitchenButtonRow.fromJson(data['button'] as Map<String, dynamic>);
  }

  Future<KitchenButtonRow> updateButton(
    int id, {
    String? name,
    String? colorHex,
    int? sortOrder,
    int? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (colorHex != null) body['color_hex'] = colorHex;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _http.patch('api/kitchen-buttons/$id', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic> || data['button'] is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return KitchenButtonRow.fromJson(data['button'] as Map<String, dynamic>);
  }

  Future<void> deleteButton(int id) async {
    final res = await _http.delete('api/kitchen-buttons/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
