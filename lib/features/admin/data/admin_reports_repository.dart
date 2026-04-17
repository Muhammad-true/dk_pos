import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class AdminSalesReportSummary {
  const AdminSalesReportSummary({
    required this.paymentCount,
    required this.totalAmount,
  });

  final int paymentCount;
  final double totalAmount;
}

class AdminSalesMethodBreakdown {
  const AdminSalesMethodBreakdown({
    required this.method,
    required this.paymentCount,
    required this.totalAmount,
  });

  final String method;
  final int paymentCount;
  final double totalAmount;
}

class AdminSalesDayBreakdown {
  const AdminSalesDayBreakdown({
    required this.day,
    required this.paymentCount,
    required this.totalAmount,
  });

  final String day;
  final int paymentCount;
  final double totalAmount;
}

class AdminSalesPaymentRow {
  const AdminSalesPaymentRow({
    required this.paymentUuid,
    required this.orderId,
    required this.orderNumber,
    required this.method,
    required this.amount,
    required this.createdAtIso,
  });

  final String paymentUuid;
  final String orderId;
  final String orderNumber;
  final String method;
  final double amount;
  final String createdAtIso;

  factory AdminSalesPaymentRow.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'];
    return AdminSalesPaymentRow(
      paymentUuid: json['paymentUuid']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      amount: amt is num ? amt.toDouble() : double.tryParse(amt?.toString() ?? '') ?? 0,
      createdAtIso: json['createdAt']?.toString() ?? '',
    );
  }
}

class AdminAcceptedByRow {
  const AdminAcceptedByRow({
    required this.userId,
    required this.username,
    required this.role,
    required this.paymentCount,
    required this.totalAmount,
  });

  final int userId;
  final String username;
  final String role;
  final int paymentCount;
  final double totalAmount;
}

class AdminKitchenStationRow {
  const AdminKitchenStationRow({
    required this.stationId,
    required this.stationName,
    required this.ordersCount,
    required this.itemsQuantity,
  });

  final int stationId;
  final String stationName;
  final int ordersCount;
  final int itemsQuantity;
}

class AdminWaiterSummary {
  const AdminWaiterSummary({required this.ordersAcceptedCount});

  final int ordersAcceptedCount;
}

class AdminCashierRevenueSummary {
  const AdminCashierRevenueSummary({
    required this.totalAmount,
    required this.byUser,
  });

  final double totalAmount;
  final List<AdminAcceptedByRow> byUser;
}

class AdminSalesReport {
  const AdminSalesReport({
    required this.branchId,
    required this.dateFrom,
    required this.dateTo,
    required this.summary,
    required this.byMethod,
    required this.byDay,
    required this.payments,
    required this.acceptedBy,
    required this.kitchenByStation,
    required this.waiterSummary,
    required this.cashierRevenue,
  });

  final String branchId;
  final String dateFrom;
  final String dateTo;
  final AdminSalesReportSummary summary;
  final List<AdminSalesMethodBreakdown> byMethod;
  final List<AdminSalesDayBreakdown> byDay;
  final List<AdminSalesPaymentRow> payments;
  final List<AdminAcceptedByRow> acceptedBy;
  final List<AdminKitchenStationRow> kitchenByStation;
  final AdminWaiterSummary waiterSummary;
  final AdminCashierRevenueSummary cashierRevenue;

