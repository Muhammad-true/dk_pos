import 'package:flutter/material.dart';

/// Брейкпоинты и расчёты под телефон / планшет / десктоп (ориентир M3).
///
/// Не хранит состояние — только ширина окна; дёшево вызывать из [LayoutBuilder].
class WindowLayout {
  const WindowLayout({required this.width});

  final double width;

  factory WindowLayout.of(BuildContext context) {
    return WindowLayout(width: MediaQuery.sizeOf(context).width);
  }

  /// Ниже — «телефон» в основном портрете.
  static const double compactMax = 600;

  /// Планшет / узкое окно на ПК.
  static const double mediumMax = 840;

  /// Типичный десктоп / широкий планшет.
  static const double expandedMax = 1200;

  /// Боковая навигация (админ rail).
  static const double railBreakpoint = 720;

  static const double railExtendedBreakpoint = 1000;

  /// Категории POS сбоку (список), иначе — горизонтальные чипы.
  static const double posCategorySidebarBreakpoint = 600;

  /// Корзина закреплена справа (десктоп).
  static const double posCartDockBreakpoint = 960;

  static const double posCartPanelWidth = 336;

  static const double posCategoryRailWidth = 200;

  bool get isCompact => width < compactMax;
  bool get isMedium => width >= compactMax && width < mediumMax;
  bool get isExpanded => width >= mediumMax && width < expandedMax;
  bool get isLarge => width >= expandedMax;

  bool get showAdminRail => width >= railBreakpoint;
  bool get extendedAdminRail => width >= railExtendedBreakpoint;

  bool get dockPosCart => width >= posCartDockBreakpoint;

  bool get loginSplitHero => width >= 900;

  bool get loginComfortableHorizontalPadding => width >= compactMax;

  /// Ширина области каталога (без панели корзины).
  double get posCatalogPaneWidth =>
      dockPosCart ? width - posCartPanelWidth - 1 : width;

  bool posSideCategoryNavForCatalogPane(double catalogPaneWidth) =>
      catalogPaneWidth >= posCategorySidebarBreakpoint;

  int posCatalogGridColumns({
    required double catalogPaneWidth,
    required bool sideCategoryNav,
  }) {
    final side = sideCategoryNav ? posCategoryRailWidth : 0.0;
    const pad = 24.0;
    final gridW = catalogPaneWidth - side - pad;
    if (gridW < 200) return 2;
    const minCell = 132.0;
    const gutter = 12.0;
    final n = ((gridW + gutter) / (minCell + gutter)).floor();
    return n.clamp(2, 7);
  }

  double posCatalogGridAspectRatio(double catalogPaneWidth) {
    if (catalogPaneWidth < compactMax) return 0.70;
    if (catalogPaneWidth < mediumMax) return 0.76;
    return 0.82;
  }

  double adminBodyMaxWidth(double viewportWidth) =>
      (viewportWidth * 0.92).clamp(320.0, 960.0);
}
