class AdminScreenRow {
  const AdminScreenRow({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.sortOrder,
    required this.isActive,
    this.config,
  });

  final int id;
  final String name;
  final String slug;
  final String type;
  final int sortOrder;
  final bool isActive;
  final Map<String, dynamic>? config;

  factory AdminScreenRow.fromJson(Map<String, dynamic> j) {
    return AdminScreenRow(
      id: (j['id'] as num).toInt(),
      name: j['name']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
      type: j['type']?.toString() ?? 'carousel',
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] == true || j['isActive'] == 1,
      config: j['config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(j['config'] as Map)
          : null,
    );
  }
}
