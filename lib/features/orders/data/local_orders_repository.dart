import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

class LocalOrderLineInput {
  const LocalOrderLineInput({
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
  });

  final String menuItemId;
  final int quantity;
  final double unitPrice;
}

class LocalOrderResult {
  const LocalOrderResult({
    required this.orderId,
    required this.number,
    required this.totalPrice,
    required this.created,
  });

  final String orderId;
  final String number;
  final double totalPrice;
  final bool created;
}

class LocalKitchenQueueItem {
  const LocalKitchenQueueItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    this.kitchenLineStatus = 'pending',
    this.kitchenStationId,
    this.kitchenStationName,
  });

  final String menuItemId;
  final String name;
  final int quantity;
  final String kitchenLineStatus;
  final int? kitchenStationId;
  final String? kitchenStationName;

  factory LocalKitchenQueueItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    final ksRaw = json['kitchenStationId'] ?? json['kitchen_station_id'];
    int? ks;
    if (ksRaw is int) {
      ks = ksRaw;
    } else if (ksRaw != null) {
      ks = int.tryParse(ksRaw.toString());
    }

    return LocalKitchenQueueItem(
      menuItemId: json['menuItemId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: asInt(json['quantity']),
      kitchenLineStatus:
          json['kitchenLineStatus']?.toString() ?? json['kitchen_line_status']?.toString() ?? 'pending',
      kitchenStationId: ks,
      kitchenStationName: json['kitchenStationName']?.toString() ?? json['kitchen_station_name']?.toString(),
    );
  }
}

/// Подписи для сборки / кухни: станция «К1», витрина без ожидания кухни.
extension LocalKitchenQueueItemAssemblyX on LocalKitchenQueueItem {
  String get assemblyKitchenTag {
    if (kitchenStationId == null) return 'витрина';
    final name = (kitchenStationName ?? '').trim();
    if (name.isNotEmpty) {
      final m = RegExp(r'(\d+)\s*$').firstMatch(name);
      if (m != null) return 'К${m.group(1)}';
    }
    return 'К$kitchenStationId';
  }

  bool get isAssemblyLineReady {
    if (kitchenStationId == null) return true;
    return kitchenLineStatus.toLowerCase() == 'ready';
  }

  String get assemblyStatusShortRu {
    final s = kitchenLineStatus.toLowerCase();
    if (kitchenStationId == null) return 'готово';
    switch (s) {
      case 'pending':
        return 'отправлено в кухню';
      case 'accepted':
        return 'готовится';
      case 'ready':
        return 'готово';
      default:
        return isAssemblyLineReady ? 'готово' : 'ожидается';
    }
  }

  String assemblyTitleWithStation() {
    final q = quantity > 1 ? '$quantity × $name' : name;
    return '$q ($assemblyKitchenTag)';
  }
}

class LocalKitchenQueueOrder {
  const LocalKitchenQueueOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.totalPrice,
    required this.items,
  });

  final String id;
  final String number;
  final String status;
  final double totalPrice;
  final List<LocalKitchenQueueItem> items;

  factory LocalKitchenQueueOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(LocalKitchenQueueItem.fromJson)
            .toList()
        : const <LocalKitchenQueueItem>[];
    return LocalKitchenQueueOrder(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'new',
      totalPrice: num.tryParse(json['totalPrice']?.toString() ?? '')?.toDouble() ?? 0,
      items: items,
    );
  }
}

/// Заказ в списках кассы «входящие / активные» (ответ cashier-incoming / cashier-active).
class LocalCashierBoardOrder {
  const LocalCashierBoardOrder({
    required this.order,
    required this.requiresPayment,
    this.orderType,
    this.tableLabel,
  });

  final LocalKitchenQueueOrder order;
  final bool requiresPayment;
  final String? orderType;
  final String? tableLabel;

  factory LocalCashierBoardOrder.fromJson(Map<String, dynamic> json) {
    return LocalCashierBoardOrder(
      order: LocalKitchenQueueOrder.fromJson(json),
      requiresPayment:
          json['requiresPayment'] == true || json['requires_payment'] == true,
      orderType: json['orderType']?.toString() ?? json['order_type']?.toString(),
      tableLabel: json['tableLabel']?.toString() ?? json['table_label']?.toString(),
    );
  }
}

