/// Расчёт цены и подписей для продажи по шт/г с базовой порцией.
class VariableSaleQty {
  const VariableSaleQty({
    required this.enabled,
    required this.measure,
    required this.defaultQty,
    required this.actualQty,
  });

  final bool enabled;
  final String measure;
  final double defaultQty;
  final double actualQty;

  bool get isPcs => measure == 'pcs';
  bool get isGram => measure == 'gram';

  double get scale {
    if (!enabled || defaultQty <= 0) return 1;
    if (actualQty <= 0) return 1;
    return actualQty / defaultQty;
  }

  static String normalizeMeasure(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'gram' || s == 'g' || s == 'г') return 'gram';
    return 'pcs';
  }

  static double parseQty(dynamic raw, double fallback) {
    if (raw is num) {
      if (raw > 0) return raw.toDouble();
    } else {
      final n = double.tryParse(raw?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    return fallback;
  }

  factory VariableSaleQty.fromMenuItem({
    required bool enabled,
    String? measure,
    double? defaultQty,
    double? actualQty,
  }) {
    if (!enabled) {
      return const VariableSaleQty(
        enabled: false,
        measure: 'pcs',
        defaultQty: 1,
        actualQty: 1,
      );
    }
    final m = normalizeMeasure(measure);
    final def = parseQty(defaultQty, m == 'gram' ? 200 : 6);
    final act = parseQty(actualQty, def);
    return VariableSaleQty(
      enabled: true,
      measure: m,
      defaultQty: def,
      actualQty: act,
    );
  }

  double scaledPrice(double catalogPrice) => catalogPrice * scale;

  String get qtyLabel {
    if (!enabled) return '';
    final n = actualQty.round();
    return measure == 'gram' ? '$n г' : '$n шт';
  }

  static String stripEmbeddedQtyFromName(String raw) {
    var name = raw.trim();
    if (name.isEmpty) return raw.trim();
    final patterns = [
      RegExp(r'\s+\d+[\s,.]?\d*\s*(шт|штук|pcs|pc)\s*$', caseSensitive: false),
      RegExp(r'\s+\d+[\s,.]?\d*\s*(г|g|gram)\s*$', caseSensitive: false),
      RegExp(r'\s+\d+[\s,.]?\d*(шт|г)\s*$', caseSensitive: false),
    ];
    var changed = true;
    while (changed) {
      changed = false;
      for (final re in patterns) {
        final next = name.replaceFirst(re, '').trim();
        if (next != name) {
          name = next;
          changed = true;
        }
      }
    }
    return name.isEmpty ? raw.trim() : name;
  }

  String displayName(String baseName, {int quantity = 1}) {
    final name = stripEmbeddedQtyFromName(baseName);
    if (!enabled) {
      return quantity > 1 ? '$quantity× $name' : name;
    }
    final label = qtyLabel;
    if (quantity > 1) {
      final total = (actualQty * quantity).round();
      final totalLabel = measure == 'gram' ? '$total г' : '$total шт';
      return '$name $totalLabel';
    }
    return '$name $label';
  }

  VariableSaleQty copyWith({double? actualQty}) {
    return VariableSaleQty(
      enabled: enabled,
      measure: measure,
      defaultQty: defaultQty,
      actualQty: actualQty ?? this.actualQty,
    );
  }
}
