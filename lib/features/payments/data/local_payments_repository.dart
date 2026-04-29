import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalPaymentResult {
  const LocalPaymentResult({
    required this.paymentUuid,
    required this.method,
    required this.amount,
    required this.idempotent,
    this.hardware,
  });

  final String paymentUuid;
  final String method;
  final double amount;
  final bool idempotent;
  final LocalPaymentHardwareResult? hardware;
}

class LocalRefundResult {
  const LocalRefundResult({
    required this.refundUuid,
    required this.paymentUuid,
    required this.orderId,
    required this.amount,
    required this.orderStatus,
    this.hardware,
  });

  final String refundUuid;
  final String paymentUuid;
  final String orderId;
  final double amount;
  final String orderStatus;
  final LocalPaymentHardwareResult? hardware;
}

class LocalPaymentHardwareResult {
  const LocalPaymentHardwareResult({
    required this.attempted,
    this.receiptPrinted,
    this.drawerOpened,
    this.receiptNumber,
    this.mode,
    this.error,
  });

  final bool attempted;
  final bool? receiptPrinted;
  final bool? drawerOpened;
  final String? receiptNumber;
  final String? mode;
  final String? error;

  factory LocalPaymentHardwareResult.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return null;
    }

    final receipt = asMap(json['receipt']);
    final drawer = asMap(json['drawer']);
    final rawError = json['error']?.toString().trim();
    final receiptMsg = receipt?['message']?.toString().trim();
    final drawerMsg = drawer?['message']?.toString().trim();
    final pickedError = (rawError != null && rawError.isNotEmpty)
        ? rawError
        : (receiptMsg != null && receiptMsg.isNotEmpty)
        ? receiptMsg
        : (drawerMsg != null && drawerMsg.isNotEmpty)
        ? drawerMsg
        : null;

    return LocalPaymentHardwareResult(
      attempted: json['attempted'] == true,
      receiptPrinted: receipt?['printed'] == null
          ? null
          : receipt?['printed'] == true,
      drawerOpened: drawer?['opened'] == null
          ? null
          : drawer?['opened'] == true,
      receiptNumber: receipt?['receiptNumber']?.toString(),
      mode: receipt?['mode']?.toString() ?? drawer?['mode']?.toString(),
      error: pickedError,
    );
  }

  String? buildHint() {
    if (!attempted) return null;
    if (error != null && error!.isNotEmpty) return 'Оборудование: $error';

    final parts = <String>[];
    if (receiptPrinted == true) {
      parts.add('Чек напечатан');
    } else if (receiptPrinted == false) {
      parts.add('Чек не напечатан');
    }

    if (drawerOpened == true) {
      parts.add('Кассовый ящик открыт');
    } else if (drawerOpened == false) {
      parts.add('Кассовый ящик не открыт');
    }

    final receipt = receiptNumber?.trim();
    if (receipt != null && receipt.isNotEmpty) {
      parts.add('№ $receipt');
    }
    final modeValue = mode?.trim();
    if (modeValue != null && modeValue.isNotEmpty) {
      parts.add('режим: $modeValue');
    }

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

class LocalPaymentHistoryItem {
  const LocalPaymentHistoryItem({required this.name, required this.quantity});

  final String name;
  final int quantity;

  factory LocalPaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'];
    return LocalPaymentHistoryItem(
      name: json['name']?.toString() ?? '',
      quantity: qty is int ? qty : int.tryParse(qty?.toString() ?? '') ?? 0,
    );
  }
}

class LocalPaymentHistoryEntry {
  const LocalPaymentHistoryEntry({
    required this.paymentUuid,
    required this.orderId,
    required this.orderNumber,
    required this.method,
    required this.amount,
    required this.createdAt,
    required this.items,
    this.orderType,
    this.tableLabel,
    this.cashierUsername,
  });

  final String paymentUuid;
  final String orderId;
  final String orderNumber;
  final String method;
  final double amount;
  final DateTime? createdAt;
  final List<LocalPaymentHistoryItem> items;
  final String? orderType;
  final String? tableLabel;
  final String? cashierUsername;

  factory LocalPaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    DateTime? paidAt;
    final rawDate = json['createdAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      paidAt = DateTime.tryParse(rawDate)?.toLocal();
    }

    return LocalPaymentHistoryEntry(
      paymentUuid: json['paymentUuid']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      amount: num.tryParse(json['amount']?.toString() ?? '')?.toDouble() ?? 0,
      createdAt: paidAt,
      orderType: json['orderType']?.toString(),
      tableLabel: json['tableLabel']?.toString(),
      cashierUsername: json['cashierUsername']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => LocalPaymentHistoryItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const <LocalPaymentHistoryItem>[],
    );
  }
}

class LocalRefundHistoryEntry {
  const LocalRefundHistoryEntry({
    required this.refundUuid,
    required this.paymentUuid,
    required this.orderId,
    required this.orderNumber,
    required this.method,
    required this.amount,
    required this.createdAt,
    required this.items,
    this.reason,
    this.orderType,
    this.tableLabel,
    this.cashierUsername,
  });

  final String refundUuid;
  final String paymentUuid;
  final String orderId;
  final String orderNumber;
  final String method;
  final double amount;
  final DateTime? createdAt;
  final List<LocalPaymentHistoryItem> items;
  final String? reason;
  final String? orderType;
  final String? tableLabel;
  final String? cashierUsername;

