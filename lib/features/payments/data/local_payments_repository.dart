import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalPaymentResult {
  const LocalPaymentResult({
    required this.paymentUuid,
    required this.method,
    required this.amount,
    required this.idempotent,
  });

  final String paymentUuid;
  final String method;
  final double amount;
  final bool idempotent;
}

class LocalPaymentsRepository {
  LocalPaymentsRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId {
    final v = dotenv.maybeGet('POS_BRANCH_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'branch_1';
  }

  String get _defaultTerminalId {
    final v = dotenv.maybeGet('POS_TERMINAL_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'KASSA-1';
  }

  Future<LocalPaymentResult> acceptPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    required String idempotencyKey,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/payments',
      body: {
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'idempotencyKey': idempotencyKey,
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
    final amountVal = num.tryParse(payment['amount']?.toString() ?? '')?.toDouble() ?? amount;
    if (paymentUuid.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул paymentUuid');
    }
    return LocalPaymentResult(
      paymentUuid: paymentUuid,
      method: method,
      amount: amountVal,
      idempotent: body['idempotent'] == true,
    );
  }
}
