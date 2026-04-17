import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/storage/key_value_store.dart';

import 'locale_event.dart';
import 'locale_state.dart';

const _kLocaleCode = 'app_locale_code';
const _fallback = Locale('ru');

class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  LocaleBloc(this._kv) : super(const LocaleState(_fallback)) {
    on<LocaleStarted>(_onStarted);
    on<LocaleChanged>(_onChanged);
  }

  final KeyValueStore _kv;

  Future<void> _onStarted(
    LocaleStarted event,
    Emitter<LocaleState> emit,
  ) async {
    final code = await _kv.getString(_kLocaleCode);
    if (code != null && code.isNotEmpty) {
      emit(LocaleState(Locale(code)));
    }
  }

  Future<void> _onChanged(
    LocaleChanged event,
    Emitter<LocaleState> emit,
  ) async {
    await _kv.setString(_kLocaleCode, event.locale.languageCode);
    emit(LocaleState(event.locale));
  }
}