  factory AdminSalesReport.fromJson(Map<String, dynamic> json) {
    final sumRaw = json['summary'];
    final sum = sumRaw is Map ? Map<String, dynamic>.from(sumRaw) : <String, dynamic>{};
    final pc = sum['paymentCount'];
    final ta = sum['totalAmount'];
    final summary = AdminSalesReportSummary(
      paymentCount: pc is num ? pc.toInt() : int.tryParse(pc?.toString() ?? '') ?? 0,
      totalAmount: ta is num ? ta.toDouble() : double.tryParse(ta?.toString() ?? '') ?? 0,
    );

    List<AdminSalesMethodBreakdown> parseMethods(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final c = m['paymentCount'];
            final t = m['totalAmount'];
            return AdminSalesMethodBreakdown(
              method: m['method']?.toString() ?? '',
              paymentCount: c is num ? c.toInt() : int.tryParse(c?.toString() ?? '') ?? 0,
              totalAmount: t is num ? t.toDouble() : double.tryParse(t?.toString() ?? '') ?? 0,
            );
          })
          .toList(growable: false);
    }

    List<AdminSalesDayBreakdown> parseDays(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final c = m['paymentCount'];
            final t = m['totalAmount'];
            return AdminSalesDayBreakdown(
              day: m['day']?.toString() ?? '',
              paymentCount: c is num ? c.toInt() : int.tryParse(c?.toString() ?? '') ?? 0,
              totalAmount: t is num ? t.toDouble() : double.tryParse(t?.toString() ?? '') ?? 0,
            );
          })
          .toList(growable: false);
    }

    List<AdminSalesPaymentRow> parsePayments(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => AdminSalesPaymentRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    List<AdminAcceptedByRow> parseAcceptedBy(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final uid = m['userId'];
            final c = m['paymentCount'];
            final t = m['totalAmount'];
            return AdminAcceptedByRow(
              userId: uid is num ? uid.toInt() : int.tryParse(uid?.toString() ?? '') ?? 0,
              username: m['username']?.toString() ?? '',
              role: m['role']?.toString() ?? '',
              paymentCount: c is num ? c.toInt() : int.tryParse(c?.toString() ?? '') ?? 0,
              totalAmount: t is num ? t.toDouble() : double.tryParse(t?.toString() ?? '') ?? 0,
            );
          })
          .toList(growable: false);
    }

    List<AdminKitchenStationRow> parseKitchenByStation(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final sid = m['stationId'];
            final oc = m['ordersCount'];
            final iq = m['itemsQuantity'];
            return AdminKitchenStationRow(
              stationId: sid is num ? sid.toInt() : int.tryParse(sid?.toString() ?? '') ?? 0,
              stationName: m['stationName']?.toString() ?? '',
              ordersCount: oc is num ? oc.toInt() : int.tryParse(oc?.toString() ?? '') ?? 0,
              itemsQuantity: iq is num ? iq.toInt() : int.tryParse(iq?.toString() ?? '') ?? 0,
            );
          })
          .toList(growable: false);
    }

    AdminWaiterSummary parseWaiterSummary(dynamic raw) {
      if (raw is! Map) return const AdminWaiterSummary(ordersAcceptedCount: 0);
      final m = Map<String, dynamic>.from(raw);
      final c = m['ordersAcceptedCount'];
      return AdminWaiterSummary(
        ordersAcceptedCount: c is num ? c.toInt() : int.tryParse(c?.toString() ?? '') ?? 0,
      );
    }

    AdminCashierRevenueSummary parseCashierRevenue(dynamic raw) {
      if (raw is! Map) {
        return const AdminCashierRevenueSummary(totalAmount: 0, byUser: []);
      }
      final m = Map<String, dynamic>.from(raw);
      final t = m['totalAmount'];
      return AdminCashierRevenueSummary(
        totalAmount: t is num ? t.toDouble() : double.tryParse(t?.toString() ?? '') ?? 0,
        byUser: parseAcceptedBy(m['byUser']),
      );
    }

    return AdminSalesReport(
      branchId: json['branchId']?.toString() ?? 'branch_1',
      dateFrom: json['dateFrom']?.toString() ?? '',
      dateTo: json['dateTo']?.toString() ?? '',
      summary: summary,
      byMethod: parseMethods(json['byMethod']),
      byDay: parseDays(json['byDay']),
      payments: parsePayments(json['payments']),
      acceptedBy: parseAcceptedBy(json['acceptedBy']),
      kitchenByStation: parseKitchenByStation(json['kitchenByStation']),
      waiterSummary: parseWaiterSummary(json['waiterSummary']),
      cashierRevenue: parseCashierRevenue(json['cashierRevenue']),
    );
  }
}

class AdminReportsRepository {
  AdminReportsRepository(this._http);

  final HttpClient _http;

