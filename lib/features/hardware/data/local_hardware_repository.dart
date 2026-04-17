import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class HardwareReceiptResult {
  const HardwareReceiptResult({
    required this.receiptNumber,
    required this.mode,
  });

  final String receiptNumber;
  final String mode;
}

class HardwareDrawerResult {
  const HardwareDrawerResult({
    required this.mode,
  });

  final String mode;
}

class LocalHardwareRepository {
  LocalHardwareRepository(this._http);

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

  Future<HardwareReceiptResult> printReceipt({
    required String orderId,
    required double totalAmount,
    required String paymentMethod,
    String? branchId,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/hardware/receipts/print',
      body: {
        'orderId': orderId,
        'branchId': branchId ?? _defaultBranchId,
        'terminalId': terminalId ?? _defaultTerminalId,
        'paymentMethod': paymentMethod,
        'totalAmount': totalAmount,
      },
    );

    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось распечатать чек',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера печати');
    }
    final receipt = body['receipt'];
    if (receipt is! Map) {
      throw ApiException(res.statusCode, 'Сервер не вернул данные чека');
    }
    final receiptNumber = receipt['receiptNumber']?.toString() ?? '';
    final mode = receipt['mode']?.toString() ?? 'unknown';
    if (receiptNumber.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер не вернул номер чека');
    }
    return HardwareReceiptResult(receiptNumber: receiptNumber, mode: mode);
  }

  Future<HardwareDrawerResult> openDrawer({
    required String paymentMethod,
    String? terminalId,
  }) async {
    final res = await _http.post(
      'api/local/hardware/drawer/open',
      body: {
        'terminalId': terminalId ?? _defaultTerminalId,
        'paymentMethod': paymentMethod,
      },
    );

    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось открыть кассовый ящик',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера кассы');
    }
    final drawer = body['drawer'];
    if (drawer is! Map) {
      throw ApiException(res.statusCode, 'Сервер не вернул данные кассы');
    }
    final mode = drawer['mode']?.toString() ?? 'unknown';
    return HardwareDrawerResult(mode: mode);
  }
}
