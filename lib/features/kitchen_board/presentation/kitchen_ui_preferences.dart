import 'package:shared_preferences/shared_preferences.dart';

/// Масштаб и раскладка интерфейса кухни (сохраняется на планшете).
class KitchenUiScale {
  const KitchenUiScale({
    this.buttonScale = 1,
    this.buttonTextScale = 1,
    this.itemTextScale = 1,
    this.orderColumns = 1,
  });

  final double buttonScale;
  final double buttonTextScale;
  final double itemTextScale;

  /// 1 — заказы друг под другом; 2 — две колонки карточек.
  final int orderColumns;

  static const standard = KitchenUiScale();
  static const large = KitchenUiScale(
    buttonScale: 1.22,
    buttonTextScale: 1.14,
    itemTextScale: 1.1,
  );

  /// Рекомендуется для планшета на кухне (крупные кнопки, лёгкое чтение).
  static const tablet = KitchenUiScale(
    buttonScale: 1.38,
    buttonTextScale: 1.24,
    itemTextScale: 1.14,
    orderColumns: 2,
  );

  KitchenUiScale clamped() {
    double c(double v) => v.clamp(0.75, 1.6);
    return KitchenUiScale(
      buttonScale: c(buttonScale),
      buttonTextScale: c(buttonTextScale),
      itemTextScale: c(itemTextScale),
      orderColumns: orderColumns.clamp(1, 2),
    );
  }
}

class KitchenUiPreferences {
  static const _kButtonScale = 'kitchen_ui_button_scale';
  static const _kButtonTextScale = 'kitchen_ui_button_text_scale';
  static const _kItemTextScale = 'kitchen_ui_item_text_scale';
  static const _kOrderColumns = 'kitchen_ui_order_columns';
  static const _kConfigured = 'kitchen_ui_configured_v1';

  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConfigured) ?? false;
  }

  static Future<bool> hasOrderColumnsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kOrderColumns);
  }

  static Future<KitchenUiScale> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KitchenUiScale(
      buttonScale: prefs.getDouble(_kButtonScale) ?? KitchenUiScale.standard.buttonScale,
      buttonTextScale:
          prefs.getDouble(_kButtonTextScale) ?? KitchenUiScale.standard.buttonTextScale,
      itemTextScale: prefs.getDouble(_kItemTextScale) ?? KitchenUiScale.standard.itemTextScale,
      orderColumns: prefs.getInt(_kOrderColumns) ?? KitchenUiScale.standard.orderColumns,
    ).clamped();
  }

  static Future<void> save(KitchenUiScale scale) async {
    final s = scale.clamped();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kButtonScale, s.buttonScale);
    await prefs.setDouble(_kButtonTextScale, s.buttonTextScale);
    await prefs.setDouble(_kItemTextScale, s.itemTextScale);
    await prefs.setInt(_kOrderColumns, s.orderColumns);
    await prefs.setBool(_kConfigured, true);
  }
}

/// Поведение экрана при дозаказе (дополнение к уже готовящемуся счёту).
class KitchenFollowUpSettings {
  const KitchenFollowUpSettings({
    this.enabled = true,
    this.highlightCard = true,
    this.highlightNewLines = true,
    this.collapseReadyItems = true,
    this.hideReadyItems = false,
    this.notifySound = true,
    this.notifyTts = true,
    this.notifySnack = true,
  });

  /// Режим «дозаказ»: отличать новые позиции от уже готовых.
  final bool enabled;

  /// Оранжевая карточка, бейдж «Дозаказ», плашка «готовить только новое».
  final bool highlightCard;

  /// Метка «ГОТОВИТЬ» на новых позициях.
  final bool highlightNewLines;

  /// Сворачивать блок «Уже готово — не готовить».
  final bool collapseReadyItems;

  /// Полностью скрывать уже готовые позиции (только новое в списке).
  final bool hideReadyItems;

  /// Звук и вибрация при дозаказе.
  final bool notifySound;

  /// Озвучка с названиями блюд («Приготовить только: …»).
  final bool notifyTts;

  /// Всплывающее сообщение внизу экрана.
  final bool notifySnack;

  static const defaults = KitchenFollowUpSettings();

