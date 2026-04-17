import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

/// Черновой просмотр раскладки ТВ (`POST /api/menu/display-preview`).
class MenuDisplayPreviewRepository {
  MenuDisplayPreviewRepository(this._http);

  final HttpClient _http;

  Future<Map<String, dynamic>> fetchPreview(Map<String, dynamic> body) async {
    final res = await _http.post('api/menu/display-preview', body: body);
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