  factory LocalRefundHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    DateTime? createdAt;
    final rawDate = json['createdAt']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      createdAt = DateTime.tryParse(rawDate)?.toLocal();
    }

    return LocalRefundHistoryEntry(
      refundUuid: json['refundUuid']?.toString() ?? '',
      paymentUuid: json['paymentUuid']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      method: json['method']?.toString() ?? '',
      amount: num.tryParse(json['amount']?.toString() ?? '')?.toDouble() ?? 0,
      createdAt: createdAt,
      reason: json['reason']?.toString(),
      orderType: json['orderType']?.toString(),
      tableLabel: json['tableLabel']?.toString(),
      cashierUsername: json['cashierUsername']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => LocalPaymentHistoryItem.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const <LocalPaymentHistoryItem>[],
    );
  }
}

class LocalPaymentsTodayHistory {
  const LocalPaymentsTodayHistory({
    required this.payments,
    required this.refunds,
  });

  final List<LocalPaymentHistoryEntry> payments;
  final List<LocalRefundHistoryEntry> refunds;
}

class LocalPaymentsRepository {
  LocalPaymentsRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId => AppConfig.storeBranchId;

  String get _defaultTerminalId {
    final v = dotenv.maybeGet('POS_TERMINAL_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'KASSA-1';
  }

  Future<LocalPaymentResult> acceptPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    int? paymentMethodId,
    required String idempotencyKey,
    double? cashReceived,
    double? cashChange,
    String? promoCode,
    double? promoDiscountAmount,
    double? loyaltyDiscountAmount,
    String? loyaltyCardNo,
    int? customerId,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/payments',
      body: {
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        'idempotencyKey': idempotencyKey,
        if (cashReceived != null) 'cashReceived': cashReceived,
        if (cashChange != null) 'cashChange': cashChange,
        if (promoCode != null && promoCode.trim().isNotEmpty)
          'promoCode': promoCode.trim(),
        if (promoDiscountAmount != null && promoDiscountAmount > 0)
          'promoDiscountAmount': promoDiscountAmount,
        if (loyaltyDiscountAmount != null && loyaltyDiscountAmount > 0)
          'loyaltyDiscountAmount': loyaltyDiscountAmount,
        if (loyaltyCardNo != null && loyaltyCardNo.trim().isNotEmpty)
          'loyaltyCardNo': loyaltyCardNo.trim(),
        if (customerId != null) 'customerId': customerId,
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось провести оплату на локальном сервере',
      );
    }

    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера оплаты');
    }
    final payment = body['payment'];
    if (payment is! Map) {
      throw ApiException(res.statusCode, 'Сервер не вернул данные оплаты');
    }
    final paymentUuid = payment['paymentUuid']?.toString() ?? '';
    final method = payment['method']?.toString() ?? paymentMethod;
    final amountVal =
        num.tryParse(payment['amount']?.toString() ?? '')?.toDouble() ?? amount;
    if (paymentUuid.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул paymentUuid');
    }
    return LocalPaymentResult(
      paymentUuid: paymentUuid,
      method: method,
      amount: amountVal,
      idempotent: body['idempotent'] == true,
      hardware: body['hardware'] is Map
          ? LocalPaymentHardwareResult.fromJson(
              Map<String, dynamic>.from(body['hardware'] as Map),
            )
          : null,
    );
  }

  Future<LocalPaymentsTodayHistory> fetchTodayHistoryBundle({
    String? branchId,
    int limit = 150,
    String? lang,
  }) async {
    final safeLimit = limit.clamp(20, 300);
    final langRaw = (lang ?? 'ru').trim().toLowerCase();
    final safeLang = (langRaw == 'tj' || langRaw == 'en') ? langRaw : 'ru';
    final res = await _http.get(
      'api/local/payments/today',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'limit': '$safeLimit',
        'lang': safeLang,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить историю оплат за сегодня',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ истории оплат');
    }
    final raw = body['payments'];
    final payments = raw is! List
        ? const <LocalPaymentHistoryEntry>[]
        : raw
              .whereType<Map>()
              .map(
                (e) => LocalPaymentHistoryEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((e) => e.paymentUuid.isNotEmpty)
              .toList(growable: false);
    final rawRefunds = body['refunds'];
    final refunds = rawRefunds is! List
        ? const <LocalRefundHistoryEntry>[]
        : rawRefunds
              .whereType<Map>()
              .map(
                (e) => LocalRefundHistoryEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((e) => e.refundUuid.isNotEmpty)
              .toList(growable: false);
    return LocalPaymentsTodayHistory(payments: payments, refunds: refunds);
  }

  Future<List<LocalPaymentHistoryEntry>> fetchTodayHistory({
    String? branchId,
    int limit = 150,
    String? lang,
  }) async {
    final bundle = await fetchTodayHistoryBundle(
      branchId: branchId,
      limit: limit,
      lang: lang,
    );
    return bundle.payments;
  }

  Future<LocalRefundResult> refundOrderPayment({
    required String orderId,
    String? paymentUuid,
    String? reason,
    bool cancelOrder = true,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/payments/refund',
      body: {
        'orderId': orderId,
        if (paymentUuid != null && paymentUuid.trim().isNotEmpty)
          'paymentUuid': paymentUuid.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'cancelOrder': cancelOrder,
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить возврат',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ возврата');
    }
    final refund = body['refund'];
    if (refund is! Map) {
      throw ApiException(res.statusCode, 'Сервер не вернул данные возврата');
    }
    final map = Map<String, dynamic>.from(refund);
    final amountVal =
        num.tryParse(map['amount']?.toString() ?? '')?.toDouble() ?? 0.0;
    return LocalRefundResult(
      refundUuid: map['refundUuid']?.toString() ?? '',
      paymentUuid: map['paymentUuid']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? orderId,
      amount: amountVal,
      orderStatus: map['orderStatus']?.toString() ?? '',
      hardware: body['hardware'] is Map
          ? LocalPaymentHardwareResult.fromJson(
              Map<String, dynamic>.from(body['hardware'] as Map),
            )
          : null,
    );
  }
}
