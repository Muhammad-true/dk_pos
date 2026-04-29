import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LoyaltyTier {
  const LoyaltyTier({
    required this.id,
    required this.code,
    required this.title,
    required this.accrualPercent,
    required this.monthlySpendThreshold,
    required this.isActive,
  });

  final int id;
  final String code;
  final String title;
  final double accrualPercent;
  final double monthlySpendThreshold;
  final bool isActive;

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      accrualPercent: num.tryParse(json['accrualPercent']?.toString() ?? '')?.toDouble() ?? 0,
      monthlySpendThreshold:
          num.tryParse(json['monthlySpendThreshold']?.toString() ?? '')?.toDouble() ?? 0,
      isActive: json['isActive'] == true || json['isActive']?.toString() == '1',
    );
  }
}

class LoyaltyCustomer {
  const LoyaltyCustomer({
    required this.id,
    required this.branchId,
    required this.fullName,
    required this.phone,
    required this.qrCode,
    required this.pointsBalance,
    required this.isBlacklisted,
    required this.totalSpentAllTime,
    required this.totalSpentCurrentMonth,
    this.cardCode,
    this.blacklistReason,
    this.tier,
  });

  final int id;
  final String branchId;
  final String fullName;
  final String phone;
  final String? cardCode;
  final String qrCode;
  final double pointsBalance;
  final bool isBlacklisted;
  final String? blacklistReason;
  final double totalSpentAllTime;
  final double totalSpentCurrentMonth;
  final LoyaltyTier? tier;

  factory LoyaltyCustomer.fromJson(Map<String, dynamic> json) {
    final tierRaw = json['tier'];
    return LoyaltyCustomer(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      branchId: json['branchId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      cardCode: json['cardCode']?.toString(),
      qrCode: json['qrCode']?.toString() ?? '',
      pointsBalance: num.tryParse(json['pointsBalance']?.toString() ?? '')?.toDouble() ?? 0,
      isBlacklisted: json['isBlacklisted'] == true || json['isBlacklisted']?.toString() == '1',
      blacklistReason: json['blacklistReason']?.toString(),
      totalSpentAllTime:
          num.tryParse(json['totalSpentAllTime']?.toString() ?? '')?.toDouble() ?? 0,
      totalSpentCurrentMonth:
          num.tryParse(json['totalSpentCurrentMonth']?.toString() ?? '')?.toDouble() ?? 0,
      tier: tierRaw is Map
          ? LoyaltyTier.fromJson(Map<String, dynamic>.from(tierRaw))
          : null,
    );
  }
}

class LocalLoyaltyRepository {
  LocalLoyaltyRepository(this._http);

  final HttpClient _http;

  String get _defaultBranchId => AppConfig.storeBranchId;

