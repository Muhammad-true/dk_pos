import 'dart:convert';

import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/core/storage/key_value_store.dart';
import 'package:dk_pos/features/auth/data/auth_remote_data_source.dart';
import 'package:dk_pos/shared/shared.dart';

const _kToken = 'pos_auth_token';
const _kUserJson = 'pos_user_json';

/// Сессия: [KeyValueStore] + [HttpClient] (токен) + [AuthRemoteDataSource].
class AuthRepository {
  AuthRepository({
    required KeyValueStore kv,
    required AuthRemoteDataSource remote,
    required HttpClient http,
  })  : _kv = kv,
        _remote = remote,
        _http = http;

  final KeyValueStore _kv;
  final AuthRemoteDataSource _remote;
  final HttpClient _http;

  bool get hasAccessToken {
    final t = _http.authToken;
    return t != null && t.isNotEmpty;
  }

  Future<void> applyTokenFromStorage() async {
    final t = await _kv.getString(_kToken);
    _http.setAuthToken(t);
  }

  Future<UserModel?> readCachedUser() async {
    final raw = await _kv.getString(_kUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<LoginUserOption>> fetchLoginUsers() => _remote.fetchLoginUsers();

  Future<(String token, UserModel user)> login({
    required String username,
    required String password,
  }) {
    return _remote.login(username: username, password: password);
  }

  Future<UserModel> fetchMe() => _remote.fetchMe();

  Future<void> persistSession(String token, UserModel user) async {
    await _kv.setString(_kToken, token);
    await _kv.setString(_kUserJson, jsonEncode(_userToJson(user)));
    _http.setAuthToken(token);
  }

  Future<void> clearSession() async {
    _http.setAuthToken(null);
    await _kv.remove(_kToken);
    await _kv.remove(_kUserJson);
  }

  Map<String, dynamic> _userToJson(UserModel u) => {
        'id': u.id,
        'username': u.username,
        'role': u.role,
        'kitchen_station_id': u.kitchenStationId,
        'kitchen_station_name': u.kitchenStationName,
        'kitchen_station_type': u.kitchenStationType,
        'kitchen_button_id': u.kitchenButtonId,
        'kitchen_button_name': u.kitchenButtonName,
        'kitchen_button_color_hex': u.kitchenButtonColorHex,
      };

  Future<void> cacheUser(UserModel user) async {
    await _kv.setString(_kUserJson, jsonEncode(_userToJson(user)));
  }
}