  KitchenFollowUpSettings copyWith({
    bool? enabled,
    bool? highlightCard,
    bool? highlightNewLines,
    bool? collapseReadyItems,
    bool? hideReadyItems,
    bool? notifySound,
    bool? notifyTts,
    bool? notifySnack,
  }) {
    return KitchenFollowUpSettings(
      enabled: enabled ?? this.enabled,
      highlightCard: highlightCard ?? this.highlightCard,
      highlightNewLines: highlightNewLines ?? this.highlightNewLines,
      collapseReadyItems: collapseReadyItems ?? this.collapseReadyItems,
      hideReadyItems: hideReadyItems ?? this.hideReadyItems,
      notifySound: notifySound ?? this.notifySound,
      notifyTts: notifyTts ?? this.notifyTts,
      notifySnack: notifySnack ?? this.notifySnack,
    );
  }
}

class KitchenFollowUpPreferences {
  static const _kEnabled = 'kitchen_followup_enabled_v1';
  static const _kHighlightCard = 'kitchen_followup_highlight_card_v1';
  static const _kHighlightNewLines = 'kitchen_followup_highlight_lines_v1';
  static const _kCollapseReady = 'kitchen_followup_collapse_ready_v1';
  static const _kHideReady = 'kitchen_followup_hide_ready_v1';
  static const _kNotifySound = 'kitchen_followup_notify_sound_v1';
  static const _kNotifyTts = 'kitchen_followup_notify_tts_v1';
  static const _kNotifySnack = 'kitchen_followup_notify_snack_v1';

  static Future<KitchenFollowUpSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return KitchenFollowUpSettings(
      enabled: prefs.getBool(_kEnabled) ?? KitchenFollowUpSettings.defaults.enabled,
      highlightCard:
          prefs.getBool(_kHighlightCard) ?? KitchenFollowUpSettings.defaults.highlightCard,
      highlightNewLines: prefs.getBool(_kHighlightNewLines) ??
          KitchenFollowUpSettings.defaults.highlightNewLines,
      collapseReadyItems: prefs.getBool(_kCollapseReady) ??
          KitchenFollowUpSettings.defaults.collapseReadyItems,
      hideReadyItems:
          prefs.getBool(_kHideReady) ?? KitchenFollowUpSettings.defaults.hideReadyItems,
      notifySound:
          prefs.getBool(_kNotifySound) ?? KitchenFollowUpSettings.defaults.notifySound,
      notifyTts: prefs.getBool(_kNotifyTts) ?? KitchenFollowUpSettings.defaults.notifyTts,
      notifySnack:
          prefs.getBool(_kNotifySnack) ?? KitchenFollowUpSettings.defaults.notifySnack,
    );
  }

  static Future<void> save(KitchenFollowUpSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, settings.enabled);
    await prefs.setBool(_kHighlightCard, settings.highlightCard);
    await prefs.setBool(_kHighlightNewLines, settings.highlightNewLines);
    await prefs.setBool(_kCollapseReady, settings.collapseReadyItems);
    await prefs.setBool(_kHideReady, settings.hideReadyItems);
    await prefs.setBool(_kNotifySound, settings.notifySound);
    await prefs.setBool(_kNotifyTts, settings.notifyTts);
    await prefs.setBool(_kNotifySnack, settings.notifySnack);
  }
}

/// Все локальные настройки экрана кухни на этом планшете.
class KitchenScreenSettings {
  const KitchenScreenSettings({
    required this.uiScale,
    required this.followUp,
  });

  final KitchenUiScale uiScale;
  final KitchenFollowUpSettings followUp;

  KitchenScreenSettings copyWith({
    KitchenUiScale? uiScale,
    KitchenFollowUpSettings? followUp,
  }) {
    return KitchenScreenSettings(
      uiScale: uiScale ?? this.uiScale,
      followUp: followUp ?? this.followUp,
    );
  }
}

class KitchenScreenPreferences {
  static Future<KitchenScreenSettings> load() async {
    final results = await Future.wait([
      KitchenUiPreferences.load(),
      KitchenFollowUpPreferences.load(),
    ]);
    return KitchenScreenSettings(
      uiScale: results[0] as KitchenUiScale,
      followUp: results[1] as KitchenFollowUpSettings,
    );
  }

  static Future<void> save(KitchenScreenSettings settings) async {
    await Future.wait([
      KitchenUiPreferences.save(settings.uiScale),
      KitchenFollowUpPreferences.save(settings.followUp),
    ]);
  }
}
