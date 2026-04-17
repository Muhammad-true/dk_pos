import 'package:flutter/material.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';

/// Тема рабочих экранов (касса, сборка, кухня): светлая / тёмная, высокий контраст.
ThemeData buildPosWorkspaceTheme(ThemeData base, PosScreenTheme mode) {
  return mode == PosScreenTheme.dark ? _buildPosDarkTheme(base) : _buildPosLightTheme(base);
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

ThemeData _buildPosDarkTheme(ThemeData base) {
  const scheme = ColorScheme.dark(
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
  );

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
  );
}

ThemeData _buildPosLightTheme(ThemeData base) {
  const scheme = ColorScheme.light(
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
  );

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
  );
}
