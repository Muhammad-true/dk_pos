import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalPaymentMethod {
  const LocalPaymentMethod({
    required this.id,
    required this.code,
    required this.title,
    required this.type,
    required this.isActive,
    required this.sortOrder,
    required this.details,
    required this.isSystem,
  });

  final int? id;
  final String code;
  final String title;
  final String type;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> details;
  final bool isSystem;

  bool get isCash => type == 'cash' || code == 'cash';
  bool get isBank => type == 'bank';

  factory LocalPaymentMethod.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['details'];
    return LocalPaymentMethod(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse(json['id']?.toString() ?? ''),
      code: (json['code']?.toString() ?? '').trim(),
      title: (json['title']?.toString() ?? '').trim(),
      type: (json['type']?.toString() ?? 'bank').trim().toLowerCase(),
      isActive:
          json['isActive'] == true ||
          json['is_active'] == true ||
          json['is_active'] == 1,
      sortOrder: json['sortOrder'] is num
          ? (json['sortOrder'] as num).toInt()
          : int.tryParse(json['sortOrder']?.toString() ?? '') ?? 100,
      details: detailsRaw is Map
          ? Map<String, dynamic>.from(detailsRaw)
          : const <String, dynamic>{},
      isSystem: json['isSystem'] == true || json['is_system'] == true,
    );
  }
}

class LocalPaymentMethodsRepository {
  LocalPaymentMethodsRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<List<LocalPaymentMethod>> fetchMethods({
    bool includeInactive = false,
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/payment-methods',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        if (includeInactive) 'includeInactive': '1',
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить способы оплаты',
      );
    }
    final body = res.body;
    if (body is! Map) return const [];
    final raw = body['methods'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LocalPaymentMethod.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<LocalPaymentMethod> createBankMethod({
    required String title,
    required String code,
    int sortOrder = 100,
    bool isActive = true,
    Map<String, dynamic>? details,
    String? branchId,
  }) async {
    final res = await _http.post(
      'api/local/payment-methods',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'title': title,
        'code': code,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'details': details ?? const <String, dynamic>{},
      },
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось создать банковский способ оплаты',
      );
    }
    final body = res.body;
    if (body is! Map || body['method'] is! Map) {
      throw ApiException(
        res.statusCode,
        'Некорректный ответ при создании способа оплаты',
      );
    }
    return LocalPaymentMethod.fromJson(
      Map<String, dynamic>.from(body['method'] as Map),
    );
  }

  Future<LocalPaymentMethod> updateBankMethod({
    required int id,
    required String title,
    required String code,
    int sortOrder = 100,
    bool isActive = true,
    Map<String, dynamic>? details,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/payment-methods/$id',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'title': title,
        'code': code,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'details': details ?? const <String, dynamic>{},
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить банковский способ оплаты',
      );
    }
    final body = res.body;
    if (body is! Map || body['method'] is! Map) {
      throw ApiException(
        res.statusCode,
        'Некорректный ответ при обновлении способа оплаты',
      );
    }
    return LocalPaymentMethod.fromJson(
      Map<String, dynamic>.from(body['method'] as Map),
    );
  }

  Future<void> archiveMethod({required int id, String? branchId}) async {
    final resolvedBranchId = Uri.encodeQueryComponent(
      branchId ?? _defaultBranchId,
    );
    final res = await _http.delete(
      'api/local/payment-methods/$id?branchId=$resolvedBranchId',
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось отключить способ оплаты',
      );
    }
  }
}
