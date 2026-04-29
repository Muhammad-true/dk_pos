class KitchenButtonRow {
  const KitchenButtonRow({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String colorHex;
  final int isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  factory KitchenButtonRow.fromJson(Map<String, dynamic> json) {
    return KitchenButtonRow(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      colorHex: (json['color_hex']?.toString() ?? '#E53935').toUpperCase(),
      isActive: _asInt(json['is_active']),
      sortOrder: _asInt(json['sort_order']),
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
    );
  }
}
