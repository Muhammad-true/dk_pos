import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/auth/data/auth_remote_data_source.dart';
import 'package:dk_pos/shared/shared.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<LoginUserOption>> fetchLoginUsers() async {
    final res = await _http.get('api/auth/login-users');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final usersRaw = data['users'];
    if (usersRaw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return usersRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (u) => LoginUserOption(
            id: (u['id'] as num?)?.toInt() ?? 0,
            username: (u['username'] ?? '').toString(),
            role: (u['role'] ?? '').toString(),
          ),
        )
        .where((u) => u.id > 0 && u.username.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<(String token, UserModel user)> login({
    required String username,
    required String password,
  }) async {
    final res = await _http.post(
      'api/auth/login',
      body: {'username': username, 'password': password},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final t = data['token']?.toString() ?? '';
    final u = data['user'];
    if (t.isEmpty || u is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return (t, UserModel.fromJson(u));
  }

  @override
  Future<UserModel> fetchMe() async {
    final res = await _http.get('api/auth/me');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final u = data['user'];
    if (u is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return UserModel.fromJson(u);
  }
}
