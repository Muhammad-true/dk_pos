import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/admin_user_row.dart';
import 'package:dk_pos/features/admin/data/users_admin_remote_data_source.dart';

class UsersAdminRemoteDataSourceImpl implements UsersAdminRemoteDataSource {
  UsersAdminRemoteDataSourceImpl(this._http);

  final HttpClient _http;

  @override
  Future<List<AdminUserRow>> fetchUsers() async {
    final res = await _http.get('api/users');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
    final data = res.body;
    if (data is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    final raw = data['users'];
    if (raw is! List) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера');
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AdminUserRow.fromJson)
        .toList();
  }

  @override
  Future<AdminUserRow> createUser({
    required String username,
    required String password,
    required String role,
    int? isActive,
    int? kitchenStationId,
    int? kitchenButtonId,
  }) async {
    final res = await _http.post(
      'api/users',
      body: {
        'username': username,
        'password': password,
        'role': role,
        'is_active': isActive,
        'kitchen_station_id': kitchenStationId,
        'kitchen_button_id': kitchenButtonId,
      },
    );
    if (res.statusCode != 201) {
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
    return AdminUserRow.fromJson(u);
  }

  @override
  Future<AdminUserRow> updateUser(
    int id, {
    String? username,
    String? password,
    String? role,
    int? isActive,
    int? kitchenStationId,
    int? kitchenButtonId,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (role != null) body['role'] = role;
    if (isActive != null) body['is_active'] = isActive;
    body['kitchen_station_id'] = kitchenStationId;
    body['kitchen_button_id'] = kitchenButtonId;
    final res = await _http.patch('api/users/$id', body: body);
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
    return AdminUserRow.fromJson(u);
  }

  @override
  Future<void> deleteUser(int id) async {
    final res = await _http.delete('api/users/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw ApiException.fromHttp(res.statusCode, res.body);
    }
  }
}
