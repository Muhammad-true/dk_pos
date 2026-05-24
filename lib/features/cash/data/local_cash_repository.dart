import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

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

  factory CashShiftSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }

    final shiftMap = asMap(json['shift']);
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

  factory CashShiftListItem.fromJson(Map<String, dynamic> json) {
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
    this.closingExpected,
    this.closingActual,
    this.variance,
  });

  final double cashSalesIn;
  final double cashRefundsOut;
  final double operationsIn;
  final double operationsOut;
  final double openingBalance;
  final double? closingExpected;
  final double? closingActual;
  final double? variance;

  factory CashShiftReportSummary.fromJson(Map<String, dynamic> json) {
    return CashShiftReportSummary(
      cashSalesIn: CashShiftSnapshot._asDouble(json['cashSalesIn']),
      cashRefundsOut: CashShiftSnapshot._asDouble(json['cashRefundsOut']),
      operationsIn: CashShiftSnapshot._asDouble(json['operationsIn']),
      operationsOut: CashShiftSnapshot._asDouble(json['operationsOut']),
      openingBalance: CashShiftSnapshot._asDouble(json['openingBalance']),
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
  });

  final bool closed;
  final String? message;
  final double? variance;
  final CashShiftReport? report;
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
    required double openingBalance,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/cash/shifts/open',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'openingBalance': openingBalance,
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

  Future<CashShiftCloseResult> closeCashShift({
    required double closingActual,
    String? closeNotes,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/cash/shifts/close',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'closingActual': closingActual,
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
    );
  }

  Future<List<CashShiftListItem>> fetchClosedShifts({
    String? branchId,
    String? from,
    String? to,
    int limit = 50,
  }) async {
    final res = await _http.get(
      'api/local/cash/shifts',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'closedOnly': '1',
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'limit': '$limit',
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
    if (body is! Map) return [];
    final items = body['items'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => CashShiftListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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
    final res = await _http.post(
      'api/local/cash/operations',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'opType': opType,
        'amount': amount,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    if (res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить кассовую операцию',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ операции');
    }
    final opMap = body['operation'];
    final snapMap = body['snapshot'];
    final hw = body['hardware'];
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
  'owner_payout': 'Выплата владельцу',
  'supplier_cash': 'Оплата поставщику',
  'rent_cash': 'Оплата аренды',
  'other': 'Прочая выемка',
};
