import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/storage/key_value_store.dart';

/// Тема экрана кассы (POS): светлая / тёмная. Хранится в SharedPreferences.
enum PosScreenTheme { light, dark }

class PosThemeCubit extends Cubit<PosScreenTheme> {
  PosThemeCubit(this._kv) : super(PosScreenTheme.light) {
    _hydrate();
  }

  final KeyValueStore _kv;

  static const storageKey = 'pos_screen_theme';

  Future<void> _hydrate() async {
    final v = await _kv.getString(storageKey);
    if (isClosed) return;
    if (v == 'light') {
      emit(PosScreenTheme.light);
    } else if (v == 'dark') {
      emit(PosScreenTheme.dark);
    }
  }

  Future<void> setTheme(PosScreenTheme mode) async {
    await _kv.setString(
      storageKey,
      mode == PosScreenTheme.light ? 'light' : 'dark',
    );
    emit(mode);
  }
}
