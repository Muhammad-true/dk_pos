import 'package:shared_preferences/shared_preferences.dart';

/// Масштаб интерфейса кухни (сохраняется на планшете).
class KitchenUiScale {
  const KitchenUiScale({
    this.buttonScale = 1,
    this.buttonTextScale = 1,
    this.itemTextScale = 1,
  });

  final double buttonScale;
  final double buttonTextScale;
  final double itemTextScale;

  static const standard = KitchenUiScale();
  static const large = KitchenUiScale(
    buttonScale: 1.22,
    buttonTextScale: 1.14,
    itemTextScale: 1.1,
  );

  KitchenUiScale clamped() {
    double c(double v) => v.clamp(0.75, 1.6);
    return KitchenUiScale(
      buttonScale: c(buttonScale),
      buttonTextScale: c(buttonTextScale),
      itemTextScale: c(itemTextScale),
    );
  }
}

class KitchenUiPreferences {
  static const _kButtonScale = 'kitchen_ui_button_scale';
  static const _kButtonTextScale = 'kitchen_ui_button_text_scale';
  static const _kItemTextScale = 'kitchen_ui_item_text_scale';

  static Future<KitchenUiScale> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KitchenUiScale(
      buttonScale: prefs.getDouble(_kButtonScale) ?? KitchenUiScale.standard.buttonScale,
      buttonTextScale:
          prefs.getDouble(_kButtonTextScale) ?? KitchenUiScale.standard.buttonTextScale,
      itemTextScale: prefs.getDouble(_kItemTextScale) ?? KitchenUiScale.standard.itemTextScale,
    ).clamped();
  }

  static Future<void> save(KitchenUiScale scale) async {
    final s = scale.clamped();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kButtonScale, s.buttonScale);
    await prefs.setDouble(_kButtonTextScale, s.buttonTextScale);
    await prefs.setDouble(_kItemTextScale, s.itemTextScale);
  }
}
