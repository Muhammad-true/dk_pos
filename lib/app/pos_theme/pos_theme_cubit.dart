import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/storage/key_value_store.dart';

/// Тема экрана кассы (POS): светлая / тёмная. Хранится в SharedPreferences.
enum PosScreenTheme { light, dark }

enum PosAccentColor {
  red,
  blue,
  green,
  purple,
  custom,
}

extension PosAccentColorX on PosAccentColor {
  String get storageValue => switch (this) {
        PosAccentColor.red => 'red',
        PosAccentColor.blue => 'blue',
        PosAccentColor.green => 'green',
        PosAccentColor.purple => 'purple',
        PosAccentColor.custom => 'custom',
      };

  Color get presetColor => switch (this) {
        PosAccentColor.red => const Color(0xFFE4002B),
        PosAccentColor.blue => const Color(0xFF1565C0),
        PosAccentColor.green => const Color(0xFF2E7D32),
        PosAccentColor.purple => const Color(0xFF6A1B9A),
        PosAccentColor.custom => const Color(0xFFE4002B),
      };

  String get label => switch (this) {
        PosAccentColor.red => 'Красный',
        PosAccentColor.blue => 'Синий',
        PosAccentColor.green => 'Зелёный',
        PosAccentColor.purple => 'Фиолетовый',
        PosAccentColor.custom => 'Свой',
      };
}

PosAccentColor parsePosAccentColor(String? value) {
  return switch (value) {
    'blue' => PosAccentColor.blue,
    'green' => PosAccentColor.green,
    'purple' => PosAccentColor.purple,
    'custom' => PosAccentColor.custom,
    _ => PosAccentColor.red,
  };
}

Color parseCustomAccentColor(String? value) {
  final s = (value ?? '').trim();
  final hex = s.startsWith('#') ? s.substring(1) : s;
  if (hex.length != 6) return const Color(0xFFE4002B);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return const Color(0xFFE4002B);
  return Color(0xFF000000 | parsed);
}

String encodeColorHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  return '#$hex';
}

class PosThemeSettings {
  const PosThemeSettings({
    required this.mode,
    required this.accent,
    required this.customAccentColor,
  });

  final PosScreenTheme mode;
  final PosAccentColor accent;
  final Color customAccentColor;

  Color get accentColor => accent == PosAccentColor.custom ? customAccentColor : accent.presetColor;

  PosThemeSettings copyWith({
    PosScreenTheme? mode,
    PosAccentColor? accent,
    Color? customAccentColor,
  }) {
    return PosThemeSettings(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
      customAccentColor: customAccentColor ?? this.customAccentColor,
    );
  }
}

class PosThemeCubit extends Cubit<PosThemeSettings> {
  PosThemeCubit(this._kv)
      : super(
          const PosThemeSettings(
            mode: PosScreenTheme.light,
            accent: PosAccentColor.red,
            customAccentColor: Color(0xFFE4002B),
          ),
        ) {
    _hydrate();
  }

  final KeyValueStore _kv;

  static const storageModeKey = 'pos_screen_theme';
  static const storageAccentKey = 'pos_accent_color';
  static const storageCustomAccentHexKey = 'pos_custom_accent_hex';

  Future<void> _hydrate() async {
    final v = await _kv.getString(storageModeKey);
    final accentRaw = await _kv.getString(storageAccentKey);
    final customHexRaw = await _kv.getString(storageCustomAccentHexKey);
    if (isClosed) return;
    final mode = v == 'dark' ? PosScreenTheme.dark : PosScreenTheme.light;
    emit(
      PosThemeSettings(
        mode: mode,
        accent: parsePosAccentColor(accentRaw),
        customAccentColor: parseCustomAccentColor(customHexRaw),
      ),
    );
  }

  Future<void> setTheme(PosScreenTheme mode) async {
    await _kv.setString(
      storageModeKey,
      mode == PosScreenTheme.light ? 'light' : 'dark',
    );
    emit(state.copyWith(mode: mode));
  }

  Future<void> setAccent(PosAccentColor accent) async {
    await _kv.setString(storageAccentKey, accent.storageValue);
    emit(state.copyWith(accent: accent));
  }

  Future<void> setCustomAccentColor(Color color) async {
    final normalized = Color(0xFF000000 | (color.toARGB32() & 0x00FFFFFF));
    await _kv.setString(storageCustomAccentHexKey, encodeColorHex(normalized));
    await _kv.setString(storageAccentKey, PosAccentColor.custom.storageValue);
    emit(
      state.copyWith(
        accent: PosAccentColor.custom,
        customAccentColor: normalized,
      ),
    );
  }
}
