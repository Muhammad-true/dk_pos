import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';

class ShiftCloseOpenOrder {
  const ShiftCloseOpenOrder({
    required this.id,
    this.number,
    required this.status,
    required this.statusLabel,
    this.tableLabel,
    this.orderType,
    this.createdAt,
    this.totalPrice,
  });

  final String id;
  final int? number;
  final String status;
  final String statusLabel;
  final String? tableLabel;
  final String? orderType;
  final String? createdAt;
  final double? totalPrice;

  factory ShiftCloseOpenOrder.fromJson(Map<String, dynamic> json) {
    return ShiftCloseOpenOrder(
      id: json['id']?.toString() ?? '',
      number: json['number'] is num ? (json['number'] as num).toInt() : int.tryParse('${json['number']}'),
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? json['status']?.toString() ?? '',
      tableLabel: json['tableLabel']?.toString(),
      orderType: json['orderType']?.toString(),
      createdAt: json['createdAt']?.toString(),
      totalPrice: json['totalPrice'] is num
          ? (json['totalPrice'] as num).toDouble()
          : double.tryParse('${json['totalPrice']}'),
    );
  }

  String get displayTitle {
    final n = number;
    final base = n != null ? '№$n' : 'Заказ $id';
    final table = tableLabel?.trim();
    if (table != null && table.isNotEmpty) return '$base · $table';
    return base;
  }
}

class ShiftClosePreflight {
  const ShiftClosePreflight({
    required this.canClose,
    required this.blockingCount,
    required this.openOrders,
    this.hint,
  });

  final bool canClose;
  final int blockingCount;
  final List<ShiftCloseOpenOrder> openOrders;
  final String? hint;

  factory ShiftClosePreflight.fromJson(Map<String, dynamic> json) {
    final raw = json['openOrders'];
    final orders = raw is List
        ? raw
              .whereType<Map>()
              .map((e) => ShiftCloseOpenOrder.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <ShiftCloseOpenOrder>[];
    return ShiftClosePreflight(
      canClose: json['canClose'] == true,
      blockingCount: json['blockingCount'] is num
          ? (json['blockingCount'] as num).toInt()
          : orders.length,
      openOrders: orders,
      hint: json['hint']?.toString(),
    );
  }
}

class ShiftClosePreflightRepository {
  ShiftClosePreflightRepository(this._http);

  final HttpClient _http;
  String get _branchId => AppConfig.storeBranchId;

  Future<ShiftClosePreflight> fetchPreflight({String? branchId}) async {
    final res = await _http.get(
      'api/local/shifts/close-preflight',
      query: {'branchId': branchId ?? _branchId},
    );
    final body = res.body;
    if (body is! Map) {
      return const ShiftClosePreflight(canClose: true, blockingCount: 0, openOrders: []);
    }
    return ShiftClosePreflight.fromJson(Map<String, dynamic>.from(body));
  }
}
