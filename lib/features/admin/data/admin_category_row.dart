class AdminCategoryTranslations {
  const AdminCategoryTranslations({
    required this.ru,
    this.tj,
    this.en,
  });

  final String ru;
  final String? tj;
  final String? en;

  factory AdminCategoryTranslations.fromJson(Map<String, dynamic> j) {
    return AdminCategoryTranslations(
      ru: j['ru']?.toString() ?? '',
      tj: j['tj']?.toString(),
      en: j['en']?.toString(),
    );
  }
}

/// Дерево для UI: корни, затем дети в порядке [sort_order, id].
List<AdminCategoryRow> orderCategoriesForAdminTree(List<AdminCategoryRow> flat) {
  final byParent = <int?, List<AdminCategoryRow>>{};
  for (final c in flat) {
    byParent.putIfAbsent(c.parentId, () => []).add(c);
  }
  for (final list in byParent.values) {
    list.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.id.compareTo(b.id);
    });
  }
  final out = <AdminCategoryRow>[];
  void walk(int? parentId) {
    final kids = byParent[parentId];
    if (kids == null) return;
    for (final k in kids) {
      out.add(k);
      walk(k.id);
    }
  }

  walk(null);
  final seen = out.map((c) => c.id).toSet();
  final orphans = flat.where((c) => !seen.contains(c.id)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  out.addAll(orphans);
  return out;
}

class AdminCategoryRow {
  const AdminCategoryRow({
    required this.id,
    required this.sortOrder,
    required this.name,
    this.subtitle,
    this.parentId,
    this.depth = 0,
  });

  final int id;
  final int sortOrder;
  final AdminCategoryTranslations name;
  final AdminCategoryTranslations? subtitle;
  final int? parentId;
  final int depth;

  factory AdminCategoryRow.fromJson(Map<String, dynamic> j) {
    final pid = j['parent_id'];
    return AdminCategoryRow(
      id: (j['id'] as num).toInt(),
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      name: AdminCategoryTranslations.fromJson(
        Map<String, dynamic>.from(j['name'] as Map),
      ),
      subtitle: j['subtitle'] != null
          ? AdminCategoryTranslations.fromJson(
              Map<String, dynamic>.from(j['subtitle'] as Map),
            )
          : null,
      parentId: pid == null ? null : (pid as num).toInt(),
      depth: (j['depth'] as num?)?.toInt() ?? 0,
    );
  }
}
