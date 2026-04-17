import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_remote_data_source.dart';

class MenuItemsAdminRepository {
  MenuItemsAdminRepository(this._remote);

  final MenuItemsAdminRemoteDataSource _remote;

  Future<List<AdminMenuItemRow>> fetchItems() async {
    final raw = await _remote.fetchItemsRaw();
    return raw.map(AdminMenuItemRow.fromJson).toList();
  }

  Future<AdminMenuItemRow> createItem(Map<String, dynamic> body) async {
    final j = await _remote.createItem(body);
    return AdminMenuItemRow.fromJson(j);
  }

  Future<AdminMenuItemRow> updateItem(String id, Map<String, dynamic> body) async {
    final j = await _remote.updateItem(id, body);
    return AdminMenuItemRow.fromJson(j);
  }

  Future<void> deleteItem(String id) => _remote.deleteItem(id);
}
