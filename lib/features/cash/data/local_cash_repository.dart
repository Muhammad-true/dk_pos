import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class CashEncashmentHint {
  const CashEncashmentHint({
    required this.recommendedAmount,
    required this.expectedInDrawer,
    required this.minReserve,
    required this.openingBalance,
    required this.cashSalesIn,
    required this.cashRefundsOut,
    required this.operationsIn,
    required this.operationsOut,
    this.lastEncashmentAt,
    this.lastEncashmentAmount,
  });

  final double recommendedAmount;
  final double expectedInDrawer;
  final double minReserve;
  final double openingBalance;
  final double cashSalesIn;
  final double cashRefundsOut;
  final double operationsIn;
  final double operationsOut;
  final String? lastEncashmentAt;
  final double? lastEncashmentAmount;

  factory CashEncashmentHint.fromJson(Map<String, dynamic> json) {
    return CashEncashmentHint(
      recommendedAmount: CashShiftSnapshot._asDouble(json['recommendedAmount']),
      expectedInDrawer: CashShiftSnapshot._asDouble(json['expectedInDrawer']),
      minReserve: CashShiftSnapshot._asDouble(json['minReserve']),
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
      cashSalesIn: CashShiftSnapshot._asDouble(json['cashSalesIn']),
      cashRefundsOut: CashShiftSnapshot._asDouble(json['cashRefundsOut']),
      operationsIn: CashShiftSnapshot._asDouble(json['operationsIn']),
      operationsOut: CashShiftSnapshot._asDouble(json['operationsOut']),
      lastEncashmentAt: json['lastEncashmentAt']?.toString(),
      lastEncashmentAmount: json['lastEncashmentAmount'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['lastEncashmentAmount']),
    );
  }
}

class CashShiftSnapshot {
  const CashShiftSnapshot({
    required this.hasOpenShift,
    required this.availableCash,
    required this.expectedInDrawer,
    required this.openingBalance,
    required this.cashSalesIn,
    required this.cashRefundsOut,
    required this.operationsIn,
    required this.operationsOut,
    required this.minReserve,
    this.shift,
    this.encashmentHint,
  });

  final bool hasOpenShift;
  final double availableCash;
  final double expectedInDrawer;
  final double openingBalance;
  final double cashSalesIn;
  final double cashRefundsOut;
  final double operationsIn;
  final double operationsOut;
  final double minReserve;
  final CashShiftInfo? shift;
  final CashEncashmentHint? encashmentHint;

