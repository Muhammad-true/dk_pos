import 'package:dk_pos/features/admin/data/admin_user_row.dart';

abstract class UsersAdminRemoteDataSource {
  Future<List<AdminUserRow>> fetchUsers();

  Future<AdminUserRow> createUser({
    required String username,
    required String password,
    required String role,
    int? kitchenStationId,
  });

  Future<AdminUserRow> updateUser(
    int id, {
    String? username,
    String? password,
    String? role,
    int? kitchenStationId,
  });

  Future<void> deleteUser(int id);
}
