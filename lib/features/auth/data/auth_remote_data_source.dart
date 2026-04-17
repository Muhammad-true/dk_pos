import 'package:dk_pos/shared/shared.dart';

/// Сетевые методы авторизации (без хранения токена).
abstract class AuthRemoteDataSource {
  Future<(String token, UserModel user)> login({
    required String username,
    required String password,
  });

  Future<UserModel> fetchMe();
}
