import 'package:shared_preferences/shared_preferences.dart';

/// Локальные настройки интерфейса кассы (на устройстве).
class PosUiPreferences {
  PosUiPreferences._();

  static const _kFlyToCartEnabled = 'pos_fly_to_cart_enabled_v1';

  static bool? _flyToCartEnabledCache;

  /// По умолчанию включено.
  static bool get flyToCartEnabled => _flyToCartEnabledCache ?? true;

  static Future<bool> loadFlyToCartEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_kFlyToCartEnabled) ?? true;
    _flyToCartEnabledCache = value;
    return value;
  }

  static Future<void> setFlyToCartEnabled(bool enabled) async {
    _flyToCartEnabledCache = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFlyToCartEnabled, enabled);
  }
}
