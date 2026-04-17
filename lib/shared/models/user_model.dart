class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.kitchenStationId,
    this.kitchenStationName,
    this.kitchenStationType,
  });

  final int id;
  final String username;
  final String role;
  final int? kitchenStationId;
  final String? kitchenStationName;
  final String? kitchenStationType;

  bool get isAdmin => role == 'admin';

  bool get isWaiter => role == 'waiter';

  /// Касса, админ или официант — экран POS с каталогом.
  bool get isPosStaff =>
      role == 'cashier' || role == 'admin' || role == 'waiter';

  /// Принять оплату / печать чека по счёту — только касса и админ.
  bool get canProcessPosPayments =>
      role == 'cashier' || role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'cashier',
      kitchenStationId: json['kitchen_station_id'] == null
          ? null
          : _parseInt(json['kitchen_station_id']),
      kitchenStationName: json['kitchen_station_name']?.toString(),
      kitchenStationType: json['kitchen_station_type']?.toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get roleLabelRu {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'warehouse':
        return 'Склад';
      case 'cashier':
        return 'Касса';
      case 'expeditor':
        return 'Сборщик';
      case 'waiter':
        return 'Официант';
      default:
        return role;
    }
  }
}
