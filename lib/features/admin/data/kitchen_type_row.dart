class KitchenTypeRow {
  const KitchenTypeRow({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String code;
  final String name;
  final int isActive;
  final int sortOrder;

  factory KitchenTypeRow.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return KitchenTypeRow(
      id: asInt(json['id']),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: asInt(json['is_active'], 1),
      sortOrder: asInt(json['sort_order']),
    );
  }
}
