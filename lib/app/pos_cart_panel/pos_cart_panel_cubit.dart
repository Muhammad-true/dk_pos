import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_cart_panel/pos_cart_panel_settings.dart';
import 'package:dk_pos/core/storage/key_value_store.dart';

class PosCartPanelCubit extends Cubit<PosCartPanelSettings> {
  PosCartPanelCubit(this._kv) : super(PosCartPanelSettings.defaults) {
    _hydrate();
  }

  final KeyValueStore _kv;

  static const _kLineSize = 'pos_cart_panel_line_size';
  static const _kFooterSize = 'pos_cart_panel_footer_size';

  Future<void> _hydrate() async {
    final lineRaw = await _kv.getString(_kLineSize);
    final footerRaw = await _kv.getString(_kFooterSize);
    if (isClosed) return;
    emit(
      PosCartPanelSettings(
        lineSize: parsePosCartLineSize(lineRaw),
        footerSize: parsePosCartFooterSize(footerRaw),
      ),
    );
  }

  Future<void> setLineSize(PosCartLineSize size) async {
    await _kv.setString(_kLineSize, size.storageValue);
    emit(state.copyWith(lineSize: size));
  }

  Future<void> setFooterSize(PosCartFooterSize size) async {
    await _kv.setString(_kFooterSize, size.storageValue);
    emit(state.copyWith(footerSize: size));
  }
}
