import 'package:dk_pos/core/network/http_client.dart';

enum PosBoardLayout {
  list,
  cards;

  static PosBoardLayout parse(
    Object? raw, {
    PosBoardLayout fallback = PosBoardLayout.cards,
  }) {
    final v = raw?.toString().trim().toLowerCase();
    if (v == 'list') return PosBoardLayout.list;
    if (v == 'cards') return PosBoardLayout.cards;
    return fallback;
  }

  String get apiValue => name;
}

class LocalPosSettings {
  const LocalPosSettings({
    this.allowManualDiscount = false,
    this.ordersLayout = PosBoardLayout.cards,
    this.billsLayout = PosBoardLayout.cards,
    this.freeTableOnPayment = true,
    this.courierDeliveryEnabled = true,
  });

  final bool allowManualDiscount;
  final PosBoardLayout ordersLayout;
  final PosBoardLayout billsLayout;

  /// Если true — после успешной оплаты стол снимается с заказа.
  /// По умолчанию true; в админке можно отключить.
  final bool freeTableOnPayment;
  final bool courierDeliveryEnabled;

  factory LocalPosSettings.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    final freeRaw = m['freeTableOnPayment'] ?? m['free_table_on_payment'];
    final courierRaw =
        m['courierDeliveryEnabled'] ?? m['courier_delivery_enabled'];
    return LocalPosSettings(
      allowManualDiscount: m['allowManualDiscount'] == true,
      ordersLayout: PosBoardLayout.parse(
        m['ordersLayout'] ?? m['orders_layout'],
      ),
      billsLayout: PosBoardLayout.parse(m['billsLayout'] ?? m['bills_layout']),
      // Нет ключа / null → включено (дефолт).
      freeTableOnPayment: freeRaw == null
          ? true
          : freeRaw == true || freeRaw == 1 || freeRaw == '1',
      courierDeliveryEnabled: courierRaw == null
          ? true
          : courierRaw == true || courierRaw == 1 || courierRaw == '1',
    );
  }
}

class LocalPosSettingsRepository {
  LocalPosSettingsRepository(this._http);
  final HttpClient _http;

  Future<LocalPosSettings> fetch() async {
    final res = await _http.get('/api/local/pos-settings');
    if (res.body is Map) {
      final settings = (res.body as Map)['settings'];
      if (settings is Map) {
        return LocalPosSettings.fromJson(Map<String, dynamic>.from(settings));
      }
    }
    return const LocalPosSettings();
  }

  Future<bool> fetchAllowManualDiscount() async {
    final s = await fetch();
    return s.allowManualDiscount;
  }

  Future<void> updateAllowManualDiscount(bool allow) async {
    await update(allowManualDiscount: allow);
  }

  Future<LocalPosSettings> update({
    bool? allowManualDiscount,
    PosBoardLayout? ordersLayout,
    PosBoardLayout? billsLayout,
    bool? freeTableOnPayment,
    bool? courierDeliveryEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (allowManualDiscount != null) {
      body['allowManualDiscount'] = allowManualDiscount;
    }
    if (ordersLayout != null) {
      body['ordersLayout'] = ordersLayout.apiValue;
    }
    if (billsLayout != null) {
      body['billsLayout'] = billsLayout.apiValue;
    }
    if (freeTableOnPayment != null) {
      body['freeTableOnPayment'] = freeTableOnPayment;
    }
    if (courierDeliveryEnabled != null) {
      body['courierDeliveryEnabled'] = courierDeliveryEnabled;
    }
    final res = await _http.patch('/api/local/pos-settings', body: body);
    if (res.body is Map) {
      final settings = (res.body as Map)['settings'];
      if (settings is Map) {
        return LocalPosSettings.fromJson(Map<String, dynamic>.from(settings));
      }
    }
    return fetch();
  }
}
