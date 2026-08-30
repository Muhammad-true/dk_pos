import 'package:dk_pos/core/error/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/core/network/http_retry.dart';
import 'package:dk_pos/core/utils/variable_sale_qty.dart';
import 'package:dk_pos/shared/models/pos_menu_models.dart';

class LocalOrderLineInput {
  const LocalOrderLineInput({
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    this.lineKey,
    this.modifiers = const [],
    this.actualQty,
    this.defaultSaleQty,
    this.saleMeasure,
  });

  final String menuItemId;
  final int quantity;
  final double unitPrice;
  final String? lineKey;
  final List<Map<String, dynamic>> modifiers;
  final double? actualQty;
  final double? defaultSaleQty;
  final String? saleMeasure;

  Map<String, dynamic> toJson() => {
    'menuItemId': menuItemId,
    'quantity': quantity,
    'unitPrice': unitPrice,
    if (lineKey != null) 'lineKey': lineKey,
    if (modifiers.isNotEmpty) 'modifiers': modifiers,
    if (actualQty != null) 'actualQty': actualQty,
    if (defaultSaleQty != null) 'defaultSaleQty': defaultSaleQty,
    if (saleMeasure != null) 'saleMeasure': saleMeasure,
  };
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

/// Ответ PATCH …/orders/:id/line (изменение количества / удаление позиции).
class LocalPatchOrderLineResult {
  const LocalPatchOrderLineResult({
    required this.orderId,
    required this.status,
    required this.totalPrice,
    this.number = '',
    this.orderCancelledEmpty = false,
  });

  final String orderId;
  final String status;
  final double totalPrice;
  final String number;

  /// Все позиции убраны — заказ автоматически отменён на сервере.
  final bool orderCancelledEmpty;
}

class LocalKitchenQueueItem {
  const LocalKitchenQueueItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    this.lineKey,
    this.saleMeasure,
    this.actualQty,
    this.defaultSaleQty,
    this.kitchenLineStatus = 'pending',
    this.kitchenAcceptedByUserId,
    this.kitchenAcceptedByUsername,
    this.kitchenAcceptedAtIso,
    this.kitchenReadyByUserId,
    this.kitchenReadyByUsername,
    this.kitchenReadyAtIso,
    this.kitchenStationId,
    this.kitchenStationName,
  });

  final String menuItemId;
  final String name;
  final int quantity;
  final String? lineKey;
  final String? saleMeasure;
  final double? actualQty;
  final double? defaultSaleQty;
  final String kitchenLineStatus;
  final int? kitchenAcceptedByUserId;
  final String? kitchenAcceptedByUsername;
  final String? kitchenAcceptedAtIso;
  final int? kitchenReadyByUserId;
  final String? kitchenReadyByUsername;
  final String? kitchenReadyAtIso;
  final int? kitchenStationId;
  final String? kitchenStationName;

  factory LocalKitchenQueueItem.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    int? asNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final ksRaw = json['kitchenStationId'] ?? json['kitchen_station_id'];
    int? ks;
    if (ksRaw is int) {
      ks = ksRaw;
    } else if (ksRaw != null) {
      ks = int.tryParse(ksRaw.toString());
    }

    final lkRaw = json['lineKey'] ?? json['line_key'];
    final lk = lkRaw?.toString().trim();

    return LocalKitchenQueueItem(
      menuItemId: json['menuItemId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: asInt(json['quantity']),
      lineKey: lk != null && lk.isNotEmpty ? lk : null,
      saleMeasure:
          json['saleMeasure']?.toString() ?? json['sale_measure']?.toString(),
      actualQty: () {
        final v = json['actualQty'] ?? json['actual_qty'];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '');
      }(),
      defaultSaleQty: () {
        final v = json['defaultSaleQty'] ?? json['default_sale_qty'];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '');
      }(),
      kitchenLineStatus:
          json['kitchenLineStatus']?.toString() ??
          json['kitchen_line_status']?.toString() ??
          'pending',
      kitchenAcceptedByUserId: asNullableInt(
        json['kitchenAcceptedByUserId'] ?? json['kitchen_accepted_by_user_id'],
      ),
      kitchenAcceptedByUsername:
          json['kitchenAcceptedByUsername']?.toString() ??
          json['kitchen_accepted_by_username']?.toString(),
      kitchenAcceptedAtIso:
          json['kitchenAcceptedAt']?.toString() ??
          json['kitchen_accepted_at']?.toString(),
      kitchenReadyByUserId: asNullableInt(
        json['kitchenReadyByUserId'] ?? json['kitchen_ready_by_user_id'],
      ),
      kitchenReadyByUsername:
          json['kitchenReadyByUsername']?.toString() ??
          json['kitchen_ready_by_username']?.toString(),
      kitchenReadyAtIso:
          json['kitchenReadyAt']?.toString() ??
          json['kitchen_ready_at']?.toString(),
      kitchenStationId: ks,
      kitchenStationName:
          json['kitchenStationName']?.toString() ??
          json['kitchen_station_name']?.toString(),
    );
  }
}

