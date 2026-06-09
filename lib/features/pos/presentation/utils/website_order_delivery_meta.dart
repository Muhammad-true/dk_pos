/// Метаданные доставки/сайта из поля `table_label` онлайн-заказа.
class WebsiteOrderDeliveryMeta {
  const WebsiteOrderDeliveryMeta({
    required this.label,
    this.address,
    this.coords,
    this.courierHandoff,
    this.phone,
    this.contact,
    this.comment,
    this.deliveryWhen,
    this.deliveryDate,
  });

  final String label;
  final String? address;
  final String? coords;
  final String? courierHandoff;
  final String? phone;
  final String? contact;
  final String? comment;
  final String? deliveryWhen;
  final String? deliveryDate;
}

WebsiteOrderDeliveryMeta parseWebsiteOrderDeliveryMeta(String rawLabel) {
  final parts = rawLabel
      .split('·')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  String? address;
  String? coords;
  String? courierHandoff;
  String? phone;
  String? contact;
  String? comment;
  String? deliveryWhen;
  String? deliveryDate;
  final clean = <String>[];
  for (final p in parts) {
    final low = p.toLowerCase();
    if (low.startsWith('адрес:')) {
      final v = p.substring('адрес:'.length).trim();
      if (v.isNotEmpty) address = v;
      continue;
    }
    if (low.startsWith('тел:')) {
      final v = p.substring('тел:'.length).trim();
      if (v.isNotEmpty) phone = v;
      continue;
    }
    if (low.startsWith('комментарий:')) {
      final v = p.substring('комментарий:'.length).trim();
      if (v.isNotEmpty) comment = v;
      continue;
    }
    if (low.startsWith('время:')) {
      final v = p.substring('время:'.length).trim();
      if (v.isNotEmpty) deliveryWhen = v;
      continue;
    }
    if (low.startsWith('дата:')) {
      final v = p.substring('дата:'.length).trim();
      if (v.isNotEmpty) deliveryDate = v;
      continue;
    }
    if (low.startsWith('окно:')) {
      final v = p.substring('окно:'.length).trim();
      if (v.isNotEmpty) deliveryWhen = v;
      continue;
    }
    if (low.startsWith('коорд:')) {
      final v = p.substring('коорд:'.length).trim();
      if (v.isNotEmpty) coords = v;
      continue;
    }
    if (low == 'выдача курьеру') {
      courierHandoff = 'Выдача курьеру';
      continue;
    }
    if (contact == null &&
        !low.startsWith('доставка') &&
        !low.startsWith('самовывоз') &&
        !low.startsWith('парковка') &&
        !low.startsWith('сайт №')) {
      contact = p;
    }
    clean.add(p);
  }
  return WebsiteOrderDeliveryMeta(
    label: clean.isEmpty ? rawLabel : clean.join(' · '),
    address: address,
    coords: coords,
    courierHandoff: courierHandoff,
    phone: phone,
    contact: contact,
    comment: comment,
    deliveryWhen: deliveryWhen,
    deliveryDate: deliveryDate,
  );
}

String? normalizePhoneForTelUri(String? raw) {
  final src = (raw ?? '').trim();
  if (src.isEmpty) return null;
  final digits = StringBuffer();
  for (var i = 0; i < src.length; i++) {
    final c = src[i];
    if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
      digits.write(c);
    } else if (c == '+' && digits.isEmpty) {
      digits.write(c);
    }
  }
  final s = digits.toString();
  if (s.replaceAll('+', '').length < 7) return null;
  return s;
}