  Future<AdminSalesReport> fetchSalesReport({
    required String dateFrom,
    required String dateTo,
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/reports/sales',
      query: {
        'branchId': branchId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить отчёт по продажам',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ отчёта по продажам');
    }
    return AdminSalesReport.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminKitchenOpsReport> fetchKitchenOpsReport({
    required String dateFrom,
    required String dateTo,
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/reports/kitchen-ops',
      query: {
        'branchId': branchId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить операционный отчёт кухни',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ kitchen-ops');
    }
    return AdminKitchenOpsReport.fromJson(Map<String, dynamic>.from(body));
  }
}

class AdminShiftRow {
  const AdminShiftRow({
    required this.id,
    required this.userId,
    required this.username,
    required this.role,
    required this.branchId,
    required this.terminalId,
    required this.openedAtIso,
    required this.closedAtIso,
    required this.durationSeconds,
  });

  final int id;
  final int userId;
  final String username;
  final String role;
  final String branchId;
  final String? terminalId;
  final String openedAtIso;
  final String? closedAtIso;
  final int durationSeconds;
}

class AdminKitchenUserOpsRow {
  const AdminKitchenUserOpsRow({
    required this.userId,
    required this.username,
    required this.role,
    required this.ordersCount,
    required this.itemsReady,
    required this.spentSeconds,
  });

  final int userId;
  final String username;
  final String role;
  final int ordersCount;
  final int itemsReady;
  final int spentSeconds;
}

class AdminKitchenStationOpsRow {
  const AdminKitchenStationOpsRow({
    required this.stationId,
    required this.stationName,
    required this.ordersCount,
    required this.itemsReady,
    required this.spentSeconds,
  });

  final int stationId;
  final String stationName;
  final int ordersCount;
  final int itemsReady;
  final int spentSeconds;
}

class AdminKitchenOpsReport {
  const AdminKitchenOpsReport({
    required this.branchId,
    required this.dateFrom,
    required this.dateTo,
    required this.shifts,
    required this.kitchenByUser,
    required this.kitchenByStation,
  });

  final String branchId;
  final String dateFrom;
  final String dateTo;
  final List<AdminShiftRow> shifts;
  final List<AdminKitchenUserOpsRow> kitchenByUser;
  final List<AdminKitchenStationOpsRow> kitchenByStation;

  factory AdminKitchenOpsReport.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    String asString(dynamic v) => v?.toString() ?? '';

    List<AdminShiftRow> parseShifts(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return AdminShiftRow(
          id: asInt(m['id']),
          userId: asInt(m['userId']),
          username: asString(m['username']),
          role: asString(m['role']),
          branchId: asString(m['branchId']),
          terminalId: m['terminalId']?.toString(),
          openedAtIso: asString(m['openedAt']),
          closedAtIso: m['closedAt']?.toString(),
          durationSeconds: asInt(m['durationSeconds']),
        );
      }).toList(growable: false);
    }

    List<AdminKitchenUserOpsRow> parseByUser(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return AdminKitchenUserOpsRow(
          userId: asInt(m['userId']),
          username: asString(m['username']),
          role: asString(m['role']),
          ordersCount: asInt(m['ordersCount']),
          itemsReady: asInt(m['itemsReady']),
          spentSeconds: asInt(m['spentSeconds']),
        );
      }).toList(growable: false);
    }

    List<AdminKitchenStationOpsRow> parseByStation(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return AdminKitchenStationOpsRow(
          stationId: asInt(m['stationId']),
          stationName: asString(m['stationName']),
          ordersCount: asInt(m['ordersCount']),
          itemsReady: asInt(m['itemsReady']),
          spentSeconds: asInt(m['spentSeconds']),
        );
      }).toList(growable: false);
    }

    return AdminKitchenOpsReport(
      branchId: asString(json['branchId']),
      dateFrom: asString(json['dateFrom']),
      dateTo: asString(json['dateTo']),
      shifts: parseShifts(json['shifts']),
      kitchenByUser: parseByUser(json['kitchenByUser']),
      kitchenByStation: parseByStation(json['kitchenByStation']),
    );
  }
}
