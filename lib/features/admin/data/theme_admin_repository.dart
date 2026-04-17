import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

/// Тема меню / ТВ (`GET/PATCH /api/theme`), в т.ч. блок `tvQueueBoard`.
class ThemeAdminRepository {
  ThemeAdminRepository(this._http);

  final HttpClient _http;

  Future<Map<String, dynamic>> fetchActiveTheme() async {
    final res = await _http.get('api/theme');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }

  Future<Map<String, dynamic>> patchTheme(int id, Map<String, dynamic> body) async {
    final res = await _http.patch('api/theme/$id', body: body);
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return data;
  }
}
