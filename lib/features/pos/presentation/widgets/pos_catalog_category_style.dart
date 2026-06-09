import 'package:flutter/material.dart';

/// Палитра корневых категорий (как на кассе).
List<Color> posCategoryCardColors(int index) {
  const palette = [
    [Color(0xFFE4002B), Color(0xFFB00022)],
    [Color(0xFF14A44D), Color(0xFF0D6B32)],
    [Color(0xFFFF8A00), Color(0xFFC96A00)],
    [Color(0xFF2B8DFF), Color(0xFF1A5DD1)],
    [Color(0xFFFFC107), Color(0xFFD69200)],
    [Color(0xFFB06CFF), Color(0xFF7F3FE0)],
    [Color(0xFF00B8A9), Color(0xFF00796B)],
    [Color(0xFFFF6B6B), Color(0xFFC44545)],
  ];
  return palette[index % palette.length];
}

/// Градиент подкатегории по названию (как на кассе).
List<Color> posCategoryColors(String name) {
  final value = name.toLowerCase();
  if (value.contains('бург')) {
    return const [Color(0xFFE4002B), Color(0xFF9F0020)];
  }
  if (value.contains('донер') || value.contains('шаур')) {
    return const [Color(0xFF00A86B), Color(0xFF0A6C4A)];
  }
  if (value.contains('комбо')) {
    return const [Color(0xFFFF7A00), Color(0xFFC25700)];
  }
  if (value.contains('напит')) {
    return const [Color(0xFF1D8BFF), Color(0xFF1353B7)];
  }
  if (value.contains('соус')) {
    return const [Color(0xFFFFC21A), Color(0xFFC78B00)];
  }
  if (value.contains('десерт')) {
    return const [Color(0xFF9B5CFF), Color(0xFF6630C2)];
  }
  return const [Color(0xFF5F6B7A), Color(0xFF394350)];
}

IconData posCategoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('бург')) return Icons.lunch_dining_rounded;
  if (value.contains('донер') || value.contains('шаур')) {
    return Icons.kebab_dining_rounded;
  }
  if (value.contains('комбо')) return Icons.fastfood_rounded;
  if (value.contains('напит')) return Icons.local_drink_rounded;
  if (value.contains('соус')) return Icons.soup_kitchen_rounded;
  if (value.contains('десерт')) return Icons.icecream_rounded;
  if (value.contains('снек') || value.contains('закуск')) {
    return Icons.tapas_rounded;
  }
  if (value.contains('карто')) return Icons.set_meal_rounded;
  return Icons.restaurant_menu_rounded;
}
