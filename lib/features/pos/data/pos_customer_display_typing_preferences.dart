import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';

/// Локальные тексты «печати» для экрана клиента (настройки на кассе).
class PosCustomerDisplayTypingPreferences {
  PosCustomerDisplayTypingPreferences._();

  static const _kTypingJson = 'pos_customer_display_typing_v1';

  static CustomerDisplayTypingConfig? _cache;

  static CustomerDisplayTypingConfig? get cached => _cache;

  static Future<CustomerDisplayTypingConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTypingJson);
    if (raw == null || raw.trim().isEmpty) {
      _cache = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = null;
        return null;
      }
      final config = CustomerDisplayTypingConfig.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      _cache = config.hasMessages ? config : null;
      return _cache;
    } catch (_) {
      _cache = null;
      return null;
    }
  }

  static Future<void> save(CustomerDisplayTypingConfig config) async {
    final normalized = config.copyWith(messages: config.effectiveMessages);
    _cache = normalized.hasMessages ? normalized : null;
    final prefs = await SharedPreferences.getInstance();
    if (!normalized.hasMessages) {
      await prefs.remove(_kTypingJson);
      return;
    }
    await prefs.setString(_kTypingJson, jsonEncode(normalized.toJson()));
  }

  static Future<void> clear() async {
    _cache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTypingJson);
  }

  static Future<CustomerDisplayContentConfig> mergeIntoConfig(
    CustomerDisplayContentConfig? remote,
  ) async {
    final base = remote ?? CustomerDisplayContentConfig.fallback();
    final local = await load();
    if (local != null && local.hasMessages) {
      return base.copyWith(typing: local);
    }
    if (base.typing.hasMessages) return base;
    return base.copyWith(typing: CustomerDisplayTypingConfig.fallback());
  }
}
