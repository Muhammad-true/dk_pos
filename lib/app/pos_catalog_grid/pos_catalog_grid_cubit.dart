import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_catalog_grid/pos_catalog_grid_settings.dart';
import 'package:dk_pos/core/storage/key_value_store.dart';

class PosCatalogGridCubit extends Cubit<PosCatalogGridSettings> {
  PosCatalogGridCubit(this._kv) : super(PosCatalogGridSettings.defaults) {
    _hydrate();
  }

  final KeyValueStore _kv;

  static const _kAuto = 'pos_catalog_grid_auto_columns';
  static const _kCols = 'pos_catalog_grid_manual_columns';
  static const _kSize = 'pos_catalog_grid_card_size';

  Future<void> _hydrate() async {
    final autoRaw = await _kv.getString(_kAuto);
    final colsRaw = await _kv.getString(_kCols);
    final sizeRaw = await _kv.getString(_kSize);
    if (isClosed) return;
    final cols = int.tryParse(colsRaw ?? '') ?? PosCatalogGridSettings.defaults.manualColumnCount;
    emit(
      PosCatalogGridSettings(
        useAutoColumns: autoRaw != '0' && autoRaw != 'false',
        manualColumnCount: cols.clamp(2, 8),
        cardSize: parsePosCatalogCardSize(sizeRaw),
      ),
    );
  }

  Future<void> setUseAutoColumns(bool value) async {
    await _kv.setString(_kAuto, value ? '1' : '0');
    emit(state.copyWith(useAutoColumns: value));
  }

  Future<void> setManualColumnCount(int value) async {
    final n = value.clamp(2, 8);
    await _kv.setString(_kCols, '$n');
    emit(state.copyWith(manualColumnCount: n));
  }

  Future<void> setCardSize(PosCatalogCardSize size) async {
    await _kv.setString(_kSize, size.storageValue);
    emit(state.copyWith(cardSize: size));
  }
}
