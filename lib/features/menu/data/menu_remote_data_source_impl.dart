import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/menu/data/menu_remote_data_source.dart';
import 'package:dk_pos/shared/shared.dart';

class MenuRemoteDataSourceImpl implements MenuRemoteDataSource {
  MenuRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<PosCategory>> fetchPosMenu({String lang = 'ru'}) async {
    final res = await _http.get(
      'api/menu/pos',
      query: {'lang': lang},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) return [];
    final raw = data['categories'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PosCategory.fromJson)
        .toList();
  }
}