class LocalKitchenQueueSnapshot {
  const LocalKitchenQueueSnapshot({
    required this.preparing,
    required this.waitingOthers,
    required this.readyForPickup,
  });

  final List<LocalKitchenQueueOrder> preparing;
  final List<LocalKitchenQueueOrder> waitingOthers;
  final List<LocalKitchenQueueOrder> readyForPickup;
}

class LocalKitchenTodayStats {
  const LocalKitchenTodayStats({
    required this.itemsReady,
    required this.spentSeconds,
  });

  final int itemsReady;
  final int spentSeconds;
}

class LocalExpeditorQueueSnapshot {
  const LocalExpeditorQueueSnapshot({
    required this.bundling,
    required this.pickup,
  });

  final List<LocalKitchenQueueOrder> bundling;
  final List<LocalKitchenQueueOrder> pickup;
}

class LocalOrdersRepository {
  LocalOrdersRepository(this._http);

  final HttpClient _http;

  Future<LocalOrderResult> createOrUpdateOrder({
    required String orderId,
    required List<LocalOrderLineInput> lines,
    required double totalAmount,
    required String orderType,
    String? tableLabel,
  }) async {
    final bodyLines = lines
        .map(
          (l) => {
            'menuItemId': l.menuItemId,
            'quantity': l.quantity,
            'unitPrice': l.unitPrice,
          },
        )
        .toList(growable: false);

    final res = await _http.post(
      'api/local/orders',
      body: {
        'orderId': orderId,
        'lines': bodyLines,
        'totalAmount': totalAmount,
        'orderType': orderType,
        'tableLabel': tableLabel,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось сохранить локальный заказ',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера заказов');
    }
    final order = body['order'];
    if (order is! Map) {
      throw ApiException(res.statusCode, 'Сервер не вернул объект заказа');
    }
    final id = order['id']?.toString() ?? '';
    final number = order['number']?.toString() ?? '';
    final total = num.tryParse(order['totalPrice']?.toString() ?? '')?.toDouble() ?? totalAmount;
    if (id.isEmpty || number.isEmpty) {
      throw ApiException(res.statusCode, 'Сервер вернул неполные данные заказа');
    }
    return LocalOrderResult(
      orderId: id,
      number: number,
      totalPrice: total,
      created: body['created'] == true,
    );
  }

