import 'package:dk_pos/core/constants/phone_defaults.dart';
import 'package:flutter/services.dart';

/// Всегда оставляет префикс [kDefaultPhoneDialPrefix]; его нельзя стереть.
/// После префикса — только цифры, не более 9 (национальная часть).
class TjPhoneDialLockedFormatter extends TextInputFormatter {
  const TjPhoneDialLockedFormatter();

  static String nationalDigitsFromAny(String raw) {
    final s = raw.trim();
    const p = kDefaultPhoneDialPrefix;
    if (s.startsWith(p)) {
      return s.substring(p.length).replaceAll(RegExp(r'[^0-9]'), '');
    }
    final digitsOnly = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('992')) {
      return digitsOnly.substring(3);
    }
    return digitsOnly;
  }

  /// Нормализует сохранённое значение к виду +992 + до 9 цифр.
  static String ensureStored(String? stored) {
    const p = kDefaultPhoneDialPrefix;
    var national = nationalDigitsFromAny(stored ?? '');
    if (national.length > 9) {
      national = national.substring(0, 9);
    }
    return p + national;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    const p = kDefaultPhoneDialPrefix;
    var national = nationalDigitsFromAny(newValue.text);
    if (national.length > 9) {
      national = national.substring(0, 9);
    }
    final out = p + national;

    var offset = newValue.selection.baseOffset;
    if (offset < p.length) {
      offset = p.length;
    }
    if (offset > out.length) {
      offset = out.length;
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: offset.clamp(p.length, out.length)),
      composing: TextRange.empty,
    );
  }
}
