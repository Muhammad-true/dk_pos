/// User row from GET /api/users (no password field).
class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.username,
    required this.role,
    this.kitchenStationId,
    this.kitchenStationName,
    this.kitchenStationType,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String username;
  final String role;
  final int? kitchenStationId;
  final String? kitchenStationName;
  final String? kitchenStationType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  static int _id(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  factory AdminUserRow.fromJson(Map<String, dynamic> json) {
    return AdminUserRow(
      id: _id(json['id']),
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'cashier',
      kitchenStationId: json['kitchen_station_id'] == null
          ? null
          : _id(json['kitchen_station_id']),
      kitchenStationName: json['kitchen_station_name']?.toString(),
      kitchenStationType: json['kitchen_station_type']?.toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}
