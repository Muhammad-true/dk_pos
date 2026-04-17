import 'package:flutter/material.dart';

/// Реальная локаль UI (в т.ч. `tg` для ARB), в отличие от [MaterialApp.locale],
/// который для `tg` подменяется на локаль с поддержкой Material.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.locale,
    required super.child,
  });

  final Locale locale;

  static Locale localeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    if (scope == null) {
      throw FlutterError(
        'AppLocaleScope не найден выше $context. '
        'Оборачивайте MaterialApp в AppLocaleScope.',
      );
    }
    return scope.locale;
  }

  @override
  bool updateShouldNotify(covariant AppLocaleScope oldWidget) =>
      oldWidget.locale != locale;
}
