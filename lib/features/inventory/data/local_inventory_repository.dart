import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class InventoryTransferSummary {
  const InventoryTransferSummary({
    required this.id,
    required this.docNumber,
    required this.docDate,
    required this.lineCount,
    this.toLocationName,
    this.totalAmount,
  });

  final int id;
  final String docNumber;
  final String? docDate;
  final int lineCount;
  final String? toLocationName;
  final double? totalAmount;

  factory InventoryTransferSummary.fromJson(Map<String, dynamic> json) {
    final ta = json['total_amount'];
    return InventoryTransferSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      docNumber: json['doc_number']?.toString() ?? '',
      docDate: json['doc_date']?.toString(),
      lineCount: int.tryParse(json['line_count']?.toString() ?? '') ?? 0,
      toLocationName: json['to_location_name']?.toString(),
      totalAmount: ta is num ? ta.toDouble() : double.tryParse(ta?.toString() ?? ''),
    );
  }
}

class InventoryCookableProduct {
  const InventoryCookableProduct({
    required this.productName,
    required this.maxQty,
    required this.status,
    this.limitingIngredientName,
  });

  final String productName;
  final int maxQty;
  final String status;
  final String? limitingIngredientName;

  factory InventoryCookableProduct.fromJson(Map<String, dynamic> json) {
    return InventoryCookableProduct(
      productName: json['product_name']?.toString() ?? 'Товар',
      maxQty: (num.tryParse(json['max_qty']?.toString() ?? '') ?? 0).floor(),
      status: json['status']?.toString() ?? 'ok',
      limitingIngredientName: json['limiting_ingredient_name']?.toString(),
    );
  }
}

class InventoryTransferLine {
  const InventoryTransferLine({
    required this.ingredientName,
    required this.qty,
    required this.unit,
    this.sku,
    this.unitCost,
  });

  final String ingredientName;
  final double qty;
  final String unit;
  final String? sku;
  final double? unitCost;

  double get lineSum => qty * (unitCost ?? 0);

  factory InventoryTransferLine.fromJson(Map<String, dynamic> json) {
    final q = json['qty'];
    final uc = json['unit_cost'];
    return InventoryTransferLine(
      ingredientName: json['ingredient_name']?.toString() ?? '—',
      qty: q is num ? q.toDouble() : double.tryParse(q?.toString() ?? '') ?? 0,
      unit: json['ingredient_unit']?.toString() ?? '',
      sku: json['ingredient_sku']?.toString(),
      unitCost: uc is num ? uc.toDouble() : double.tryParse(uc?.toString() ?? ''),
    );
  }
}

class InventoryTransferDocument {
  const InventoryTransferDocument({
    required this.id,
    required this.docNumber,
    required this.status,
    required this.lines,
    this.toLocationName,
  });

  final int id;
  final String docNumber;
  final String status;
  final List<InventoryTransferLine> lines;
  final String? toLocationName;

  double get totalAmount => lines.fold(0, (s, ln) => s + ln.lineSum);

  factory InventoryTransferDocument.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines
            .whereType<Map>()
            .map((e) => InventoryTransferLine.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <InventoryTransferLine>[];
    return InventoryTransferDocument(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      docNumber: json['doc_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lines: lines,
      toLocationName: json['to_location_name']?.toString(),
    );
  }
}

class LocalInventoryRepository {
  LocalInventoryRepository(this._http);

  final HttpClient _http;

  Future<({bool enabled, List<InventoryTransferSummary> items})> fetchInTransit() async {
    final res = await _http.get('api/local/inventory/transfers/in-transit');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить накладные',
      );
    }
    final body = res.body;
    if (body is! Map) {
      return (enabled: true, items: <InventoryTransferSummary>[]);
    }
    final enabled = body['enabled'] != false;
    final raw = body['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => InventoryTransferSummary.fromJson(Map<String, dynamic>.from(e)))
            .where((d) => d.id > 0)
            .toList()
        : <InventoryTransferSummary>[];
    return (enabled: enabled, items: items);
  }

  Future<InventoryTransferDocument> fetchTransfer(int id) async {
    final res = await _http.get('api/local/inventory/transfers/$id');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить накладную',
      );
    }
    final body = res.body;
    if (body is! Map || body['document'] is! Map) {
      throw ApiException(0, 'Пустой ответ сервера');
    }
    return InventoryTransferDocument.fromJson(
      Map<String, dynamic>.from(body['document'] as Map),
    );
  }

  Future<List<InventoryCookableProduct>> fetchCookableProducts() async {
    final res = await _http.get('api/local/inventory/stock-insights');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось получить остатки точки',
      );
    }
    final body = res.body;
    if (body is! Map || body['enabled'] == false) return <InventoryCookableProduct>[];
    final raw = body['yields'];
    return raw is List
        ? raw
            .whereType<Map>()
            .map((e) => InventoryCookableProduct.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <InventoryCookableProduct>[];
  }

  Future<InventoryTransferDocument> receiveTransfer(int id) async {
    final res = await _http.post('api/local/inventory/transfers/$id/receive', body: {});
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось принять накладную',
      );
    }
    final body = res.body;
    if (body is! Map || body['document'] is! Map) {
      throw ApiException(0, 'Пустой ответ после приёма');
    }
    return InventoryTransferDocument.fromJson(
      Map<String, dynamic>.from(body['document'] as Map),
    );
  }
}
