import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/config/app_config.dart';
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
    this.methodTitle = '',
    required this.paymentCount,
    required this.totalAmount,
  });

  final String method;
  final String methodTitle;
  final int paymentCount;
  final double totalAmount;

  /// Название для отчёта: «ДС», «Эсхата» и т.д.
  String get displayLabel =>
      methodTitle.trim().isNotEmpty ? methodTitle.trim() : method;
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
    this.methodTitle = '',
    required this.amount,
    required this.createdAtIso,
  });

  final String paymentUuid;
  final String orderId;
  final String orderNumber;
  final String method;
  final String methodTitle;
  final double amount;
  final String createdAtIso;

  String get displayLabel =>
      methodTitle.trim().isNotEmpty ? methodTitle.trim() : method;

  factory AdminSalesPaymentRow.fromJson(Map<String, dynamic> json) {
    final amt = json['amount'];
    return AdminSalesPaymentRow(
      paymentUuid: json['paymentUuid']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      methodTitle: json['methodTitle']?.toString() ?? '',
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
              methodTitle: m['methodTitle']?.toString() ?? '',
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
      branchId: json['branchId']?.toString() ?? '',
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

class AdminSyncWorkerInfo {
  const AdminSyncWorkerInfo({
    required this.enabled,
    required this.intervalMs,
    required this.endpointConfigured,
  });

  final bool enabled;
  final int intervalMs;
  final bool endpointConfigured;
}

class AdminSyncOutboxInfo {
  const AdminSyncOutboxInfo({
    required this.pending,
    required this.retrying,
    required this.failed,
    required this.sent,
    required this.latestEventAt,
  });

  final int pending;
  final int retrying;
  final int failed;
  final int sent;
  final String? latestEventAt;
}

class AdminSyncPushState {
  const AdminSyncPushState({
    required this.lastPushedAt,
    required this.lastSuccessAt,
    required this.lastError,
    required this.lastBatchSent,
  });

  final String? lastPushedAt;
  final String? lastSuccessAt;
  final String? lastError;
  final int lastBatchSent;
}

class AdminSyncPullState {
  const AdminSyncPullState({
    required this.lastPulledAt,
    required this.lastSuccessAt,
    required this.lastError,
    required this.lastCatalogHash,
  });

  final String? lastPulledAt;
  final String? lastSuccessAt;
  final String? lastError;
  final String? lastCatalogHash;
}

class AdminSyncStatus {
  const AdminSyncStatus({
    required this.branchId,
    required this.serverTime,
    required this.pushWorker,
    required this.pullWorker,
    this.siteOrdersWorker,
    required this.outbox,
    required this.pushState,
    required this.pullState,
    this.globalCatalogLocalEditDisabled = false,
  });

  final String branchId;
  final String serverTime;
  final AdminSyncWorkerInfo pushWorker;
  final AdminSyncWorkerInfo pullWorker;
  /// Импорт заказов с сайта (GLOBAL_SITE_ORDERS_SYNC_*).
  final AdminSyncWorkerInfo? siteOrdersWorker;
  final AdminSyncOutboxInfo outbox;
  final AdminSyncPushState? pushState;
  final AdminSyncPullState? pullState;
  /// Сервер: GLOBAL_CATALOG_LOCAL_EDIT_DISABLED — меню только с глобала (pull).
  final bool globalCatalogLocalEditDisabled;
}

class AdminServerEnvGroup {
  const AdminServerEnvGroup({
    required this.id,
    required this.label,
    required this.keys,
  });

  final String id;
  final String label;
  final List<String> keys;
}

class AdminEnvKeyHelp {
  const AdminEnvKeyHelp({
    required this.purpose,
    required this.values,
  });

  final String purpose;
  final String values;
}

class AdminServerEnvConfig {
  const AdminServerEnvConfig({
    required this.groups,
    required this.keyHelp,
    required this.effectivePlain,
    required this.secretIsSet,
    required this.storedOverrideKeys,
    required this.hint,
  });

  final List<AdminServerEnvGroup> groups;
  final Map<String, AdminEnvKeyHelp> keyHelp;
  final Map<String, String> effectivePlain;
  final Map<String, bool> secretIsSet;
  final List<String> storedOverrideKeys;
  final String hint;
}

class AdminSyncActionResult {
  const AdminSyncActionResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class AdminSiteOrderImportFailureRow {
  const AdminSiteOrderImportFailureRow({
    required this.globalSiteOrderId,
    required this.reason,
    required this.detail,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.attemptCount,
    required this.resolvedAt,
  });

  final int globalSiteOrderId;
  final String reason;
  final String? detail;
  final String? firstSeenAt;
  final String? lastSeenAt;
  final int attemptCount;
  final String? resolvedAt;
}

class AdminPaymentCheckItem {
  const AdminPaymentCheckItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String menuItemId;
  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory AdminPaymentCheckItem.fromJson(Map<String, dynamic> json) {
    return AdminPaymentCheckItem(
      menuItemId: json['menuItemId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Товар',
      quantity: _asDouble(json['quantity']),
      unitPrice: _asDouble(json['unitPrice']),
      lineTotal: _asDouble(json['lineTotal']),
    );
  }
}

class AdminPaymentCheckDetail {
  const AdminPaymentCheckDetail({
    required this.paymentUuid,
    required this.orderNumber,
    required this.methodTitle,
    required this.amount,
    required this.createdAtIso,
    required this.items,
  });

  final String paymentUuid;
  final String orderNumber;
  final String methodTitle;
  final double amount;
  final String createdAtIso;
  final List<AdminPaymentCheckItem> items;

  factory AdminPaymentCheckDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => AdminPaymentCheckItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AdminPaymentCheckItem>[];
    return AdminPaymentCheckDetail(
      paymentUuid: json['paymentUuid']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      methodTitle: json['methodTitle']?.toString() ?? json['method']?.toString() ?? '',
      amount: _asDouble(json['amount']),
      createdAtIso: json['createdAt']?.toString() ?? '',
      items: items,
    );
  }
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

class AdminReportsRepository {
  AdminReportsRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<AdminPaymentCheckDetail> fetchPaymentCheck({
    required String paymentUuid,
    String? branchId,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.get(
      'api/local/reports/payments/$paymentUuid/check',
      query: {'branchId': resolvedBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить позиции чека',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ чека');
    }
    return AdminPaymentCheckDetail.fromJson(Map<String, dynamic>.from(body));
  }

  Future<AdminSalesReport> fetchSalesReport({
    required String dateFrom,
    required String dateTo,
    String? branchId,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.get(
      'api/local/reports/sales',
      query: {
        'branchId': resolvedBranchId,
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
    String? branchId,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.get(
      'api/local/reports/kitchen-ops',
      query: {
        'branchId': resolvedBranchId,
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

  Future<AdminSyncStatus> fetchSyncStatus({
    String? branchId,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.get(
      'api/local/sync/status',
      query: {'branchId': resolvedBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить статус синхронизации',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ sync/status');
    }
    final json = Map<String, dynamic>.from(body);

    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    bool asBool(dynamic v) {
      if (v is bool) return v;
      final s = v?.toString().toLowerCase().trim() ?? '';
      return s == 'true' || s == '1' || s == 'yes' || s == 'on';
    }
    String? asNullableString(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return s;
    }

    AdminSyncWorkerInfo parseWorker(dynamic raw) {
      final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return AdminSyncWorkerInfo(
        enabled: asBool(m['enabled']),
        intervalMs: asInt(m['intervalMs']),
        endpointConfigured: asBool(m['endpointConfigured']),
      );
    }

    AdminSyncOutboxInfo parseOutbox(dynamic raw) {
      final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      return AdminSyncOutboxInfo(
        pending: asInt(m['pending']),
        retrying: asInt(m['retrying']),
        failed: asInt(m['failed']),
        sent: asInt(m['sent']),
        latestEventAt: asNullableString(m['latestEventAt']),
      );
    }

    AdminSyncPushState? parsePushState(dynamic raw) {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      return AdminSyncPushState(
        lastPushedAt: asNullableString(m['lastPushedAt']),
        lastSuccessAt: asNullableString(m['lastSuccessAt']),
        lastError: asNullableString(m['lastError']),
        lastBatchSent: asInt(m['lastBatchSent']),
      );
    }

    AdminSyncPullState? parsePullState(dynamic raw) {
      if (raw is! Map) return null;
      final m = Map<String, dynamic>.from(raw);
      return AdminSyncPullState(
        lastPulledAt: asNullableString(m['lastPulledAt']),
        lastSuccessAt: asNullableString(m['lastSuccessAt']),
        lastError: asNullableString(m['lastError']),
        lastCatalogHash: asNullableString(m['lastCatalogHash']),
      );
    }

    final workers = json['workers'] is Map
        ? Map<String, dynamic>.from(json['workers'] as Map)
        : <String, dynamic>{};

    AdminSyncWorkerInfo? siteOrdersParse() {
      final raw = workers['siteOrders'];
      if (raw == null) return null;
      return parseWorker(raw);
    }

    return AdminSyncStatus(
      branchId: json['branchId']?.toString() ?? resolvedBranchId,
      serverTime: json['serverTime']?.toString() ?? '',
      pushWorker: parseWorker(workers['push']),
      pullWorker: parseWorker(workers['pull']),
      siteOrdersWorker: siteOrdersParse(),
      outbox: parseOutbox(json['outbox']),
      pushState: parsePushState(json['pushState']),
      pullState: parsePullState(json['pullState']),
      globalCatalogLocalEditDisabled: asBool(json['globalCatalogLocalEditDisabled']),
    );
  }

  Future<AdminServerEnvConfig> fetchServerEnv() async {
    final res = await _http.get('api/local/server-env');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить настройки сервера',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ server-env');
    }
    final json = Map<String, dynamic>.from(body);
    final rawGroups = json['groups'];
    final groups = <AdminServerEnvGroup>[];
    if (rawGroups is List) {
      for (final g in rawGroups.whereType<Map>()) {
        final m = Map<String, dynamic>.from(g);
        final rawKeys = m['keys'];
        final keys = rawKeys is List
            ? rawKeys.map((e) => e.toString()).toList(growable: false)
            : const <String>[];
        groups.add(
          AdminServerEnvGroup(
            id: m['id']?.toString() ?? '',
            label: m['label']?.toString() ?? '',
            keys: keys,
          ),
        );
      }
    }
    final plainRaw = json['effectivePlain'];
    final effectivePlain = <String, String>{};
    if (plainRaw is Map) {
      for (final e in plainRaw.entries) {
        effectivePlain[e.key.toString()] = e.value?.toString() ?? '';
      }
    }
    final secretRaw = json['secretMeta'];
    final secretIsSet = <String, bool>{};
    if (secretRaw is Map) {
      for (final e in secretRaw.entries) {
        final key = e.key.toString();
        final v = e.value;
        if (v is Map) {
          final mm = Map<String, dynamic>.from(v);
          secretIsSet[key] = mm['isSet'] == true || mm['isSet'].toString() == '1';
        }
      }
    }
    final storedRaw = json['storedOverrideKeys'];
    final storedOverrideKeys = storedRaw is List
        ? storedRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final hint = json['hint']?.toString() ?? '';

    final keyHelp = <String, AdminEnvKeyHelp>{};
    final rawHelp = json['keyHelp'];
    if (rawHelp is Map) {
      for (final e in rawHelp.entries) {
        final key = e.key.toString();
        final v = e.value;
        if (v is! Map) continue;
        final m = Map<String, dynamic>.from(v);
        keyHelp[key] = AdminEnvKeyHelp(
          purpose: m['purpose']?.toString() ?? '',
          values: m['values']?.toString() ?? '',
        );
      }
    }

    return AdminServerEnvConfig(
      groups: groups,
      keyHelp: keyHelp,
      effectivePlain: Map<String, String>.from(effectivePlain),
      secretIsSet: secretIsSet,
      storedOverrideKeys: storedOverrideKeys,
      hint: hint,
    );
  }

  Future<AdminSyncActionResult> saveServerEnv({
    required Map<String, String> upsert,
    List<String> removeKeys = const [],
  }) async {
    final res = await _http.patch(
      'api/local/server-env',
      body: {
        'upsert': upsert,
        'removeKeys': removeKeys,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось сохранить настройки сервера',
      );
    }
    final body = res.body;
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final msg = map['message']?.toString() ?? 'Сохранено. Перезапустите backend.';
    return AdminSyncActionResult(ok: true, message: msg);
  }

  Future<AdminSyncActionResult> triggerPushNow({
    String? branchId,
    int limit = 50,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.post(
      'api/local/sync/push-global',
      body: {
        'branchId': resolvedBranchId,
        'limit': limit,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Push в global не выполнен',
      );
    }
    final body = res.body;
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final sentRaw = map['sent'];
    final sent = sentRaw is num ? sentRaw.toInt() : int.tryParse(sentRaw?.toString() ?? '') ?? 0;
    return AdminSyncActionResult(ok: true, message: 'Push выполнен: отправлено $sent событий');
  }

  Future<AdminSyncActionResult> triggerPullNow({
    String? branchId,
  }) async {
    final resolvedBranchId = (branchId == null || branchId.trim().isEmpty)
        ? _defaultBranchId
        : branchId.trim();
    final res = await _http.post(
      'api/local/sync/pull-global',
      body: {'branchId': resolvedBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Pull каталога не выполнен',
      );
    }
    final body = res.body;
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final skipped = map['skippedNoChanges'] == true;
    if (skipped) {
      return const AdminSyncActionResult(ok: true, message: 'Pull: изменений каталога нет');
    }
    final cRaw = map['categoriesSynced'];
    final pRaw = map['productsSynced'];
    final categories = cRaw is num ? cRaw.toInt() : int.tryParse(cRaw?.toString() ?? '') ?? 0;
    final products = pRaw is num ? pRaw.toInt() : int.tryParse(pRaw?.toString() ?? '') ?? 0;
    return AdminSyncActionResult(
      ok: true,
      message: 'Pull выполнен: категорий $categories, товаров $products',
    );
  }

  Future<List<AdminSiteOrderImportFailureRow>> fetchSiteOrderFailures({
    int limit = 100,
    bool includeResolved = false,
  }) async {
    final res = await _http.get(
      'api/local/sync/site-order-failures',
      query: {
        'limit': '$limit',
        'includeResolved': includeResolved ? 'true' : 'false',
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить проблемные сайт-заказы',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ site-order-failures');
    }
    final map = Map<String, dynamic>.from(body);
    final rawItems = map['items'];
    if (rawItems is! List) return const [];
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    String? asNullableString(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return s;
    }

    return rawItems
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          return AdminSiteOrderImportFailureRow(
            globalSiteOrderId: asInt(m['globalSiteOrderId']),
            reason: m['reason']?.toString() ?? '',
            detail: asNullableString(m['detail']),
            firstSeenAt: asNullableString(m['firstSeenAt']),
            lastSeenAt: asNullableString(m['lastSeenAt']),
            attemptCount: asInt(m['attemptCount']),
            resolvedAt: asNullableString(m['resolvedAt']),
          );
        })
        .toList(growable: false);
  }

  Future<AdminSyncActionResult> retrySiteOrderFailures({
    int? globalSiteOrderId,
  }) async {
    final body = <String, dynamic>{};
    if (globalSiteOrderId != null && globalSiteOrderId > 0) {
      body['globalSiteOrderId'] = globalSiteOrderId;
    }
    final res = await _http.post(
      'api/local/sync/site-order-failures/retry',
      body: body,
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить повторный импорт',
      );
    }
    return const AdminSyncActionResult(
      ok: true,
      message: 'Retry выполнен: проверяйте статус ниже.',
    );
  }

  Future<AdminSyncActionResult> resolveSiteOrderFailure({
    required int globalSiteOrderId,
  }) async {
    final res = await _http.patch(
      'api/local/sync/site-order-failures/$globalSiteOrderId/resolve',
      body: const <String, dynamic>{},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось закрыть инцидент',
      );
    }
    return const AdminSyncActionResult(
      ok: true,
      message: 'Инцидент помечен как resolved.',
    );
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
    required this.kitchenButtonId,
    required this.kitchenButtonName,
    required this.kitchenButtonColorHex,
    required this.ordersAcceptedCount,
    required this.itemsAccepted,
    required this.ordersReadyCount,
    required this.itemsReady,
    required this.spentSeconds,
  });

  final int userId;
  final String username;
  final String role;
  final int kitchenButtonId;
  final String kitchenButtonName;
  final String kitchenButtonColorHex;
  final int ordersAcceptedCount;
  final int itemsAccepted;
  final int ordersReadyCount;
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
          kitchenButtonId: asInt(m['kitchenButtonId']),
          kitchenButtonName: asString(m['kitchenButtonName']),
          kitchenButtonColorHex: asString(m['kitchenButtonColorHex']),
          ordersAcceptedCount: asInt(m['ordersAcceptedCount']),
          itemsAccepted: asInt(m['itemsAccepted']),
          ordersReadyCount: asInt(m['ordersReadyCount']),
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
