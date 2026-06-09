import 'package:flutter/material.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';

/// Тема рабочих экранов (касса, сборка, кухня): светлая / тёмная, высокий контраст.
ThemeData buildPosWorkspaceTheme(ThemeData base, PosScreenTheme mode, Color accentColor) {
  return mode == PosScreenTheme.dark
      ? _buildPosDarkTheme(base, accentColor)
      : _buildPosLightTheme(base, accentColor);
}

/// Градиент фона экрана клиента (следует теме кассы).
List<Color> customerDisplayBackgroundGradient(ThemeData theme) {
  final s = theme.colorScheme;
  final sc = theme.scaffoldBackgroundColor;
  if (theme.brightness == Brightness.dark) {
    return [
      Color.lerp(const Color(0xFF120A0A), s.surface, 0.4)!,
      s.surface,
      const Color(0xFF090909),
    ];
  }
  return [
    Color.lerp(const Color(0xFFFFF4F6), s.surfaceContainerLow, 0.55)!,
    sc,
    Color.lerp(s.surfaceContainerLow, sc, 0.35)!,
  ];
}

/// Полупрозрачная панель на экране клиента.
Color customerDisplayGlassFill(ThemeData theme) {
  if (theme.brightness == Brightness.dark) {
    return Colors.white.withValues(alpha: 0.06);
  }
  return theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92);
}

Color customerDisplayGlassBorder(ThemeData theme) {
  if (theme.brightness == Brightness.dark) {
    return Colors.white.withValues(alpha: 0.10);
  }
  return theme.colorScheme.outlineVariant;
}

/// Поверхность чека / карточки товара на экране клиента.
Color customerDisplayCardSurface(ThemeData theme) {
  return theme.colorScheme.surfaceContainerLowest;
}

Color customerDisplayCardBorder(ThemeData theme) {
  return theme.colorScheme.outlineVariant;
}

/// Вертикальный градиент под контент (касса, кухня, сборка).
List<Color> posWorkspaceBodyGradient(ThemeData theme) {
  final s = theme.colorScheme;
  final sc = theme.scaffoldBackgroundColor;
  if (theme.brightness == Brightness.dark) {
    return [
      Color.lerp(s.surfaceContainerHigh, s.surfaceContainerLowest, 0.45)!,
      sc,
    ];
  }
  return [
    Color.lerp(s.surfaceContainerLow, s.surfaceContainerLowest, 0.65)!,
    sc,
  ];
}

ThemeData _buildPosDarkTheme(ThemeData base, Color accentColor) {
  final scheme = const ColorScheme.dark(
    primary: Color(0xFFE4002B),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFD166),
    onSecondary: Color(0xFF2C1600),
    surface: Color(0xFF1A1D24),
    onSurface: Color(0xFFF6F1E8),
    error: Color(0xFFE36262),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF6B707C),
    outlineVariant: Color(0xFF303541),
    surfaceContainerLowest: Color(0xFF171A20),
    surfaceContainerLow: Color(0xFF1F232C),
    surfaceContainer: Color(0xFF272C36),
    surfaceContainerHigh: Color(0xFF2D3340),
    surfaceContainerHighest: Color(0xFF343B48),
    onSurfaceVariant: Color(0xFFAAB2C3),
  ).copyWith(primary: accentColor);

  final textTheme = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF111318),
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: const Color(0xFF111318),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    dividerColor: scheme.outlineVariant,
    inputDecorationTheme: _posInputDecorationTheme(scheme, textTheme),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
    ),
  );
}

InputDecorationTheme _posInputDecorationTheme(
  ColorScheme scheme,
  TextTheme textTheme,
) {
  const radius = 14.0;
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
    hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}

ThemeData _buildPosLightTheme(ThemeData base, Color accentColor) {
  final scheme = const ColorScheme.light(
    primary: Color(0xFFE4002B),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFD166),
    onSecondary: Color(0xFF2C1600),
    surface: Color(0xFFF7F7F9),
    onSurface: Color(0xFF1F2430),
    error: Color(0xFFE36262),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFFB8BEC9),
    outlineVariant: Color(0xFFDADDE4),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F3F7),
    surfaceContainer: Color(0xFFE9EDF3),
    surfaceContainerHigh: Color(0xFFE0E5EE),
    surfaceContainerHighest: Color(0xFFD8DEE9),
    onSurfaceVariant: Color(0xFF5B6474),
  ).copyWith(primary: accentColor);

  final textTheme = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3F4F7),
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: const Color(0xFFF3F4F7),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    dividerColor: scheme.outlineVariant,
    inputDecorationTheme: _posInputDecorationTheme(scheme, textTheme),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
    ),
  );
}
