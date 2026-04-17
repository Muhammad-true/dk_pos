import 'package:flutter/material.dart';

/// Адаптивные отступы и шрифты очередей (кухня / сборка) для телефона, планшета и большого экрана.
abstract final class PosQueueLayout {
  /// Короткая сторона экрана (удобно для телефон / планшет).
  static double shortestSide(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide;

  /// Отступ списка [ListView] / [RefreshIndicator].
  static double listPadding(BuildContext context, {required bool embedded}) {
    final s = shortestSide(context);
    if (s < 360) return embedded ? 8 : 12;
    if (s < 600) return embedded ? 12 : 14;
    if (s < 900) return embedded ? 14 : 18;
    return embedded ? 16 : 22;
  }

  static EdgeInsets cardOuterPadding(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return const EdgeInsets.all(12);
    if (s < 600) return const EdgeInsets.all(14);
    if (s < 900) return const EdgeInsets.all(16);
    return const EdgeInsets.all(18);
  }

  static double iconBox(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 44;
    if (s < 600) return 48;
    if (s < 900) return 52;
    return 56;
  }

  static double iconInner(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 24;
    if (s < 600) return 26;
    if (s < 900) return 28;
    return 30;
  }

  static double iconRadius(BuildContext context) => iconBox(context) * 0.27;

  /// Заголовок «Заказ N» на экране сборки.
  static double orderTitleExpeditor(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 24;
    if (s < 600) return 28;
    if (s < 900) return 32;
    return 36;
  }

  /// Заголовок заказа на кухне.
  static double orderTitleKitchen(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 22;
    if (s < 600) return 26;
    if (s < 900) return 30;
    return 34;
  }

  static double itemLine(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 16;
    if (s < 600) return 18;
    if (s < 900) return 20;
    return 22;
  }

  static double kitchenStatusIcon(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 22;
    if (s < 600) return 24;
    if (s < 900) return 26;
    return 28;
  }

  static double metaIcon(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 16;
    if (s < 600) return 17;
    return 18;
  }

  static double buttonVerticalPadding(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 12;
    if (s < 600) return 14;
    return 16;
  }

  static double rowGutter(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 10;
    if (s < 600) return 12;
    return 14;
  }

  static double itemRowSpacing(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 8;
    if (s < 600) return 10;
    return 12;
  }

  static double bulletTopPad(BuildContext context) {
    if (shortestSide(context) < 360) return 5;
    return 6;
  }

  static double waitingHint(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 15;
    if (s < 600) return 16;
    if (s < 900) return 17;
    return 18;
  }

  static double sectionBarWidth(BuildContext context) =>
      shortestSide(context) < 600 ? 3.0 : 4.0;

  static double sectionBarHeight(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 16;
    if (s < 900) return 18;
    return 20;
  }

  static double sectionGap(BuildContext context) =>
      shortestSide(context) < 600 ? 8 : 10;

  static double sectionFont(BuildContext context) {
    final s = shortestSide(context);
    if (s < 360) return 13;
    if (s < 600) return 14;
    if (s < 900) return 15;
    return 16;
  }
}
