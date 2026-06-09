import 'package:flutter/material.dart';

import 'package:dk_pos/app/pos_catalog_grid/pos_catalog_grid_settings.dart'
    show PosCatalogCardSize, PosCatalogGridSettings;

/// Брейкпоинты и расчёты под телефон / планшет / десктоп (ориентир M3).
///
/// Не хранит состояние — только ширина окна; дёшево вызывать из [LayoutBuilder].
class WindowLayout {
  const WindowLayout({required this.width, this.shortestSide});

  final double width;
  final double? shortestSide;

  factory WindowLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return WindowLayout(width: size.width, shortestSide: size.shortestSide);
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

  static const double posCartPanelWidth = 347;

  static const double posCategoryRailWidth = 200;

  bool get isCompact => width < compactMax;
  bool get isMedium => width >= compactMax && width < mediumMax;
  bool get isExpanded => width >= mediumMax && width < expandedMax;
  bool get isLarge => width >= expandedMax;

  bool get showAdminRail => width >= railBreakpoint;
  bool get extendedAdminRail => width >= railExtendedBreakpoint;

  /// Компактная верхняя панель POS: drawer, сокращённый AppBar.
  bool get posNarrowToolbar => width < compactMax;

  /// Корзина закреплена справа: десктоп @960+ или landscape-планшет @840+.
  bool get dockPosCart {
    if (width >= posCartDockBreakpoint) return true;
    final ss = shortestSide ?? width;
    return width >= mediumMax && ss >= compactMax;
  }

  bool get loginSplitHero => width >= 900;

  bool get loginComfortableHorizontalPadding => width >= compactMax;

  /// Ширина области каталога (без панели корзины).
  double get posCatalogPaneWidth =>
      dockPosCart ? width - posCartPanelWidth - 1 : width;

  bool posSideCategoryNavForCatalogPane(double catalogPaneWidth) =>
      catalogPaneWidth >= posCategorySidebarBreakpoint;

  int posCatalogGridColumnsAuto({
    required double catalogPaneWidth,
    required bool sideCategoryNav,
    double minCellWidth = 132,
  }) {
    final side = sideCategoryNav ? posCategoryRailWidth : 0.0;
    const pad = 24.0;
    final gridW = catalogPaneWidth - side - pad;
    if (gridW < 200) return 2;
    const gutter = 12.0;
    final n = ((gridW + gutter) / (minCellWidth + gutter)).floor();
    return n.clamp(2, 8);
  }

  int posCatalogGridColumns({
    required double catalogPaneWidth,
    required bool sideCategoryNav,
    PosCatalogGridSettings? grid,
  }) {
    final g = grid ?? PosCatalogGridSettings.defaults;
    return g.columnsFor(
      catalogPaneWidth: catalogPaneWidth,
      sideCategoryNav: sideCategoryNav,
    );
  }

  double posCatalogGridAspectRatio(
    double catalogPaneWidth, {
    bool orderAppendMode = false,
    PosCatalogCardSize cardSize = PosCatalogCardSize.normal,
  }) {
    if (orderAppendMode) {
      final base = cardSize.aspectRatio;
      if (catalogPaneWidth < 520) return base - 0.06;
      if (catalogPaneWidth < 720) return base - 0.02;
      return base;
    }
    return cardSize.aspectRatio;
  }

  /// Ширина колонки каталога, когда корзина уже стоит справа в [Row].
  double posCatalogPaneWidthBesideCart(double viewportWidth, double cartPanelWidth) {
    final w = viewportWidth - cartPanelWidth - 2;
    return w > 280 ? w : 280;
  }

  double adminBodyMaxWidth(double viewportWidth) =>
      (viewportWidth * 0.92).clamp(320.0, 960.0);

  /// Колонки карточек в диалогах (заказы, счета, hub-плитки).
  int cardGridColumns({double minCellWidth = 280}) {
    if (width < 560) return 1;
    if (width < 900) return 2;
    return (width / minCellWidth).floor().clamp(2, 3);
  }

  /// Колонки hub-плиток (админ-каталог, обзор).
  int hubGridColumns({double minCellWidth = 260}) {
    if (width < compactMax) return 1;
    return (width / minCellWidth).floor().clamp(2, 4);
  }
}
