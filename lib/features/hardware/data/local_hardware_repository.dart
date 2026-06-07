import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/config/app_config.dart';
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

class HardwarePrinterDevice {
  const HardwarePrinterDevice({
    required this.name,
    this.status,
  });

  final String name;
  final String? status;

  factory HardwarePrinterDevice.fromJson(Map<String, dynamic> json) {
    return HardwarePrinterDevice(
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString(),
    );
  }
}

/// Ответ `GET /api/local/hardware/status` (режим печати и доступность принтера в Windows).
class HardwareStatusSnapshot {
  const HardwareStatusSnapshot({
    required this.hardwareMode,
    required this.receiptPrinterConfigured,
    required this.receiptPrinterReachable,
    required this.receiptPrinterStatusCode,
    this.receiptPrinterName,
    this.driverPrinterStatus,
    this.probeError,
  });

  final String hardwareMode;
  final bool receiptPrinterConfigured;
  final bool receiptPrinterReachable;
  final String receiptPrinterStatusCode;
  final String? receiptPrinterName;
  final dynamic driverPrinterStatus;
  final String? probeError;

  factory HardwareStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return HardwareStatusSnapshot(
      hardwareMode: json['hardwareMode']?.toString() ?? '',
      receiptPrinterConfigured: json['receiptPrinterConfigured'] == true,
      receiptPrinterReachable: json['receiptPrinterReachable'] == true,
      receiptPrinterStatusCode:
          json['receiptPrinterStatusCode']?.toString() ?? '',
      receiptPrinterName: json['receiptPrinterName']?.toString(),
      driverPrinterStatus: json['driverPrinterStatus'],
      probeError: json['probeError']?.toString(),
    );
  }
}

class LocalHardwareRepository {
  LocalHardwareRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId => AppConfig.storeBranchId;

  String get _defaultTerminalId {
    final v = dotenv.maybeGet('POS_TERMINAL_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'KASSA-1';
  }

  Future<HardwareReceiptResult> printReceipt({
    required String orderId,
    required double totalAmount,
    required String paymentMethod,
    String? receiptTitle,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? deliveryNote,
    bool? isDeliveryOrder,
    String? branchId,
    String? terminalId,
  }) async {
    final body = <String, dynamic>{
      'orderId': orderId,
      'branchId': branchId ?? _defaultBranchId,
      'terminalId': terminalId ?? _defaultTerminalId,
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
    };
    void putIfNotEmpty(String key, String? value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) body[key] = v;
    }
    putIfNotEmpty('receiptTitle', receiptTitle);
    putIfNotEmpty('customerName', customerName);
    putIfNotEmpty('customerPhone', customerPhone);
    putIfNotEmpty('deliveryAddress', deliveryAddress);
    putIfNotEmpty('deliveryNote', deliveryNote);
    if (isDeliveryOrder == true) body['isDeliveryOrder'] = true;

    final res = await _http.post(
      'api/local/hardware/receipts/print',
      body: body,
    );

    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось распечатать чек',
      );
    }
    final responseBody = res.body;
    if (responseBody is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера печати');
    }
    final receipt = responseBody['receipt'];
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

  Future<HardwareStatusSnapshot> fetchHardwareStatus() async {
    final res = await _http.get(
      'api/local/hardware/status',
      query: {'branchId': _defaultBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось получить статус оборудования',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ статуса оборудования');
    }
    return HardwareStatusSnapshot.fromJson(Map<String, dynamic>.from(body));
  }

  Future<List<HardwarePrinterDevice>> fetchAvailablePrinters() async {
    final res = await _http.get('api/local/hardware/printers');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось получить список принтеров',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ списка принтеров');
    }
    final raw = body['printers'];
    if (raw is! List) return const <HardwarePrinterDevice>[];
    return raw
        .whereType<Map>()
        .map((e) => HardwarePrinterDevice.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.name.trim().isNotEmpty)
        .toList();
  }
}
