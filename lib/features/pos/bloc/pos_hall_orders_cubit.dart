import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill_merge.dart';

class PosHallOrdersState extends Equatable {
  const PosHallOrdersState({this.bills = const []});

  final List<PosTableBill> bills;

  List<PosTableBill> get openBills {
    final list = bills.where((b) => !b.isPaid).toList();
    list.sort((a, b) {
      final ta = a.tableNumber;
      final tb = b.tableNumber;
      if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
      if (ta != null && tb == null) return -1;
      if (ta == null && tb != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  List<Object?> get props => [bills];
}

class PosHallOrdersCubit extends Cubit<PosHallOrdersState> {
  PosHallOrdersCubit() : super(const PosHallOrdersState());

  /// Неоплаченный счёт на этом столе и в этой зоне (если есть).
  PosTableBill? findOpenBillForTable({
    required int number,
    required PosTableZone zone,
  }) {
    for (final b in state.openBills) {
      if (b.tableNumber == number && b.tableZone == zone) {
        return b;
      }
    }
    return null;
  }

  /// Регистрирует счёт или **дополняет** уже открытый на том же столе (неоплаченный).
  /// Возвращает итоговый счёт (тот же id, что и у открытого, при слиянии).
  PosTableBill registerOrMergeBill(PosTableBill bill) {
    if (!bill.isPaid &&
        bill.tableNumber != null &&
        bill.tableZone != null) {
      final idx = state.bills.indexWhere(
        (b) =>
            !b.isPaid &&
            b.tableNumber == bill.tableNumber &&
            b.tableZone == bill.tableZone,
      );
      if (idx >= 0) {
        final merged = mergePosTableBills(state.bills[idx], bill);
        final next = List<PosTableBill>.from(state.bills);
        next[idx] = merged;
        emit(PosHallOrdersState(bills: next));
        return merged;
      }
    }
    emit(PosHallOrdersState(bills: [...state.bills, bill]));
    return bill;
  }

  void registerBill(PosTableBill bill) {
    registerOrMergeBill(bill);
  }

  void markPaid(String billId, {String? paymentMethod}) {
    emit(
      PosHallOrdersState(
        bills: state.bills
            .map(
              (b) => b.id == billId
                  ? b.copyWith(
                      isPaid: true,
                      paymentMethod: paymentMethod ?? b.paymentMethod,
                    )
                  : b,
            )
            .toList(),
      ),
    );
  }

  /// Подтянуть открытые счета с сервера: они перезаписывают одноимённые id;
  /// локальные неоплаченные, которых ещё нет на сервере (например сбой sync), сохраняются.
  void mergeHydrateFromServer(List<PosTableBill> serverOpenBills) {
    final serverIds = serverOpenBills.map((e) => e.id).toSet();
    final paid = state.bills.where((b) => b.isPaid).toList();
    final localUnpaidOnly = state.bills
        .where((b) => !b.isPaid && !serverIds.contains(b.id))
        .toList();
    emit(
      PosHallOrdersState(
        bills: [...paid, ...serverOpenBills, ...localUnpaidOnly],
      ),
    );
  }
}