class LocalKitchenActorProfile {
  const LocalKitchenActorProfile({
    required this.id,
    required this.username,
    this.kitchenButtonId,
    this.kitchenButtonName,
    this.kitchenButtonColorHex,
  });

  final int id;
  final String username;
  final int? kitchenButtonId;
  final String? kitchenButtonName;
  final String? kitchenButtonColorHex;
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
    final title = _kitchenPrepareTitle();
    return '$title ($assemblyKitchenTag)';
  }

  String _kitchenPrepareTitle() {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return name;

    // Бэкенд (forKitchen) уже отдаёт «7× Донер» / «Стрипсы 300 г» — не дублируем.
    if (_kitchenNameAlreadyShowsQuantity(trimmedName)) {
      return trimmedName;
    }

    final m = (saleMeasure ?? '').trim().toLowerCase();
    final per = actualQty;
    final isVariablePortion =
        per != null && per > 0 && (m == 'pcs' || m == 'gram' || m == 'g');
    if (isVariablePortion) {
      final total = (per * (quantity > 0 ? quantity : 1)).round();
      final unit = m == 'gram' || m == 'g' ? 'г' : 'шт';
      final base = _stripTrailingQtyFromName(trimmedName);
      if (base.isNotEmpty) {
        return '$base $total $unit';
      }
    }
    return trimmedName;
  }
}

bool _kitchenNameAlreadyShowsQuantity(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'^\d+\s*[×xх]\s', caseSensitive: false).hasMatch(t)) {
    return true;
  }
  if (RegExp(
    r'\d+\s*(шт|штук|pcs|г|g)\s*$',
    caseSensitive: false,
  ).hasMatch(t)) {
    return true;
  }
  return false;
}

String _stripTrailingQtyFromName(String raw) {
  return VariableSaleQty.stripEmbeddedQtyFromName(raw);
}

class LocalKitchenQueueOrder {
  const LocalKitchenQueueOrder({
    required this.id,
    required this.number,
    this.orderType,
    this.tableLabel,
    required this.status,
    required this.totalPrice,
    required this.items,
    this.handOutSource,
    this.handedOutAtIso,
  });

  final String id;
  final String number;
  final String? orderType;
  final String? tableLabel;
  final String status;
  final double totalPrice;
  final List<LocalKitchenQueueItem> items;

  /// После `done`: `manual` | `auto` с бэкенда; `null` — старые заказы без поля.
  final String? handOutSource;

  /// Заказ хотя бы раз выдавали гостю — дозаказ после этой метки режется на выдаче.
  final String? handedOutAtIso;

  LocalKitchenQueueOrder copyWith({
    String? orderType,
    String? tableLabel,
    bool clearTableLabel = false,
  }) {
    return LocalKitchenQueueOrder(
      id: id,
      number: number,
      orderType: orderType ?? this.orderType,
      tableLabel: clearTableLabel ? null : (tableLabel ?? this.tableLabel),
      status: status,
      totalPrice: totalPrice,
      items: items,
      handOutSource: handOutSource,
      handedOutAtIso: handedOutAtIso,
    );
  }