  factory CashShiftSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final shiftMap = asMap(json['shift']);
    final hintMap = asMap(json['encashmentHint']);
    return CashShiftSnapshot(
      hasOpenShift: json['hasOpenShift'] == true,
      availableCash: _asDouble(json['availableCash']),
      expectedInDrawer: _asDouble(json['expectedInDrawer']),
      openingBalance: _asDouble(json['openingBalance']),
      cashSalesIn: _asDouble(json['cashSalesIn']),
      cashRefundsOut: _asDouble(json['cashRefundsOut']),
      operationsIn: _asDouble(json['operationsIn']),
      operationsOut: _asDouble(json['operationsOut']),
      minReserve: _asDouble(json['minReserve']),
      shift: shiftMap == null ? null : CashShiftInfo.fromJson(shiftMap),
      encashmentHint:
          hintMap == null ? null : CashEncashmentHint.fromJson(hintMap),
    );
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class CashShiftInfo {
  const CashShiftInfo({
    required this.shiftUuid,
    required this.openingBalance,
    this.openedAt,
    this.closingExpected,
    this.closingActual,
    this.variance,
  });

  final String shiftUuid;
  final double openingBalance;
  final String? openedAt;
  final double? closingExpected;
  final double? closingActual;
  final double? variance;

  factory CashShiftInfo.fromJson(Map<String, dynamic> json) {
    return CashShiftInfo(
      shiftUuid: json['shiftUuid']?.toString() ?? '',
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
      openedAt: json['openedAt']?.toString(),
      closingExpected: json['closingExpected'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingExpected']),
      closingActual: json['closingActual'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingActual']),
      variance: json['variance'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['variance']),
    );
  }
}

class CashOperationInfo {
  const CashOperationInfo({
    required this.operationUuid,
    required this.opType,
    required this.direction,
    required this.amount,
    this.comment,
    this.createdAt,
  });

  final String operationUuid;
  final String opType;
  final String direction;
  final double amount;
  final String? comment;
  final String? createdAt;

  factory CashOperationInfo.fromJson(Map<String, dynamic> json) {
    return CashOperationInfo(
      operationUuid: json['operationUuid']?.toString() ?? '',
      opType: json['opType']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      amount: CashShiftSnapshot._asDouble(json['amount']),
      comment: json['comment']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class CashOperationResult {
  const CashOperationResult({
    required this.operation,
    required this.snapshot,
    this.hardwareHint,
  });

  final CashOperationInfo operation;
  final CashShiftSnapshot snapshot;
  final String? hardwareHint;
}

class CashShiftGlobalSync {
  const CashShiftGlobalSync({
    required this.status,
    required this.ok,
    this.eventId,
    this.message,
    this.lastError,
    this.sentAt,
    this.retryCount = 0,
  });

  final String status;
  final bool ok;
  final String? eventId;
  final String? message;
  final String? lastError;
  final String? sentAt;
  final int retryCount;

  factory CashShiftGlobalSync.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CashShiftGlobalSync(status: 'unknown', ok: false);
    }
    return CashShiftGlobalSync(
      status: json['status']?.toString() ?? 'unknown',
      ok: json['ok'] == true,
      eventId: json['eventId']?.toString(),
      message: json['message']?.toString(),
      lastError: json['lastError']?.toString(),
      sentAt: json['sentAt']?.toString(),
      retryCount: json['retryCount'] is num
          ? (json['retryCount'] as num).toInt()
          : int.tryParse(json['retryCount']?.toString() ?? '') ?? 0,
    );
  }

  String get shortLabel {
    if (ok || status == 'sent') return 'Отправлено';
    if (status == 'pending') return 'В очереди';
    if (status == 'failed') return 'Ошибка';
    if (status == 'missing') return 'Нет данных';
    return status;
  }
}

class CashShiftListPreview {
  const CashShiftListPreview({
    required this.totalSalesNet,
    required this.nonCashNet,
    required this.cashSalesIn,
    required this.encashmentTotal,
    required this.nonCashByMethod,
    this.encashmentDone = false,
    this.closingActual,
    this.cashAboveReserve,
    this.minReserve,
  });

  final double totalSalesNet;
  final double nonCashNet;
  final double cashSalesIn;
  final double encashmentTotal;
  final List<CashShiftPaymentMethodRow> nonCashByMethod;
  final bool encashmentDone;
  final double? closingActual;
  final double? cashAboveReserve;
  final double? minReserve;

  factory CashShiftListPreview.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CashShiftListPreview(
        totalSalesNet: 0,
        nonCashNet: 0,
        cashSalesIn: 0,
        encashmentTotal: 0,
        nonCashByMethod: [],
      );
    }
    final banksRaw = json['nonCashByMethod'];
    final banks = banksRaw is List
        ? banksRaw
              .whereType<Map>()
              .map(
                (e) => CashShiftPaymentMethodRow.fromJson({
                  ...Map<String, dynamic>.from(e),
                  'key': e['key'] ?? e['method'] ?? '',
                  'method': e['method'] ?? 'card',
                  'isCash': false,
                  'paymentsIn': e['paymentsIn'] ?? e['net'] ?? 0,
                  'refundsOut': e['refundsOut'] ?? 0,
                }),
              )
              .toList()
        : <CashShiftPaymentMethodRow>[];
    return CashShiftListPreview(
      totalSalesNet: CashShiftSnapshot._asDouble(json['totalSalesNet']),
      nonCashNet: CashShiftSnapshot._asDouble(json['nonCashNet']),
      cashSalesIn: CashShiftSnapshot._asDouble(json['cashSalesIn']),
      encashmentTotal: CashShiftSnapshot._asDouble(json['encashmentTotal']),
      encashmentDone: json['encashmentDone'] == true ||
          CashShiftSnapshot._asDouble(json['encashmentTotal']) > 0.009,
      closingActual: json['closingActual'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingActual']),
      cashAboveReserve: json['cashAboveReserve'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['cashAboveReserve']),
      minReserve: json['minReserve'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['minReserve']),
      nonCashByMethod: banks,
    );
  }

  String get nonCashBrief {
    if (nonCashByMethod.isEmpty) return '—';
    return nonCashByMethod.map((m) => '${m.title}: ${m.net.toStringAsFixed(0)}').join(', ');
  }
}

class CashEncashmentAlert {
  const CashEncashmentAlert({
    required this.shiftsWithoutEncashment,
    required this.message,
    this.daysSinceEncashment,
    this.lastEncashmentAt,
    this.lastEncashmentAmount,
  });

  final int shiftsWithoutEncashment;
  final String message;
  final int? daysSinceEncashment;
  final String? lastEncashmentAt;
  final double? lastEncashmentAmount;

  factory CashEncashmentAlert.fromJson(Map<String, dynamic> json) {
    return CashEncashmentAlert(
      shiftsWithoutEncashment: int.tryParse('${json['shifts_without_encashment']}') ?? 0,
      message: json['message']?.toString() ?? '',
      daysSinceEncashment: json['days_since_encashment'] == null
          ? null
          : int.tryParse('${json['days_since_encashment']}'),
      lastEncashmentAt: json['last_encashment_at']?.toString(),
      lastEncashmentAmount: json['last_encashment_amount'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['last_encashment_amount']),
    );
  }
}

class CashClosedShiftsResult {
  const CashClosedShiftsResult({
    required this.items,
    this.encashmentAlert,
  });

  final List<CashShiftListItem> items;
  final CashEncashmentAlert? encashmentAlert;
}

class CashShiftListItem {
  const CashShiftListItem({
    required this.id,
    required this.shiftUuid,
    required this.openingBalance,
    this.openedAt,
    this.closedAt,
    this.closingExpected,
    this.closingActual,
    this.variance,
    this.openedByUsername,
    this.closedByUsername,
    this.closeNotes,
    this.terminalId,
    this.globalSync,
    this.preview,
  });

  final String id;
  final String shiftUuid;
  final double openingBalance;
  final String? openedAt;
  final String? closedAt;
  final double? closingExpected;
  final double? closingActual;
  final double? variance;
  final String? openedByUsername;
  final String? closedByUsername;
  final String? closeNotes;
  final String? terminalId;
  final CashShiftGlobalSync? globalSync;
  final CashShiftListPreview? preview;

  factory CashShiftListItem.fromJson(Map<String, dynamic> json) {
    final previewMap = json['preview'];
    return CashShiftListItem(
      id: json['id']?.toString() ?? '',
      shiftUuid: json['shiftUuid']?.toString() ?? '',
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
      openedAt: json['openedAt']?.toString(),
      closedAt: json['closedAt']?.toString(),
      closingExpected: json['closingExpected'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingExpected']),
      closingActual: json['closingActual'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingActual']),
      variance: json['variance'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['variance']),
      openedByUsername: json['openedByUsername']?.toString(),
      closedByUsername: json['closedByUsername']?.toString(),
      closeNotes: json['closeNotes']?.toString(),
      terminalId: json['terminalId']?.toString(),
      globalSync: json['globalSync'] is Map
          ? CashShiftGlobalSync.fromJson(
              Map<String, dynamic>.from(json['globalSync'] as Map),
            )
          : null,
      preview: previewMap is Map
          ? CashShiftListPreview.fromJson(Map<String, dynamic>.from(previewMap))
          : null,
    );
  }
}

class CashShiftPaymentMethodRow {
  const CashShiftPaymentMethodRow({
    required this.key,
    required this.method,
    required this.title,
    required this.paymentsIn,
    required this.refundsOut,
    required this.net,
    required this.isCash,
    this.expectedNet,
    this.actualNet,
    this.variance,
  });

  final String key;
  final String method;
  final String title;
  final double paymentsIn;
  final double refundsOut;
  final double net;
  final bool isCash;
  final double? expectedNet;
  final double? actualNet;
  final double? variance;

  double get displayExpected => expectedNet ?? net;

  factory CashShiftPaymentMethodRow.fromJson(Map<String, dynamic> json) {
    final expected = json['expectedNet'] == null
        ? CashShiftSnapshot._asDouble(json['net'])
        : CashShiftSnapshot._asDouble(json['expectedNet']);
    return CashShiftPaymentMethodRow(
      key: json['key']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      paymentsIn: CashShiftSnapshot._asDouble(json['paymentsIn']),
      refundsOut: CashShiftSnapshot._asDouble(json['refundsOut']),
      net: CashShiftSnapshot._asDouble(json['net']),
      isCash: json['isCash'] == true,
      expectedNet: expected,
      actualNet: json['actualNet'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['actualNet']),
      variance: json['variance'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['variance']),
    );
  }
}

class CashCloseBankPreviewRow {
  const CashCloseBankPreviewRow({
    required this.key,
    required this.title,
    required this.expectedNet,
    required this.paymentsIn,
    required this.refundsOut,
  });

  final String key;
  final String title;
  final double expectedNet;
  final double paymentsIn;
  final double refundsOut;

  factory CashCloseBankPreviewRow.fromJson(Map<String, dynamic> json) {
    return CashCloseBankPreviewRow(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      expectedNet: CashShiftSnapshot._asDouble(json['expectedNet']),
      paymentsIn: CashShiftSnapshot._asDouble(json['paymentsIn']),
      refundsOut: CashShiftSnapshot._asDouble(json['refundsOut']),
    );
  }
}

class CashCloseShiftPreview {
  const CashCloseShiftPreview({
    required this.hasOpenShift,
    required this.expectedInDrawer,
    required this.banks,
    this.nonCashExpectedTotal = 0,
    this.openingBalance = 0,
    this.cashSalesIn = 0,
    this.cashRefundsOut = 0,
    this.encashmentTotal = 0,
    this.encashmentDone = false,
    this.totalSalesNet = 0,
  });

  final bool hasOpenShift;
  final double expectedInDrawer;
  final double nonCashExpectedTotal;
  final double openingBalance;
  final double cashSalesIn;
  final double cashRefundsOut;
  final double encashmentTotal;
  final bool encashmentDone;
  final double totalSalesNet;
  final List<CashCloseBankPreviewRow> banks;

  factory CashCloseShiftPreview.fromJson(Map<String, dynamic> json) {
    final banksRaw = json['banks'];
    final encashmentTotal = CashShiftSnapshot._asDouble(json['encashmentTotal']);
    return CashCloseShiftPreview(
      hasOpenShift: json['hasOpenShift'] == true,
      expectedInDrawer: CashShiftSnapshot._asDouble(json['expectedInDrawer']),
      nonCashExpectedTotal:
          CashShiftSnapshot._asDouble(json['nonCashExpectedTotal']),
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
      cashSalesIn: CashShiftSnapshot._asDouble(json['cashSalesIn']),
      cashRefundsOut: CashShiftSnapshot._asDouble(json['cashRefundsOut']),
      encashmentTotal: encashmentTotal,
      encashmentDone: json['encashmentDone'] == true || encashmentTotal > 0.009,
      totalSalesNet: CashShiftSnapshot._asDouble(json['totalSalesNet']),
      banks: banksRaw is List
          ? banksRaw
                .whereType<Map>()
                .map(
                  (e) => CashCloseBankPreviewRow.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class CashShiftWithdrawalRow {
  const CashShiftWithdrawalRow({
    required this.opType,
    required this.label,
    required this.amount,
  });

  final String opType;
  final String label;
  final double amount;

  factory CashShiftWithdrawalRow.fromJson(Map<String, dynamic> json) {
    return CashShiftWithdrawalRow(
      opType: json['opType']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      amount: CashShiftSnapshot._asDouble(json['amount']),
    );
  }
}

class CashShiftReportSummary {
  const CashShiftReportSummary({
    required this.cashSalesIn,
    required this.cashRefundsOut,
    required this.operationsIn,
    required this.operationsOut,
    required this.openingBalance,
    required this.nonCashNet,
    required this.totalSalesNet,
    required this.nonCashByMethod,
    required this.withdrawalRows,
    required this.offRegisterOut,
    required this.encashmentTotal,
    this.closingExpected,
    this.closingActual,
    this.variance,
    this.minReserve,
    this.encashmentDone = false,
    this.cashAboveReserve,
    this.nonCashVarianceTotal,
  });

  final double cashSalesIn;
  final double cashRefundsOut;
  final double operationsIn;
  final double operationsOut;
  final double openingBalance;
  final double nonCashNet;
  final double totalSalesNet;
  final List<CashShiftPaymentMethodRow> nonCashByMethod;
  final List<CashShiftWithdrawalRow> withdrawalRows;
  final double offRegisterOut;
  final double encashmentTotal;
  final double? closingExpected;
  final double? closingActual;
  final double? variance;
  final double? minReserve;
  final bool encashmentDone;
  final double? cashAboveReserve;
  final double? nonCashVarianceTotal;

  bool get encashmentWasDone => encashmentDone || encashmentTotal > 0.009;

  factory CashShiftReportSummary.fromJson(Map<String, dynamic> json) {
    List<CashShiftPaymentMethodRow> parseNonCashMethods(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => CashShiftPaymentMethodRow.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => !m.isCash && m.method != 'cash')
          .toList();
    }

    List<CashShiftWithdrawalRow> parseWithdrawals(Map<String, dynamic> j) {
      final top = j['withdrawalRows'];
      if (top is List) {
        return top
            .whereType<Map>()
            .map((e) => CashShiftWithdrawalRow.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final ob = j['operationsBreakdown'];
      if (ob is Map) {
        final rows = ob['withdrawalRows'];
        if (rows is List) {
          return rows
              .whereType<Map>()
              .map((e) => CashShiftWithdrawalRow.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
      return const [];
    }

    final withdrawals = parseWithdrawals(json);
    final encFromRows = withdrawals
        .where(
          (w) =>
              w.opType == 'encashment' || w.opType == 'encashment_off_register',
        )
        .fold<double>(0, (s, w) => s + w.amount);
    final encashmentTotal = json['encashmentTotal'] == null
        ? encFromRows
        : CashShiftSnapshot._asDouble(json['encashmentTotal']);

    final nonCashTop = json['nonCashByMethod'];
    final nonCashByMethod = nonCashTop is List
        ? parseNonCashMethods(nonCashTop)
        : parseNonCashMethods(json['paymentsByMethod']);

    return CashShiftReportSummary(
      cashSalesIn: CashShiftSnapshot._asDouble(json['cashSalesIn']),
      cashRefundsOut: CashShiftSnapshot._asDouble(json['cashRefundsOut']),
      operationsIn: CashShiftSnapshot._asDouble(json['operationsIn']),
      operationsOut: CashShiftSnapshot._asDouble(json['operationsOut']),
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
      nonCashNet: CashShiftSnapshot._asDouble(json['nonCashNet']),
      totalSalesNet: CashShiftSnapshot._asDouble(json['totalSalesNet']),
      nonCashByMethod: nonCashByMethod,
      withdrawalRows: withdrawals,
      offRegisterOut: CashShiftSnapshot._asDouble(
        json['offRegisterOut'] ?? json['operationsBreakdown']?['offRegisterOut'],
      ),
      encashmentTotal: encashmentTotal,
      encashmentDone: json['encashmentDone'] == true || encashmentTotal > 0.009,
      minReserve: json['minReserve'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['minReserve']),
      cashAboveReserve: json['cashAboveReserve'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['cashAboveReserve']),
      closingExpected: json['closingExpected'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingExpected']),
      closingActual: json['closingActual'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['closingActual']),
      variance: json['variance'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['variance']),
      nonCashVarianceTotal: json['nonCashVarianceTotal'] == null
          ? null
          : CashShiftSnapshot._asDouble(json['nonCashVarianceTotal']),
    );
  }
}

class CashShiftReport {
  const CashShiftReport({
    required this.shift,
    required this.summary,
    required this.operations,
  });

  final CashShiftListItem shift;
  final CashShiftReportSummary summary;
  final List<CashOperationInfo> operations;

  factory CashShiftReport.fromJson(Map<String, dynamic> json) {
    final opsRaw = json['operations'];
    final ops = opsRaw is List
        ? opsRaw
              .whereType<Map>()
              .map((e) => CashOperationInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <CashOperationInfo>[];
    return CashShiftReport(
      shift: CashShiftListItem.fromJson(
        Map<String, dynamic>.from(json['shift'] as Map? ?? {}),
      ),
      summary: CashShiftReportSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
      operations: ops,
    );
  }
}

class CashShiftCloseResult {
  const CashShiftCloseResult({
    required this.closed,
    this.message,
    this.variance,
    this.report,
    this.globalSync,
  });

  final bool closed;
  final String? message;
  final double? variance;
  final CashShiftReport? report;
  final CashShiftGlobalSync? globalSync;
}

class CashShiftOpeningSuggestion {
  const CashShiftOpeningSuggestion({
    required this.suggestedOpeningBalance,
    this.lastClosedShift,
  });

  final double? suggestedOpeningBalance;
  final CashShiftListItem? lastClosedShift;
}

class LocalCashRepository {
  LocalCashRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId => AppConfig.storeBranchId;

  String get _defaultTerminalId {
    final v = dotenv.maybeGet('POS_TERMINAL_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'KASSA-1';
  }

  Future<CashShiftSnapshot> fetchActiveShift({
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.get(
      'api/local/cash/active-shift',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить кассовую смену',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ кассовой смены');
    }
    return CashShiftSnapshot.fromJson(Map<String, dynamic>.from(body));
  }

  Future<CashShiftSnapshot> openCashShift({
    double? openingBalance,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/cash/shifts/open',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        if (openingBalance != null) 'openingBalance': openingBalance,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось открыть кассовую смену',
      );
    }
    return fetchActiveShift(branchId: branchId, terminalId: terminalId);
  }

  Future<CashShiftOpeningSuggestion> fetchOpeningSuggestion({
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.get(
      'api/local/cash/shifts/last-closing',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось получить подсказку по размену',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ подсказки по размену');
    }
    final map = Map<String, dynamic>.from(body);
    final shiftMap = map['shift'];
    final shift = shiftMap is Map
        ? CashShiftListItem.fromJson(Map<String, dynamic>.from(shiftMap))
        : null;
    final rawSuggestion = map['suggestedOpeningBalance'];
    return CashShiftOpeningSuggestion(
      suggestedOpeningBalance:
          rawSuggestion == null ? null : CashShiftSnapshot._asDouble(rawSuggestion),
      lastClosedShift: shift,
    );
  }

  Future<CashCloseShiftPreview> fetchCloseShiftPreview({
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.get(
      'api/local/cash/shifts/close-preview',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить данные для закрытия смены',
      );
    }
    final body = res.body;
    if (body is! Map) {
      return const CashCloseShiftPreview(
        hasOpenShift: false,
        expectedInDrawer: 0,
        banks: [],
      );
    }
    return CashCloseShiftPreview.fromJson(Map<String, dynamic>.from(body));
  }

  Future<CashShiftCloseResult> closeCashShift({
    double? closingActual,
    List<Map<String, dynamic>>? nonCashActual,
    String? closeNotes,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/cash/shifts/close',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        // «По факту» больше не спрашиваем на кассе — сверка в global admin.
        if (closingActual != null) 'closingActual': closingActual,
        if (nonCashActual != null && nonCashActual.isNotEmpty)
          'nonCashActual': nonCashActual,
        if (closeNotes != null && closeNotes.trim().isNotEmpty)
          'closeNotes': closeNotes.trim(),
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось закрыть кассовую смену',
      );
    }
    final body = res.body;
    if (body is! Map) {
      return const CashShiftCloseResult(closed: true);
    }
    final map = Map<String, dynamic>.from(body);
    CashShiftReport? report;
    if (map['summary'] is Map && map['shift'] is Map) {
      report = CashShiftReport.fromJson(map);
    }
    return CashShiftCloseResult(
      closed: map['closed'] == true,
      message: map['message']?.toString(),
      variance: map['variance'] == null
          ? null
          : CashShiftSnapshot._asDouble(map['variance']),
      report: report,
      globalSync: map['globalSync'] is Map
          ? CashShiftGlobalSync.fromJson(
              Map<String, dynamic>.from(map['globalSync'] as Map),
            )
          : null,
    );
  }

  Future<CashClosedShiftsResult> fetchClosedShifts({
    String? branchId,
    String? from,
    String? to,
    int limit = 100,
    /// `desc` — сначала новые (по умолчанию), `asc` — сначала старые.
    String sort = 'desc',
  }) async {
    final res = await _http.get(
      'api/local/cash/shifts',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'closedOnly': '1',
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'limit': '$limit',
        'sort': sort,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить смены',
      );
    }
    final body = res.body;
    if (body is! Map) return const CashClosedShiftsResult(items: []);
    final items = body['items'];
    final alertRaw = body['encashmentAlert'];
    return CashClosedShiftsResult(
      items: items is List
          ? items
              .whereType<Map>()
              .map((e) => CashShiftListItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      encashmentAlert: alertRaw is Map
          ? CashEncashmentAlert.fromJson(Map<String, dynamic>.from(alertRaw))
          : null,
    );
  }

  Future<CashShiftReport> fetchShiftReport({
    required String shiftId,
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/cash/shifts/$shiftId/report',
      query: {'branchId': branchId ?? _defaultBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить отчёт смены',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ отчёта смены');
    }
    return CashShiftReport.fromJson(Map<String, dynamic>.from(body));
  }

  Future<CashOperationResult> postOperation({
    required String opType,
    required double amount,
    String? comment,
    String? branchId,
    String? terminalId,
  }) async {
    return _postOperationBody(
      payload: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'opType': opType,
        'amount': amount,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  /// Инкассация по пересчёту ящика или по расчёту (amount без countedInDrawer).
  Future<CashOperationResult> postEncashment({
    double? amount,
    double? countedInDrawer,
    bool reconcileSurplus = false,
    String? comment,
    String? branchId,
    String? terminalId,
  }) async {
    return _postOperationBody(
      payload: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'opType': 'encashment',
        if (amount != null) 'amount': amount,
        if (countedInDrawer != null) 'countedInDrawer': countedInDrawer,
        if (reconcileSurplus) 'reconcileSurplus': true,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
  }

  Future<CashOperationResult> _postOperationBody({
    required Map<String, dynamic> payload,
  }) async {
    final res = await _http.post(
      'api/local/cash/operations',
      body: payload,
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить кассовую операцию',
      );
    }
    final responseBody = res.body;
    if (responseBody is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ операции');
    }
    final opMap = responseBody['operation'];
    final snapMap = responseBody['snapshot'];
    final hw = responseBody['hardware'];
    String? hint;
    if (hw is Map) {
      final err = hw['error']?.toString();
      if (err != null && err.isNotEmpty) hint = err;
    }
    return CashOperationResult(
      operation: CashOperationInfo.fromJson(
        opMap is Map ? Map<String, dynamic>.from(opMap) : const {},
      ),
      snapshot: CashShiftSnapshot.fromJson(
        snapMap is Map ? Map<String, dynamic>.from(snapMap) : const {},
      ),
      hardwareHint: hint,
    );
  }
}

/// Подписи типов операций для UI.
const cashOpTypeLabels = <String, String>{
  'change_in': 'Внесение (размен)',
  'encashment': 'Инкассация в сейф',
  'encashment_off_register': 'Инкассация вне учёта кассы',
  'owner_payout': 'Выплата владельцу',
  'supplier_cash': 'Оплата поставщику',
  'rent_cash': 'Оплата аренды',
  'off_register': 'Вне кассы',
  'other': 'Прочая выемка',
};
