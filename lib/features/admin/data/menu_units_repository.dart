import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class MenuUnitOption {
  const MenuUnitOption({
    required this.id,
    required this.code,
    required this.label,
  });

  final int id;
  final String code;
  final String label;
}

class MenuUnitsRepository {
  MenuUnitsRepository(this._http);

  final HttpClient _http;

  Future<List<MenuUnitOption>> fetchUnits(String langCode) async {
    final res = await _http.get(
      'api/menu/units',
      query: {'lang': langCode},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['units'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw.whereType<Map<String, dynamic>>().map((m) {
      return MenuUnitOption(
        id: (m['id'] as num).toInt(),
        code: m['code']?.toString() ?? '',
        label: m['label']?.toString() ?? '',
      );
    }).toList();
  }
}
