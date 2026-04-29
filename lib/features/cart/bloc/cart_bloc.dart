import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/cart/data/cart_repository.dart';

import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc(this._repo) : super(_snapshot(_repo)) {
    on<CartItemAdded>(_onAdd);
    on<CartItemDecremented>(_onDecrement);
    on<CartCleared>(_onClear);
    on<CartResetAll>(_onResetAll);
    on<CartCheckCreated>(_onCheckCreated);
    on<CartCheckSelected>(_onCheckSelected);
    on<CartCheckRemoved>(_onCheckRemoved);
    on<CartCheckTableLabelSet>(_onTableLabel);
    on<CartOrderTypeIndexChanged>(_onOrderType);
  }

  final CartRepository _repo;

  static CartState _snapshot(CartRepository repo) {
    return CartState(
      checks: List<CartCheckInfo>.from(repo.checkSummaries),
      activeCheckId: repo.activeCheckId,
      lines: Map<String, CartLine>.from(repo.activeLines),
      activeOrderTypeIndex: repo.activeOrderTypeIndex,
    );
  }

  void _emit(Emitter<CartState> emit) {
    emit(_snapshot(_repo));
  }

  void _onAdd(CartItemAdded event, Emitter<CartState> emit) {
    _repo.add(event.item, unitPrice: event.unitPrice);
    _emit(emit);
  }

  void _onDecrement(CartItemDecremented event, Emitter<CartState> emit) {
    _repo.decrement(event.lineKey);
    _emit(emit);
  }

  void _onClear(CartCleared event, Emitter<CartState> emit) {
    _repo.clearActive();
    _emit(emit);
  }

  void _onResetAll(CartResetAll event, Emitter<CartState> emit) {
    _repo.resetAll();
    _emit(emit);
  }

  void _onCheckCreated(CartCheckCreated event, Emitter<CartState> emit) {
    _repo.createCheck();
    _emit(emit);
  }

  void _onCheckSelected(CartCheckSelected event, Emitter<CartState> emit) {
    _repo.switchCheck(event.checkId);
    _emit(emit);
  }

  void _onCheckRemoved(CartCheckRemoved event, Emitter<CartState> emit) {
    if (_repo.removeCheck(event.checkId)) {
      _emit(emit);
    }
  }

  void _onTableLabel(CartCheckTableLabelSet event, Emitter<CartState> emit) {
    _repo.setTableLabelForActive(event.label);
    _emit(emit);
  }

  void _onOrderType(CartOrderTypeIndexChanged event, Emitter<CartState> emit) {
    _repo.setOrderTypeIndexForActive(event.index);
    _emit(emit);
  }
}