  Future<LocalKitchenQueueSnapshot> fetchKitchenQueueMy() async {
    final res = await _http.get('api/local/orders/queue/my');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить очередь кухни',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера очереди');
    }
    List<LocalKitchenQueueOrder> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LocalKitchenQueueOrder.fromJson)
          .toList();
    }

    return LocalKitchenQueueSnapshot(
      preparing: parseList(body['preparing']),
      waitingOthers: parseList(body['waitingOthers'] ?? body['waiting_others']),
      readyForPickup: parseList(body['ready']),
    );
  }

  /// Общая очередь филиала (GET /queue) — для экрана «показ очереди», без фильтра по кухне.
  Future<LocalKitchenQueueSnapshot> fetchKitchenQueueDisplay() async {
    final res = await _http.get('api/local/orders/queue');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить очередь',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера очереди');
    }
    List<LocalKitchenQueueOrder> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LocalKitchenQueueOrder.fromJson)
          .toList();
    }

    return LocalKitchenQueueSnapshot(
      preparing: parseList(body['preparing']),
      waitingOthers: parseList(body['waitingOthers'] ?? body['waiting_others']),
      readyForPickup: parseList(body['ready']),
    );
  }

  Future<LocalExpeditorQueueSnapshot> fetchExpeditorQueue() async {
    final res = await _http.get('api/local/orders/expeditor-queue');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить очередь сборки',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ сервера очереди сборки');
    }
    List<LocalKitchenQueueOrder> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LocalKitchenQueueOrder.fromJson)
          .toList();
    }

    return LocalExpeditorQueueSnapshot(
      bundling: parseList(body['bundling']),
      pickup: parseList(body['pickup']),
    );
  }

  Future<void> updateKitchenProgress({
    required String orderId,
    required String action,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/kitchen-progress',
      body: {'action': action},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить этап кухни',
      );
    }
  }

  Future<void> handoffOrder({
    required String orderId,
    required String action,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/handoff',
      body: {'action': action},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить действие выдачи',
      );
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/status',
      body: {'status': status},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось обновить статус заказа',
      );
    }
  }

  /// Неоплаченные счета с привязкой к столу (GET /open-table-bills).
  Future<List<LocalCashierBoardOrder>> fetchCashierIncomingOrders({
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/orders/cashier-incoming',
      query: {'branchId': branchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить входящие заказы',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ cashier-incoming');
    }
    final raw = body['orders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LocalCashierBoardOrder.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => o.order.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<LocalCashierBoardOrder>> fetchCashierActiveOrders({
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/orders/cashier-active',
      query: {'branchId': branchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить активные заказы',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ cashier-active');
    }
    final raw = body['orders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LocalCashierBoardOrder.fromJson(Map<String, dynamic>.from(e)))
        .where((o) => o.order.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> acknowledgeCashierIncomingOrder({
    required String orderId,
    String branchId = 'branch_1',
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/cashier-ack',
      body: {'branchId': branchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось отметить заказ',
      );
    }
  }

  Future<LocalKitchenTodayStats> fetchKitchenMyTodayStats({
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/reports/kitchen-my-today',
      query: {'branchId': branchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить статистику кухни за сегодня',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ kitchen-my-today');
    }
    final map = Map<String, dynamic>.from(body);
    final itemsRaw = map['itemsReady'];
    final spentRaw = map['spentSeconds'];
    return LocalKitchenTodayStats(
      itemsReady: itemsRaw is num ? itemsRaw.toInt() : int.tryParse(itemsRaw?.toString() ?? '') ?? 0,
      spentSeconds: spentRaw is num ? spentRaw.toInt() : int.tryParse(spentRaw?.toString() ?? '') ?? 0,
    );
  }

  Future<List<LocalOpenTableBillDto>> fetchOpenTableBills({
    String branchId = 'branch_1',
  }) async {
    final res = await _http.get(
      'api/local/orders/open-table-bills',
      query: {'branchId': branchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить счета на столах',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ open-table-bills');
    }
    final raw = body['bills'];
    if (raw is! List) return const [];

    LocalOpenTableBillLineDto parseLine(Map<String, dynamic> m) {
      final q = m['quantity'];
      final qty = q is int ? q : int.tryParse(q?.toString() ?? '') ?? 0;
      final lt = m['lineTotal'] ?? m['line_total'];
      final total = lt is num ? lt.toDouble() : double.tryParse(lt?.toString() ?? '') ?? 0.0;
      return LocalOpenTableBillLineDto(
        name: m['name']?.toString() ?? '',
        quantity: qty,
        lineTotal: total,
      );
    }

    final out = <LocalOpenTableBillDto>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final linesRaw = m['lines'];
      final lines = <LocalOpenTableBillLineDto>[];
      if (linesRaw is List) {
        for (final lr in linesRaw) {
          if (lr is Map) {
            lines.add(parseLine(Map<String, dynamic>.from(lr)));
          }
        }
      }
      final totalRaw = m['total'] ?? m['totalPrice'];
      final total = totalRaw is num
          ? totalRaw.toDouble()
          : double.tryParse(totalRaw?.toString() ?? '') ?? 0.0;
      out.add(
        LocalOpenTableBillDto(
          id: m['id']?.toString() ?? '',
          number: m['number']?.toString() ?? '',
          total: total,
          orderType: m['orderType']?.toString() ?? m['order_type']?.toString() ?? 'На месте',
          tableLabel: m['tableLabel']?.toString() ?? m['table_label']?.toString() ?? '',
          createdAtIso: m['createdAt']?.toString() ?? m['created_at']?.toString(),
          lines: lines,
        ),
      );
    }
    return out;
  }
}

class LocalOpenTableBillLineDto {
  const LocalOpenTableBillLineDto({
    required this.name,
    required this.quantity,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double lineTotal;
}

class LocalOpenTableBillDto {
  const LocalOpenTableBillDto({
    required this.id,
    required this.number,
    required this.total,
    required this.orderType,
    required this.tableLabel,
    required this.lines,
    this.createdAtIso,
  });

  final String id;
  final String number;
  final double total;
  final String orderType;
  final String tableLabel;
  final String? createdAtIso;
  final List<LocalOpenTableBillLineDto> lines;
}