  Future<List<LoyaltyTier>> fetchTiers() async {
    final res = await _http.get('api/local/loyalty/tiers');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить уровни лояльности',
      );
    }
    final body = res.body;
    final raw = body is Map ? body['tiers'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LoyaltyTier.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<LoyaltyTier> updateTier({
    required int tierId,
    String? title,
    double? accrualPercent,
    double? monthlySpendThreshold,
    bool? isActive,
  }) async {
    final res = await _http.patch(
      'api/local/loyalty/tiers/$tierId',
      body: {
        if (title != null) 'title': title,
        if (accrualPercent != null) 'accrualPercent': accrualPercent,
        if (monthlySpendThreshold != null) 'monthlySpendThreshold': monthlySpendThreshold,
        if (isActive != null) 'isActive': isActive,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить уровень',
      );
    }
    final body = res.body;
    if (body is! Map || body['tier'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ при обновлении уровня');
    }
    return LoyaltyTier.fromJson(Map<String, dynamic>.from(body['tier'] as Map));
  }

  Future<List<LoyaltyCustomer>> searchCustomers({
    String query = '',
    String? branchId,
    bool includeBlacklisted = false,
    int limit = 40,
  }) async {
    final res = await _http.get(
      'api/local/loyalty/customers',
      query: {
        'branchId': branchId ?? _defaultBranchId,
        'query': query,
        'includeBlacklisted': includeBlacklisted ? '1' : '0',
        'limit': '$limit',
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось найти клиентов',
      );
    }
    final body = res.body;
    final raw = body is Map ? body['customers'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LoyaltyCustomer.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  Future<LoyaltyCustomer> createCustomer({
    required String phone,
    String? fullName,
    String? cardCode,
    /// Код из профиля donerkebab.tj (loyalty_public_id), чтобы QR на сайте и в POS совпадали.
    String? qrCode,
    String? branchId,
  }) async {
    final res = await _http.post(
      'api/local/loyalty/customers',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'phone': phone,
        if (fullName != null) 'fullName': fullName,
        if (cardCode != null) 'cardCode': cardCode,
        if (qrCode != null && qrCode.trim().isNotEmpty) 'qrCode': qrCode.trim(),
      },
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось создать клиента',
      );
    }
    final body = res.body;
    if (body is! Map || body['customer'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ при создании клиента');
    }
    return LoyaltyCustomer.fromJson(Map<String, dynamic>.from(body['customer'] as Map));
  }

  Future<LoyaltyCustomer> updateCustomer({
    required int customerId,
    String? fullName,
    String? phone,
    String? cardCode,
    int? tierId,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/loyalty/customers/$customerId',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (cardCode != null) 'cardCode': cardCode,
        if (tierId != null) 'tierId': tierId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить клиента',
      );
    }
    final body = res.body;
    if (body is! Map || body['customer'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ при обновлении клиента');
    }
    return LoyaltyCustomer.fromJson(Map<String, dynamic>.from(body['customer'] as Map));
  }

  Future<LoyaltyCustomer> setBlacklist({
    required int customerId,
    required bool blacklisted,
    String? reason,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/loyalty/customers/$customerId/blacklist',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'blacklisted': blacklisted,
        if (reason != null) 'reason': reason,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить ЧС',
      );
    }
    final body = res.body;
    if (body is! Map || body['customer'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ при обновлении ЧС');
    }
    return LoyaltyCustomer.fromJson(Map<String, dynamic>.from(body['customer'] as Map));
  }

  Future<LoyaltyCustomer> adjustPoints({
    required int customerId,
    required double pointsDelta,
    String? comment,
    String? branchId,
  }) async {
    final res = await _http.post(
      'api/local/loyalty/customers/$customerId/points-adjust',
      body: {
        'branchId': branchId ?? _defaultBranchId,
        'pointsDelta': pointsDelta,
        if (comment != null) 'comment': comment,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось изменить баллы',
      );
    }
    final body = res.body;
    if (body is! Map || body['customer'] is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ изменения баллов');
    }
    return LoyaltyCustomer.fromJson(Map<String, dynamic>.from(body['customer'] as Map));
  }

  Future<void> deleteCustomer({
    required int customerId,
    String? branchId,
  }) async {
    final safeBranch = branchId ?? _defaultBranchId;
    final res = await _http.delete(
      'api/local/loyalty/customers/$customerId?branchId=${Uri.encodeQueryComponent(safeBranch)}',
    );
    if (res.statusCode != 204) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось удалить клиента',
      );
    }
  }

  Future<List<LoyaltyHistoryEntry>> fetchCustomerHistory({
    required int customerId,
    String? branchId,
    int limit = 100,
  }) async {
    final safeBranch = branchId ?? _defaultBranchId;
    final res = await _http.get(
      'api/local/loyalty/customers/$customerId/history',
      query: {
        'branchId': safeBranch,
        'limit': '$limit',
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить историю клиента',
      );
    }
    final body = res.body;
    final raw = body is Map ? body['history'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LoyaltyHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

class LoyaltyHistoryEntry {
  const LoyaltyHistoryEntry({
    required this.id,
    required this.txType,
    required this.pointsDelta,
    required this.createdAt,
    this.amountBase,
    this.orderId,
    this.orderNumber,
    this.paymentUuid,
    this.paymentAmount,
    this.paymentMethod,
    this.comment,
  });

  final int id;
  final String txType;
  final double pointsDelta;
  final DateTime? createdAt;
  final double? amountBase;
  final String? orderId;
  final String? orderNumber;
  final String? paymentUuid;
  final double? paymentAmount;
  final String? paymentMethod;
  final String? comment;

  factory LoyaltyHistoryEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt']?.toString();
    return LoyaltyHistoryEntry(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      txType: json['txType']?.toString() ?? '',
      pointsDelta: num.tryParse(json['pointsDelta']?.toString() ?? '')?.toDouble() ?? 0,
      amountBase: num.tryParse(json['amountBase']?.toString() ?? '')?.toDouble(),
      orderId: json['orderId']?.toString(),
      orderNumber: json['orderNumber']?.toString(),
      paymentUuid: json['paymentUuid']?.toString(),
      paymentAmount: num.tryParse(json['paymentAmount']?.toString() ?? '')?.toDouble(),
      paymentMethod: json['paymentMethod']?.toString(),
      comment: json['comment']?.toString(),
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw)?.toLocal() : null,
    );
  }
}
