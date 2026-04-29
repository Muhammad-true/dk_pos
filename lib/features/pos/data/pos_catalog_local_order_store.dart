import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/shared/shared.dart';

const _kPrefsKeyLegacy = 'pos_catalog_local_order_v1';

/// Безопасный суффикс ключа для [SharedPreferences] (роль: cashier, waiter, …).
String posCatalogOrderPrefsScope(String? role) {
  final r = (role ?? '').trim().toLowerCase();
  if (r.isEmpty) return 'default';
  final safe = r.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  return safe.isEmpty ? 'default' : safe;
}

String _prefsKeyForScope(String scope) =>
    '${_kPrefsKeyLegacy}_${posCatalogOrderPrefsScope(scope)}';

/// Локальный порядок категорий и товаров на экране POS (не влияет на сервер).
///
/// [scope] — обычно `user.role` (`cashier`, `waiter`, …), чтобы на одном устройстве
/// касса и официант не перезаписывали порядок друг другу (в т.ч. на Android).
class PosCatalogLocalOrderStore {
  Future<PosCatalogLocalOrderSnapshot> load({required String scope}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyForScope(scope);
    var raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      raw = prefs.getString(_kPrefsKeyLegacy);
    }
    if (raw == null || raw.isEmpty) {
      return PosCatalogLocalOrderSnapshot.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return PosCatalogLocalOrderSnapshot.empty();
      }
      return PosCatalogLocalOrderSnapshot.fromJson(decoded);
    } catch (_) {
      return PosCatalogLocalOrderSnapshot.empty();
    }
  }

  Future<void> save(
    PosCatalogLocalOrderSnapshot snapshot, {
    required String scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKeyForScope(scope);
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
  }
}

class PosCatalogLocalOrderSnapshot {
  const PosCatalogLocalOrderSnapshot({
    required this.rootCategoryIds,
    required this.itemIdsByCategory,
  });

  /// Порядок корневых категорий в боковой/верхней навигации.
  final List<int> rootCategoryIds;

  /// Ключ — id узла каталога, у которого показываются товары ([MenuState.pathIds].last).
  final Map<int, List<String>> itemIdsByCategory;

  static PosCatalogLocalOrderSnapshot empty() => const PosCatalogLocalOrderSnapshot(
        rootCategoryIds: [],
        itemIdsByCategory: {},
      );

  Map<String, dynamic> toJson() => {
        'roots': rootCategoryIds,
        'items': itemIdsByCategory.map((k, v) => MapEntry('$k', v)),
      };

  factory PosCatalogLocalOrderSnapshot.fromJson(Map<String, dynamic> json) {
    final roots = <int>[];
    final r = json['roots'];
    if (r is List) {
      for (final e in r) {
        final id = int.tryParse(e.toString());
        if (id != null) roots.add(id);
      }
    }
    final items = <int, List<String>>{};
    final im = json['items'];
    if (im is Map) {
      im.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id == null) return;
        if (v is List) {
          items[id] = v.map((e) => e.toString()).toList();
        }
      });
    }
    return PosCatalogLocalOrderSnapshot(
      rootCategoryIds: roots,
      itemIdsByCategory: items,
    );
  }

  PosCatalogLocalOrderSnapshot withRootOrder(List<int> ids) {
    return PosCatalogLocalOrderSnapshot(
      rootCategoryIds: ids,
      itemIdsByCategory: itemIdsByCategory,
    );
  }

  PosCatalogLocalOrderSnapshot withItemOrderForCategory(
    int categoryId,
    List<String> orderedItemIds,
  ) {
    final next = Map<int, List<String>>.from(itemIdsByCategory);
    next[categoryId] = orderedItemIds;
    return PosCatalogLocalOrderSnapshot(
      rootCategoryIds: rootCategoryIds,
      itemIdsByCategory: next,
    );
  }
}

int _compareCategories(PosCategory a, PosCategory b) {
  final o = a.sortOrder.compareTo(b.sortOrder);
  if (o != 0) return o;
  return a.id.compareTo(b.id);
}

List<PosCategory> mergePosRootCategoryOrder(
  List<PosCategory> api,
  List<int> savedOrder,
) {
  if (savedOrder.isEmpty) {
    final copy = List<PosCategory>.from(api)..sort(_compareCategories);
    return copy;
  }
  final byId = {for (final c in api) c.id: c};
  final out = <PosCategory>[];
  final seen = <int>{};
  for (final id in savedOrder) {
    final c = byId[id];
    if (c != null) {
      out.add(c);
      seen.add(id);
    }
  }
  final rest = api.where((c) => !seen.contains(c.id)).toList()
    ..sort(_compareCategories);
  return [...out, ...rest];
}

List<PosMenuItem> mergePosItemOrder(
  List<PosMenuItem> api,
  List<String>? savedOrder,
) {
  if (savedOrder == null || savedOrder.isEmpty) {
    return List<PosMenuItem>.from(api);
  }
  final byId = {for (final i in api) i.id: i};
  final out = <PosMenuItem>[];
  final seen = <String>{};
  for (final id in savedOrder) {
    final it = byId[id];
    if (it != null) {
      out.add(it);
      seen.add(id);
    }
  }
  final rest = api.where((i) => !seen.contains(i.id)).toList();
  return [...out, ...rest];
}