  factory LocalKitchenQueueOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(LocalKitchenQueueItem.fromJson)
              .toList()
        : const <LocalKitchenQueueItem>[];
    final hoRaw = json['handOutSource'] ?? json['hand_out_source'];
    final hoStr = hoRaw?.toString().trim() ?? '';
    final handedRaw = json['handedOutAt'] ?? json['handed_out_at'];
    final handedStr = handedRaw?.toString().trim() ?? '';
    return LocalKitchenQueueOrder(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      orderType:
          json['orderType']?.toString() ?? json['order_type']?.toString(),
      tableLabel:
          json['tableLabel']?.toString() ?? json['table_label']?.toString(),
      status: json['status']?.toString() ?? 'new',
      totalPrice:
          num.tryParse(json['totalPrice']?.toString() ?? '')?.toDouble() ?? 0,
      items: items,
      handOutSource: hoStr.isEmpty ? null : hoStr.toLowerCase(),
      handedOutAtIso: handedStr.isEmpty ? null : handedStr,
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
    this.orderSource,
    this.needsCashierAck = false,
    this.receiptPrinted,
    this.globalSitePushStatus,
  });

  final LocalKitchenQueueOrder order;
  final bool requiresPayment;
  final String? orderType;
  final String? tableLabel;

  /// `pos` | `website` — с бэкенда после синка сайта.
  final String? orderSource;

  /// Статус new без подтверждения кассиром (входящий без стола и т.п.).
  final bool needsCashierAck;

  /// Фискальный чек последней оплаты: `null` если не оплачен или нет данных в БД.
  final bool? receiptPrinted;

  /// Последний статус, отправленный на global API (`with_courier`, `delivered`, …).
  final String? globalSitePushStatus;

  LocalCashierBoardOrder copyWith({
    String? tableLabel,
    String? orderType,
    bool? requiresPayment,
    bool clearTableLabel = false,
  }) {
    final nextTable = clearTableLabel ? '' : (tableLabel ?? this.tableLabel);
    final nextType = orderType ?? this.orderType;
    return LocalCashierBoardOrder(
      order: order.copyWith(
        orderType: nextType,
        tableLabel: nextTable,
        clearTableLabel: clearTableLabel,
      ),
      requiresPayment: requiresPayment ?? this.requiresPayment,
      orderType: nextType,
      tableLabel: nextTable,
      orderSource: orderSource,
      needsCashierAck: needsCashierAck,
      receiptPrinted: receiptPrinted,
      globalSitePushStatus: globalSitePushStatus,
    );
  }

  factory LocalCashierBoardOrder.fromJson(Map<String, dynamic> json) {
    bool? receiptPrinted;
    final rp = json['receiptPrinted'] ?? json['receipt_printed'];
    if (rp == true) {
      receiptPrinted = true;
    } else if (rp == false) {
      receiptPrinted = false;
    }
    return LocalCashierBoardOrder(
      order: LocalKitchenQueueOrder.fromJson(json),
      requiresPayment:
          json['requiresPayment'] == true || json['requires_payment'] == true,
      orderType:
          json['orderType']?.toString() ?? json['order_type']?.toString(),
      tableLabel:
          json['tableLabel']?.toString() ?? json['table_label']?.toString(),
      orderSource:
          json['orderSource']?.toString() ?? json['order_source']?.toString(),
      needsCashierAck:
          json['needsCashierAck'] == true || json['needs_cashier_ack'] == true,
      receiptPrinted: receiptPrinted,
      globalSitePushStatus:
          json['globalSitePushStatus']?.toString() ??
          json['global_site_push_status']?.toString(),
    );
  }
}

class LocalKitchenQueueSnapshot {
  const LocalKitchenQueueSnapshot({
    required this.preparing,
    required this.waitingOthers,
    required this.readyForPickup,
    this.queueRevision,
  });

  final List<LocalKitchenQueueOrder> preparing;
  final List<LocalKitchenQueueOrder> waitingOthers;
  final List<LocalKitchenQueueOrder> readyForPickup;
  final int? queueRevision;
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
    this.queueRevision,
  });

  final List<LocalKitchenQueueOrder> bundling;
  final List<LocalKitchenQueueOrder> pickup;
  final int? queueRevision;
}

class LocalOrdersRepository {
  LocalOrdersRepository(this._http);

  final HttpClient _http;
  String get _defaultBranchId => AppConfig.storeBranchId;

  String get _defaultTerminalId {
    final v = dotenv.maybeGet('POS_TERMINAL_ID')?.trim();
    return (v != null && v.isNotEmpty) ? v : 'KASSA-1';
  }

