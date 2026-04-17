class KitchenStationRow {
  const KitchenStationRow({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String type;
  final int isActive;
  final int sortOrder;

  factory KitchenStationRow.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return KitchenStationRow(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'inside',
      isActive: asInt(json['is_active'], 1),
      sortOrder: asInt(json['sort_order']),
    );
  }
}
