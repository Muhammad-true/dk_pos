abstract class MenuItemsAdminRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchItemsRaw();

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> body);

  Future<Map<String, dynamic>> updateItem(String id, Map<String, dynamic> body);

  Future<void> deleteItem(String id);
}
