import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/admin/data/local_pos_settings_repository.dart';
export 'package:dk_pos/features/admin/data/local_pos_settings_repository.dart'
    show PosBoardLayout;

class PosBoardLayoutState {
  const PosBoardLayoutState({
    this.ordersLayout = PosBoardLayout.cards,
    this.billsLayout = PosBoardLayout.cards,
    this.loading = true,
    this.saving = false,
  });

  final PosBoardLayout ordersLayout;
  final PosBoardLayout billsLayout;
  final bool loading;
  final bool saving;

  PosBoardLayoutState copyWith({
    PosBoardLayout? ordersLayout,
    PosBoardLayout? billsLayout,
    bool? loading,
    bool? saving,
  }) {
    return PosBoardLayoutState(
      ordersLayout: ordersLayout ?? this.ordersLayout,
      billsLayout: billsLayout ?? this.billsLayout,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
    );
  }
}

/// Вид «Заказы» / «Счета» — общий для филиала; менять может и кассир.
class PosBoardLayoutCubit extends Cubit<PosBoardLayoutState> {
  PosBoardLayoutCubit(this._repo) : super(const PosBoardLayoutState()) {
    refresh();
  }

  final LocalPosSettingsRepository _repo;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true));
    try {
      final s = await _repo.fetch();
      if (isClosed) return;
      emit(
        PosBoardLayoutState(
          ordersLayout: s.ordersLayout,
          billsLayout: s.billsLayout,
          loading: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> setOrdersLayout(PosBoardLayout layout) async {
    if (state.ordersLayout == layout && !state.loading) return;
    emit(state.copyWith(ordersLayout: layout, saving: true));
    try {
      final s = await _repo.update(ordersLayout: layout);
      if (isClosed) return;
      emit(
        state.copyWith(
          ordersLayout: s.ordersLayout,
          billsLayout: s.billsLayout,
          saving: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(saving: false));
      await refresh();
    }
  }

  Future<void> setBillsLayout(PosBoardLayout layout) async {
    if (state.billsLayout == layout && !state.loading) return;
    emit(state.copyWith(billsLayout: layout, saving: true));
    try {
      final s = await _repo.update(billsLayout: layout);
      if (isClosed) return;
      emit(
        state.copyWith(
          ordersLayout: s.ordersLayout,
          billsLayout: s.billsLayout,
          saving: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(saving: false));
      await refresh();
    }
  }
}
