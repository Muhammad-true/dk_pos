import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_settings.dart';
import 'package:dk_pos/core/storage/key_value_store.dart';

class PosCashierBoardCubit extends Cubit<PosCashierBoardSettings> {
  PosCashierBoardCubit(this._kv) : super(PosCashierBoardSettings.defaults) {
    _hydrate();
  }

  final KeyValueStore _kv;

  static const _kDensity = 'pos_cashier_board_density_v1';
  static const _kTableHeadline = 'pos_cashier_board_table_headline_v1';
  static const _kTitle = 'pos_cashier_board_title_v1';
  static const _kItemText = 'pos_cashier_board_item_text_v1';
  static const _kShowTableOnTop = 'pos_cashier_board_show_table_top_v1';

  Future<void> _hydrate() async {
    final densityRaw = await _kv.getString(_kDensity);
    final tableHeadline = _parseDouble(await _kv.getString(_kTableHeadline));
    final title = _parseDouble(await _kv.getString(_kTitle));
    final itemText = _parseDouble(await _kv.getString(_kItemText));
    final showTopRaw = await _kv.getString(_kShowTableOnTop);
    if (isClosed) return;
    emit(
      PosCashierBoardSettings(
        density: parsePosCashierCardDensity(densityRaw),
        tableHeadlineScale: tableHeadline ??
            PosCashierBoardSettings.defaults.tableHeadlineScale,
        titleScale: title ?? PosCashierBoardSettings.defaults.titleScale,
        itemTextScale:
            itemText ?? PosCashierBoardSettings.defaults.itemTextScale,
        showTableOnTop: showTopRaw == null
            ? PosCashierBoardSettings.defaults.showTableOnTop
            : showTopRaw != '0' && showTopRaw != 'false',
      ).clamped(),
    );
  }

  double? _parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.trim());
  }

  Future<void> applyPreset(PosCashierBoardSettings preset) async {
    await save(preset);
  }

  Future<void> save(PosCashierBoardSettings next) async {
    final s = next.clamped();
    await _kv.setString(_kDensity, s.density.storageValue);
    await _kv.setString(_kTableHeadline, s.tableHeadlineScale.toString());
    await _kv.setString(_kTitle, s.titleScale.toString());
    await _kv.setString(_kItemText, s.itemTextScale.toString());
    await _kv.setString(_kShowTableOnTop, s.showTableOnTop ? '1' : '0');
    emit(s);
  }

  Future<void> setDensity(PosCashierCardDensity density) async {
    await save(state.copyWith(density: density));
  }

  Future<void> setTableHeadlineScale(double value) async {
    await save(state.copyWith(tableHeadlineScale: value));
  }

  Future<void> setTitleScale(double value) async {
    await save(state.copyWith(titleScale: value));
  }

  Future<void> setItemTextScale(double value) async {
    await save(state.copyWith(itemTextScale: value));
  }

  Future<void> setShowTableOnTop(bool value) async {
    await save(state.copyWith(showTableOnTop: value));
  }
}
