import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/kitchen_station_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_type_row.dart';

class KitchenStationsRepository {
  KitchenStationsRepository(this._http);

  final HttpClient _http;

  Future<List<KitchenStationRow>> fetchStations() async {
    final res = await _http.get('api/kitchen-stations');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['stations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(KitchenStationRow.fromJson)
        .toList();
  }

  Future<KitchenStationRow> createStation({
    required String name,
    required String type,
    int sortOrder = 0,
    int isActive = 1,
  }) async {
    final res = await _http.post(
      'api/kitchen-stations',
      body: {
        'name': name,
        'type': type,
        'sort_order': sortOrder,
        'is_active': isActive,
      },
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic> || data['station'] is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return KitchenStationRow.fromJson(data['station'] as Map<String, dynamic>);
  }

  Future<KitchenStationRow> updateStation(
    int id, {
    String? name,
    String? type,
    int? sortOrder,
    int? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (type != null) body['type'] = type;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _http.patch('api/kitchen-stations/$id', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic> || data['station'] is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return KitchenStationRow.fromJson(data['station'] as Map<String, dynamic>);
  }

  Future<void> deleteStation(int id) async {
    final res = await _http.delete('api/kitchen-stations/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }

  Future<List<KitchenTypeRow>> fetchTypes() async {
    final res = await _http.get('api/kitchen-types');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['types'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(KitchenTypeRow.fromJson)
        .toList();
  }

  Future<KitchenTypeRow> createType({
    required String code,
    required String name,
    int sortOrder = 0,
    int isActive = 1,
  }) async {
    final res = await _http.post(
      'api/kitchen-types',
      body: {
        'code': code,
        'name': name,
        'sort_order': sortOrder,
        'is_active': isActive,
      },
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic> || data['type'] is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return KitchenTypeRow.fromJson(data['type'] as Map<String, dynamic>);
  }
}
