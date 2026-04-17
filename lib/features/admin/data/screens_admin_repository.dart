import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/screen_page_item_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_remote_data_source.dart';

class ScreensAdminRepository {
  ScreensAdminRepository(this._remote);

  final ScreensAdminRemoteDataSource _remote;

  Future<List<AdminScreenRow>> fetchScreens({bool activeOnly = false}) async {
    final raw = await _remote.fetchScreensRaw(activeOnly: activeOnly);
    return raw.map(AdminScreenRow.fromJson).toList();
  }

  Future<AdminScreenRow> createScreen(Map<String, dynamic> body) async {
    final j = await _remote.createScreen(body);
    return AdminScreenRow.fromJson(j);
  }

  Future<AdminScreenRow> updateScreen(int id, Map<String, dynamic> body) async {
    final j = await _remote.updateScreen(id, body);
    return AdminScreenRow.fromJson(j);
  }

  Future<AdminScreenRow> mergeScreenConfig(int id, Map<String, dynamic> configPatch) async {
    final j = await _remote.mergeScreenConfig(id, configPatch);
    return AdminScreenRow.fromJson(j);
  }

  Future<void> deleteScreen(int id) => _remote.deleteScreen(id);

  Future<List<AdminScreenPageRow>> fetchScreenPages(int screenId) async {
    final raw = await _remote.fetchScreenPagesRaw(screenId);
    return raw.map(AdminScreenPageRow.fromJson).toList();
  }

  Future<AdminScreenPageRow> addScreenPage(
    int screenId, {
    required String pageType,
    int sortOrder = 0,
    int? comboId,
  }) async {
    final j = await _remote.addScreenPage(
      screenId,
      pageType: pageType,
      sortOrder: sortOrder,
      comboId: comboId,
    );
    return AdminScreenPageRow.fromJson(j);
  }

  Future<void> deleteScreenPage(int screenId, int pageId) =>
      _remote.deleteScreenPage(screenId, pageId);

  /// Ответ: `{ page: {...}, items: [...] }`.
  Future<Map<String, dynamic>> fetchScreenPageDetail(int screenId, int pageId) =>
      _remote.fetchScreenPageDetailRaw(screenId, pageId);

  Future<AdminScreenPageRow> patchScreenPage(
    int screenId,
    int pageId, {
    String? pageType,
    int? sortOrder,
    Map<String, dynamic>? listTitle,
    Map<String, dynamic>? secondListTitle,
    int? comboId,
    bool clearComboId = false,
    Map<String, dynamic>? config,
  }) async {
    final body = <String, dynamic>{};
    if (pageType != null) body['page_type'] = pageType;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (listTitle != null) body['list_title'] = listTitle;
    if (secondListTitle != null) body['second_list_title'] = secondListTitle;
    if (config != null) body['config'] = config;
    if (clearComboId) {
      body['combo_id'] = null;
    } else if (comboId != null) {
      body['combo_id'] = comboId;
    }
    final j = await _remote.patchScreenPage(screenId, pageId, body);
    return AdminScreenPageRow.fromJson(j);
  }

  Future<ScreenPageItemRow> addScreenPageItem(
    int screenId,
    int pageId, {
    required String menuItemId,
    required String role,
    int sortOrder = 0,
  }) async {
    final j = await _remote.addScreenPageItem(screenId, pageId, {
      'menu_item_id': menuItemId,
      'role': role,
      'sort_order': sortOrder,
    });
    return ScreenPageItemRow.fromJson(j);
  }

  Future<void> deleteScreenPageItem(int screenId, int pageId, int itemRowId) =>
      _remote.deleteScreenPageItem(screenId, pageId, itemRowId);
}
