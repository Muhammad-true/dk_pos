import 'package:equatable/equatable.dart';

import 'package:dk_pos/shared/shared.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

final class CartItemAdded extends CartEvent {
  const CartItemAdded(this.item, {this.unitPrice});

  final PosMenuItem item;
  final double? unitPrice;

  @override
  List<Object?> get props => [item.id, unitPrice];
}

final class CartItemDecremented extends CartEvent {
  const CartItemDecremented(this.lineKey);

  final String lineKey;

  @override
  List<Object?> get props => [lineKey];
}

/// Очистить позиции **текущего** чека (как «обнулить заказ» на вкладке).
final class CartCleared extends CartEvent {
  const CartCleared();
}

/// Сбросить все чеки и оставить один пустой (выход кассира и т.п.).
final class CartResetAll extends CartEvent {
  const CartResetAll();
}

/// Новый пустой чек и переключение на него.
final class CartCheckCreated extends CartEvent {
  const CartCheckCreated();
}

final class CartCheckSelected extends CartEvent {
  const CartCheckSelected(this.checkId);

  final String checkId;

  @override
  List<Object?> get props => [checkId];
}

final class CartCheckRemoved extends CartEvent {
  const CartCheckRemoved(this.checkId);

  final String checkId;

  @override
  List<Object?> get props => [checkId];
}

final class CartCheckTableLabelSet extends CartEvent {
  const CartCheckTableLabelSet(this.label);

  final String? label;

  @override
  List<Object?> get props => [label];
}

final class CartOrderTypeIndexChanged extends CartEvent {
  const CartOrderTypeIndexChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}
