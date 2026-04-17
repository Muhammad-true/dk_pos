abstract class ScreensAdminRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchScreensRaw({bool activeOnly = false});

  Future<Map<String, dynamic>> createScreen(Map<String, dynamic> body);

  Future<Map<String, dynamic>> updateScreen(int id, Map<String, dynamic> body);

  /// PATCH с `config_merge: true` (слияние с текущим `config` на сервере).
  Future<Map<String, dynamic>> mergeScreenConfig(int id, Map<String, dynamic> configPatch);

  Future<void> deleteScreen(int id);

  Future<List<Map<String, dynamic>>> fetchScreenPagesRaw(int screenId);

  Future<Map<String, dynamic>> addScreenPage(
    int screenId, {
    required String pageType,
    int sortOrder = 0,
    int? comboId,
  });

  Future<void> deleteScreenPage(int screenId, int pageId);

  Future<Map<String, dynamic>> fetchScreenPageDetailRaw(int screenId, int pageId);

  Future<Map<String, dynamic>> patchScreenPage(
    int screenId,
    int pageId,
    Map<String, dynamic> body,
  );

  Future<Map<String, dynamic>> addScreenPageItem(
    int screenId,
    int pageId,
    Map<String, dynamic> body,
  );

  Future<void> deleteScreenPageItem(int screenId, int pageId, int itemRowId);
}