  Future<LocalOrderResult> createOrUpdateOrder({
    required String orderId,
    required List<LocalOrderLineInput> lines,
    required double totalAmount,
    required String orderType,
    String? tableLabel,
    Map<String, dynamic>? deliveryMeta,
    double? deliveryFee,
    String? terminalId,
  }) async {
    final bodyLines = lines.map((l) => l.toJson()).toList(growable: false);

    final res = await _http.post(
      'api/local/orders',
      body: {
        'orderId': orderId,
        'branchId': _defaultBranchId,
        'lines': bodyLines,
        'totalAmount': totalAmount,
        'orderType': orderType,
        'tableLabel': tableLabel,
        if (deliveryMeta != null) 'deliveryMeta': deliveryMeta,
        if (deliveryFee != null) 'deliveryFee': deliveryFee,
        'terminalId': terminalId ?? _defaultTerminalId,
      },
      receiveTimeout: lines.length >= 20
          ? const Duration(seconds: 45)
          : const Duration(seconds: 20),
      sendTimeout: lines.length >= 20
          ? const Duration(seconds: 45)
          : const Duration(seconds: 20),
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
    final total =
        num.tryParse(order['totalPrice']?.toString() ?? '')?.toDouble() ??
        totalAmount;
    if (id.isEmpty || number.isEmpty) {
      throw ApiException(
        res.statusCode,
        'Сервер вернул неполные данные заказа',
      );
    }
    final note = body['note']?.toString().toLowerCase() ?? '';
    if (bodyLines.isNotEmpty && note.contains('позиции не переданы')) {
      throw ApiException(
        res.statusCode,
        'Заказ на сервере без позиций — повторите оформление',
      );
    }
    return LocalOrderResult(
      orderId: id,
      number: number,
      totalPrice: total,
      created: body['created'] == true,
    );
  }

  /// Фиксирует согласие клиента до изменения интернет-заказа.
  /// Сервер создаёт ревизию, которая затем попадёт в сайт и приложение.
  Future<void> recordSiteOrderChangeConsent({
    required String orderId,
    String reason = 'Изменено по согласованию с клиентом',
  }) async {
    final id = orderId.trim();
    if (id.isEmpty) return;
    final res = await _http.post(
      'api/local/orders/$id/site-order-change-consent',
      body: {
        'reason': reason,
        'terminalId': _defaultTerminalId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось зафиксировать согласие клиента',
      );
    }
  }

  /// Сменить / назначить стол у неоплаченного заказа (гость пересел или сел позже).
  Future<({String? tableLabel, String? orderType, bool noop})>
  updateOrderTable({
    required String orderId,
    String? tableLabel,
    bool clearTable = false,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/table',
      body: {
        if (clearTable) 'clearTable': true,
        if (!clearTable) 'tableLabel': tableLabel,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось изменить стол',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ смены стола');
    }
    final order = body['order'];
    final label = order is Map
        ? (order['tableLabel'] ?? order['table_label'])?.toString()
        : null;
    final orderType = order is Map
        ? (order['orderType'] ?? order['order_type'])?.toString()
        : null;
    return (
      tableLabel: label,
      orderType: orderType,
      noop: body['noop'] == true,
    );
  }

  /// Журнал событий заказа (смена стола и др.) для диалога «История».
  Future<List<LocalOrderEvent>> fetchOrderEvents(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) return const [];
    final res = await _http.get('api/local/orders/$id/events');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить историю заказа',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ истории заказа');
    }
    final raw = body['events'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LocalOrderEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Сменить способ заказа (с собой / на месте / доставка) после оформления.
  Future<({String? tableLabel, String? orderType, bool noop})> updateOrderType({
    required String orderId,
    required String orderType,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/order-type',
      body: {'orderType': orderType},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось изменить тип заказа',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ смены типа');
    }
    final order = body['order'];
    final label = order is Map
        ? (order['tableLabel'] ?? order['table_label'])?.toString()
        : null;
    final nextType = order is Map
        ? (order['orderType'] ?? order['order_type'])?.toString()
        : null;
    return (tableLabel: label, orderType: nextType, noop: body['noop'] == true);
  }

  Future<LocalKitchenQueueSnapshot> fetchKitchenQueueMy() async {
    const localTimeout = Duration(seconds: 8);
    final res = await _http.get(
      'api/local/orders/queue/my',
      receiveTimeout: localTimeout,
      sendTimeout: localTimeout,
    );
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
      queueRevision: body['queueRevision'] ?? body['queue_revision'],
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
      queueRevision: body['queueRevision'] ?? body['queue_revision'],
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
      throw ApiException(
        res.statusCode,
        'Некорректный ответ сервера очереди сборки',
      );
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
      queueRevision: body['queueRevision'] ?? body['queue_revision'],
    );
  }

  Future<void> updateKitchenProgress({
    required String orderId,
    required String action,
    int? actorUserId,
    String? menuItemId,
  }) async {
    const kitchenActionTimeout = Duration(seconds: 12);
    return withNetworkRetry(
      () async {
        final body = <String, dynamic>{'action': action};
        if (actorUserId != null && actorUserId > 0) {
          body['actorUserId'] = actorUserId;
        }
        final menuItem = (menuItemId ?? '').trim();
        if (menuItem.isNotEmpty) {
          body['menuItemId'] = menuItem;
        }
        final res = await _http.patch(
          'api/local/orders/$orderId/kitchen-progress',
          body: body,
          receiveTimeout: kitchenActionTimeout,
          sendTimeout: kitchenActionTimeout,
        );
        if (res.statusCode != 200) {
          throw ApiException.fromHttp(
            res.statusCode,
            res.body,
            fallbackMessage: 'Не удалось обновить этап кухни',
          );
        }
      },
      // 1 повтор достаточно: сервер теперь noop на повторный accept.
      attempts: 2,
      initialDelay: const Duration(milliseconds: 400),
    );
  }

  Future<List<LocalKitchenActorProfile>> fetchKitchenTeamMyStation() async {
    final res = await _http.get('api/local/orders/kitchen-team/my-station');
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить список поваров по кухне',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ kitchen-team');
    }
    final raw = body['users'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          int? asNullableInt(dynamic v) {
            if (v == null) return null;
            if (v is int) return v;
            if (v is num) return v.toInt();
            return int.tryParse(v.toString());
          }

          return LocalKitchenActorProfile(
            id: asNullableInt(m['id']) ?? 0,
            username: m['username']?.toString() ?? '',
            kitchenButtonId: asNullableInt(
              m['kitchenButtonId'] ?? m['kitchen_button_id'],
            ),
            kitchenButtonName:
                m['kitchenButtonName']?.toString() ??
                m['kitchen_button_name']?.toString(),
            kitchenButtonColorHex:
                m['kitchenButtonColorHex']?.toString() ??
                m['kitchen_button_color_hex']?.toString(),
          );
        })
        .where((e) => e.id > 0 && e.username.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> handoffOrder({
    required String orderId,
    required String action,
    String? handOutSource,
  }) async {
    final body = <String, dynamic>{'action': action};
    if (action == 'hand_out') {
      body['handOutSource'] =
          (handOutSource ?? 'manual').trim().toLowerCase() == 'auto'
          ? 'auto'
          : 'manual';
    }
    final res = await _http.patch(
      'api/local/orders/$orderId/handoff',
      body: body,
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось выполнить действие выдачи',
      );
    }
  }

  Future<void> cancelOrder({
    required String orderId,
    String? reason,
    String? branchId,
  }) async {
    final body = <String, dynamic>{'branchId': branchId ?? _defaultBranchId};
    final cleanReason = reason?.trim();
    if (cleanReason != null && cleanReason.isNotEmpty) {
      body['reason'] = cleanReason;
    }
    final res = await _http.patch(
      'api/local/orders/$orderId/cancel',
      body: body,
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось отменить заказ',
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

  /// Неоплаченные счета филиала (GET /open-table-bills): стол, «с собой» и т.д.
  Future<List<LocalCashierBoardOrder>> fetchCashierIncomingOrders({
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/orders/cashier-incoming',
      query: {'branchId': branchId ?? _defaultBranchId},
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
        .map(
          (e) => LocalCashierBoardOrder.fromJson(Map<String, dynamic>.from(e)),
        )
        .where((o) => o.order.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<LocalCashierBoardOrder>> fetchCashierActiveOrders({
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/orders/cashier-active',
      query: {'branchId': branchId ?? _defaultBranchId},
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
        .map(
          (e) => LocalCashierBoardOrder.fromJson(Map<String, dynamic>.from(e)),
        )
        .where((o) => o.order.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> acknowledgeCashierIncomingOrder({
    required String orderId,
    String? branchId,
  }) async {
    final res = await _http.patch(
      'api/local/orders/$orderId/cashier-ack',
      body: {'branchId': branchId ?? _defaultBranchId},
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
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/reports/kitchen-my-today',
      query: {'branchId': branchId ?? _defaultBranchId},
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
      itemsReady: itemsRaw is num
          ? itemsRaw.toInt()
          : int.tryParse(itemsRaw?.toString() ?? '') ?? 0,
      spentSeconds: spentRaw is num
          ? spentRaw.toInt()
          : int.tryParse(spentRaw?.toString() ?? '') ?? 0,
    );
  }

  Future<LocalPatchOrderLineResult> patchOrderLineQuantity({
    required String orderId,
    required String menuItemId,
    required int quantity,
    String? lineKey,
    String? reason,
    String? branchId,
  }) async {
    final cleanReason = reason?.trim();
    final res = await _http.patch(
      'api/local/orders/$orderId/line',
      body: {
        'menuItemId': menuItemId,
        if (lineKey != null && lineKey.trim().isNotEmpty)
          'lineKey': lineKey.trim(),
        'quantity': quantity,
        if (cleanReason != null && cleanReason.isNotEmpty)
          'reason': cleanReason,
        'branchId': branchId ?? _defaultBranchId,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage:
            'Нельзя убрать позицию. Если кухня уже приняла блюдо — укажите причину убирания.',
      );
    }
    final body = res.body;
    if (body is! Map) {
      return LocalPatchOrderLineResult(
        orderId: orderId,
        status: '',
        totalPrice: 0,
      );
    }
    final map = Map<String, dynamic>.from(body);
    final orderRaw = map['order'];
    final order = orderRaw is Map
        ? Map<String, dynamic>.from(orderRaw)
        : const {};
    final tp = order['totalPrice'] ?? order['total_price'];
    final total = tp is num
        ? tp.toDouble()
        : double.tryParse(tp?.toString() ?? '') ?? 0;
    final cancelledFlag =
        map['orderCancelledEmpty'] == true ||
        map['order_cancelled_empty'] == true;
    final status = order['status']?.toString() ?? '';
    final number = order['number']?.toString() ?? '';
    return LocalPatchOrderLineResult(
      orderId: order['id']?.toString() ?? orderId,
      status: status,
      totalPrice: total,
      number: number,
      orderCancelledEmpty: cancelledFlag,
    );
  }

  Future<List<LocalOpenTableBillDto>> fetchOpenTableBills({
    String? branchId,
  }) async {
    final res = await _http.get(
      'api/local/orders/open-table-bills',
      query: {'branchId': branchId ?? _defaultBranchId},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Не удалось загрузить счета на оплату',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ open-table-bills');
    }
    final raw = body['bills'];
    if (raw is! List) return const [];

    int? parseNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    LocalOpenTableBillLineDto parseLine(Map<String, dynamic> m) {
      final q = m['quantity'];
      final qty = q is int ? q : int.tryParse(q?.toString() ?? '') ?? 0;
      final lt = m['lineTotal'] ?? m['line_total'];
      final total = lt is num
          ? lt.toDouble()
          : double.tryParse(lt?.toString() ?? '') ?? 0.0;
      final upRaw = m['unitPrice'] ?? m['unit_price'];
      final up = upRaw is num
          ? upRaw.toDouble()
          : double.tryParse(upRaw?.toString() ?? '');
      final midRaw = m['menuItemId'] ?? m['menu_item_id'];
      final mid = midRaw?.toString().trim();
      final lkRaw = m['lineKey'] ?? m['line_key'];
      final lk = lkRaw?.toString().trim();
      final modsRaw = m['modifiers'];
      final modifiers = <PosCartModifier>[];
      if (modsRaw is List) {
        for (final mr in modsRaw) {
          if (mr is Map) {
            modifiers.add(
              PosCartModifier.fromJson(Map<String, dynamic>.from(mr)),
            );
          }
        }
      }
      return LocalOpenTableBillLineDto(
        name: m['name']?.toString() ?? '',
        quantity: qty,
        lineTotal: total,
        menuItemId: mid != null && mid.isNotEmpty ? mid : null,
        lineKey: lk != null && lk.isNotEmpty ? lk : null,
        unitPrice: up,
        kitchenLineStatus:
            m['kitchenLineStatus']?.toString() ??
            m['kitchen_line_status']?.toString(),
        kitchenStationId: parseNullableInt(
          m['kitchenStationId'] ?? m['kitchen_station_id'],
        ),
        modifiers: modifiers,
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
      final promoRaw = m['promoDiscountAmount'] ?? m['promo_discount_amount'];
      final promoDiscount = promoRaw is num
          ? promoRaw.toDouble()
          : double.tryParse(promoRaw?.toString() ?? '');
      final subtotalRaw = m['subtotal'] ?? m['order_subtotal'];
      final subtotal = subtotalRaw is num
          ? subtotalRaw.toDouble()
          : double.tryParse(subtotalRaw?.toString() ?? '');
      final deliveryFeeRaw = m['deliveryFee'] ?? m['delivery_fee'];
      final deliveryFee = deliveryFeeRaw is num
          ? deliveryFeeRaw.toDouble()
          : double.tryParse(deliveryFeeRaw?.toString() ?? '') ?? 0.0;
      final graceRaw =
          m['tableSessionGraceMinutes'] ?? m['table_session_grace_minutes'];
      final graceMin = graceRaw is int
          ? graceRaw
          : int.tryParse(graceRaw?.toString() ?? '');
      out.add(
        LocalOpenTableBillDto(
          id: m['id']?.toString() ?? '',
          number: m['number']?.toString() ?? '',
          status: m['status']?.toString() ?? '',
          total: total,
          orderType:
              m['orderType']?.toString() ??
              m['order_type']?.toString() ??
              'На месте',
          tableLabel:
              m['tableLabel']?.toString() ?? m['table_label']?.toString() ?? '',
          isDelivery: m['isDelivery'] == true || m['is_delivery'] == true,
          customerPhone:
              m['customerPhone']?.toString() ?? m['customer_phone']?.toString(),
          orderSource:
              m['orderSource']?.toString() ?? m['order_source']?.toString(),
          createdAtIso:
              m['createdAt']?.toString() ?? m['created_at']?.toString(),
          createdByUsername:
              m['createdByUsername']?.toString() ??
              m['created_by_username']?.toString(),
          createdByRole:
              m['createdByRole']?.toString() ??
              m['created_by_role']?.toString(),
          terminalId:
              m['terminalId']?.toString() ?? m['terminal_id']?.toString(),
          isWaiterOrder:
              m['isWaiterOrder'] == true || m['is_waiter_order'] == true,
          isTakeaway: m['isTakeaway'] == true || m['is_takeaway'] == true,
          isCashierOrder:
              m['isCashierOrder'] == true || m['is_cashier_order'] == true,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          promoCode: m['promoCode']?.toString() ?? m['promo_code']?.toString(),
          promoDiscountAmount: promoDiscount,
          isPaid: m['isPaid'] == true || m['is_paid'] == true,
          requiresPayment:
              m['requiresPayment'] == true ||
              m['requires_payment'] == true ||
              (m['requiresPayment'] == null &&
                  m['requires_payment'] == null &&
                  !(m['isPaid'] == true || m['is_paid'] == true) &&
                  total > 0),
          handedOutAtIso:
              m['handedOutAt']?.toString() ?? m['handed_out_at']?.toString(),
          tableSessionPhase:
              m['tableSessionPhase']?.toString() ??
              m['table_session_phase']?.toString(),
          tableSessionEndsAtIso:
              m['tableSessionEndsAt']?.toString() ??
              m['table_session_ends_at']?.toString(),
          tableSessionGraceMinutes: graceMin,
          lines: lines,
        ),
      );
    }
    return out;
  }

  Future<LocalPromoValidateResult> validatePromoCode({
    required String code,
    required double subtotal,
  }) async {
    final res = await _http.post(
      'api/local/promo-codes/validate',
      body: {'code': code.trim(), 'subtotal': subtotal},
    );
    if (res.statusCode != 200) {
      throw ApiException.fromHttp(
        res.statusCode,
        res.body,
        fallbackMessage: 'Промокод недоступен',
      );
    }
    final body = res.body;
    if (body is! Map) {
      throw ApiException(res.statusCode, 'Некорректный ответ validate promo');
    }
    final m = Map<String, dynamic>.from(body);
    final discountRaw = m['discount_amount'] ?? m['discountAmount'];
    final discount = discountRaw is num
        ? discountRaw.toDouble()
        : double.tryParse(discountRaw?.toString() ?? '') ?? 0;
    final promo = m['promo'];
    String? title;
    if (promo is Map) {
      title = promo['title']?.toString();
    }
    return LocalPromoValidateResult(
      code: code.trim().toUpperCase(),
      discountAmount: discount,
      title: title,
    );
  }
}

class LocalPromoValidateResult {
  const LocalPromoValidateResult({
    required this.code,
    required this.discountAmount,
    this.title,
  });

  final String code;
  final double discountAmount;
  final String? title;
}

class LocalOpenTableBillLineDto {
  const LocalOpenTableBillLineDto({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.menuItemId,
    this.lineKey,
    this.unitPrice,
    this.kitchenLineStatus,
    this.kitchenStationId,
    this.modifiers = const [],
  });

  final String name;
  final int quantity;
  final double lineTotal;
  final String? menuItemId;
  final String? lineKey;
  final double? unitPrice;
  final String? kitchenLineStatus;
  final int? kitchenStationId;
  final List<PosCartModifier> modifiers;
}

class LocalOpenTableBillDto {
  const LocalOpenTableBillDto({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.orderType,
    required this.tableLabel,
    required this.lines,
    this.orderSource,
    this.createdAtIso,
    this.isDelivery = false,
    this.customerPhone,
    this.createdByUsername,
    this.createdByRole,
    this.terminalId,
    this.isWaiterOrder = false,
    this.isTakeaway = false,
    this.isCashierOrder = false,
    this.subtotal,
    this.deliveryFee = 0,
    this.promoCode,
    this.promoDiscountAmount,
    this.isPaid = false,
    this.requiresPayment,
    this.handedOutAtIso,
    this.tableSessionPhase,
    this.tableSessionEndsAtIso,
    this.tableSessionGraceMinutes,
  });

  final String id;
  final String number;
  final String status;
  final double total;
  final String orderType;
  final String tableLabel;

  /// `pos` | `website` — с бэкенда open-table-bills.
  final String? orderSource;
  final String? createdAtIso;
  final bool isDelivery;
  final String? customerPhone;
  final String? createdByUsername;
  final String? createdByRole;
  final String? terminalId;
  final bool isWaiterOrder;
  final bool isTakeaway;
  final bool isCashierOrder;
  final double? subtotal;
  final double deliveryFee;
  final String? promoCode;
  final double? promoDiscountAmount;
  final bool isPaid;
  final bool? requiresPayment;
  final String? handedOutAtIso;

  /// `active` | `handed_out` | null
  final String? tableSessionPhase;
  final String? tableSessionEndsAtIso;
  final int? tableSessionGraceMinutes;
  final List<LocalOpenTableBillLineDto> lines;
}

/// Событие журнала заказа (смена стола и др.).
class LocalOrderEvent {
  const LocalOrderEvent({
    required this.id,
    required this.orderId,
    required this.eventType,
    this.payload = const {},
    this.actorUsername = '',
    this.createdAtIso,
  });

  factory LocalOrderEvent.fromJson(Map<String, dynamic> m) {
    final payloadRaw = m['payload'] ?? m['payload_json'];
    final payload = <String, dynamic>{};
    if (payloadRaw is Map) {
      payload.addAll(Map<String, dynamic>.from(payloadRaw));
    }
    return LocalOrderEvent(
      id: m['id'] is num
          ? (m['id'] as num).toInt()
          : int.tryParse('${m['id']}') ?? 0,
      orderId: (m['orderId'] ?? m['order_id'] ?? '').toString(),
      eventType: (m['eventType'] ?? m['event_type'] ?? '').toString(),
      payload: payload,
      actorUsername: (m['actorUsername'] ?? m['actor_username'] ?? '')
          .toString()
          .trim(),
      createdAtIso: (m['createdAt'] ?? m['created_at'])?.toString(),
    );
  }

  final int id;
  final String orderId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String actorUsername;
  final String? createdAtIso;

  String get fromLabel =>
      (payload['from'] ?? payload['fromLabel'] ?? '').toString().trim();

  String get toLabel =>
      (payload['to'] ?? payload['toLabel'] ?? '').toString().trim();

  bool get cleared =>
      payload['cleared'] == true || (toLabel.isEmpty && fromLabel.isNotEmpty);
}
