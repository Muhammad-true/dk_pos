import 'package:dk_pos/shared/shared.dart';

class LoginUserOption {
  const LoginUserOption({
    required this.id,
    required this.username,
    required this.role,
  });

  final int id;
  final String username;
  final String role;
}

/// Сетевые методы авторизации (без хранения токена).
abstract class AuthRemoteDataSource {
  Future<List<LoginUserOption>> fetchLoginUsers();

  Future<(String token, UserModel user)> login({
    required String username,
    required String password,
  });

  Future<UserModel> fetchMe();
}
