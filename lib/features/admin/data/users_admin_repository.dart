import 'package:dk_pos/features/admin/data/admin_user_row.dart';
import 'package:dk_pos/features/admin/data/users_admin_remote_data_source.dart';

class UsersAdminRepository {
  UsersAdminRepository(this._remote);

  final UsersAdminRemoteDataSource _remote;

  Future<List<AdminUserRow>> fetchUsers() => _remote.fetchUsers();

  Future<AdminUserRow> createUser({
    required String username,
    required String password,
    required String role,
    int? isActive,
    int? kitchenStationId,
    int? kitchenButtonId,
  }) {
    return _remote.createUser(
      username: username,
      password: password,
      role: role,
      isActive: isActive,
      kitchenStationId: kitchenStationId,
      kitchenButtonId: kitchenButtonId,
    );
  }

  Future<AdminUserRow> updateUser(
    int id, {
    String? username,
    String? password,
    String? role,
    int? isActive,
    int? kitchenStationId,
    int? kitchenButtonId,
  }) {
    return _remote.updateUser(
      id,
      username: username,
      password: password,
      role: role,
      isActive: isActive,
      kitchenStationId: kitchenStationId,
      kitchenButtonId: kitchenButtonId,
    );
  }

  Future<void> deleteUser(int id) => _remote.deleteUser(id);
}
