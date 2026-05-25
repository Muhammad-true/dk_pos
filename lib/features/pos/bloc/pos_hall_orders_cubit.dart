import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill_merge.dart';
import 'package:dk_pos/features/pos/presentation/utils/website_order_delivery_meta.dart';

class PosHallOrdersState extends Equatable {
  PosHallOrdersState({
    this.bills = const [],
    this.openBillAppendDraft,
    this.openBillAppendBaselineQtyByLineKey = const {},
    this.openBillAppendKitchenQtyLockedByLineKey = const {},
    this.openBillAppendCustomerConsent = false,
    this.openBillAppendConsentMeta,
  }) : openBillsSorted = _sortedOpenBills(bills);

  final List<PosTableBill> bills;

  /// Режим «добавить позиции к счёту из списка оплат».
  final PosTableBill? openBillAppendDraft;

  /// Количества строк счёта после подгрузки в корзину — на сервер уходит только приращение.
  final Map<String, int> openBillAppendBaselineQtyByLineKey;

  /// Строки кухни уже «готово» — нельзя менять количество в корзине до снятия блокировки.
  final Map<String, bool> openBillAppendKitchenQtyLockedByLineKey;

  /// Изменение онлайн-заказа после согласия с клиентом — предложить печать чека.
  final bool openBillAppendCustomerConsent;

  final WebsiteOrderDeliveryMeta? openBillAppendConsentMeta;

  /// Неоплаченные счета в закреплённом порядке (пересчитывается только при смене [bills]).
  final List<PosTableBill> openBillsSorted;

  List<PosTableBill> get openBills => openBillsSorted;

  static List<PosTableBill> _sortedOpenBills(List<PosTableBill> bills) {
    final list = bills.where((b) => !b.isPaid).toList();
    list.sort((a, b) {
      final za = a.tableZone;
      final zb = b.tableZone;
      if (za != null && zb != null && za != zb) {
        if (za == PosTableZone.hall && zb == PosTableZone.veranda) return -1;
        if (za == PosTableZone.veranda && zb == PosTableZone.hall) return 1;
      }
      if (za != null && zb == null) return -1;
      if (za == null && zb != null) return 1;
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
  List<Object?> get props => [
        bills,
        openBillAppendDraft,
        openBillAppendBaselineQtyByLineKey,
        openBillAppendKitchenQtyLockedByLineKey,
        openBillAppendCustomerConsent,
        openBillAppendConsentMeta,
      ];
}

class PosHallOrdersCubit extends Cubit<PosHallOrdersState> {
  PosHallOrdersCubit() : super(PosHallOrdersState());

  void startOpenBillAppend(
    PosTableBill bill, {
    Map<String, int> baselineQtyByLineKey = const {},
    Map<String, bool> kitchenQtyLockedByLineKey = const {},
    bool customerConsentEdit = false,
    WebsiteOrderDeliveryMeta? consentReceiptMeta,
  }) {
    emit(
      PosHallOrdersState(
        bills: state.bills,
        openBillAppendDraft: bill,
        openBillAppendBaselineQtyByLineKey: baselineQtyByLineKey,
        openBillAppendKitchenQtyLockedByLineKey: kitchenQtyLockedByLineKey,
        openBillAppendCustomerConsent: customerConsentEdit,
        openBillAppendConsentMeta: consentReceiptMeta,
      ),
    );
  }

  void clearOpenBillAppend() {
    if (state.openBillAppendDraft == null &&
        state.openBillAppendBaselineQtyByLineKey.isEmpty &&
        state.openBillAppendKitchenQtyLockedByLineKey.isEmpty &&
        !state.openBillAppendCustomerConsent) {
      return;
    }
    emit(PosHallOrdersState(bills: state.bills));
  }

  PosTableBill? findOpenBillByOrderId(String orderId) {
    final id = orderId.trim();
    if (id.isEmpty) return null;
    for (final b in state.openBills) {
      if (b.id == id) return b;
    }
    return null;
  }

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
        emit(_stateWithBills(next));
        return merged;
      }
    }
    emit(_stateWithBills([...state.bills, bill]));
    return bill;
  }

  PosHallOrdersState _stateWithBills(List<PosTableBill> bills) {
    return PosHallOrdersState(
      bills: bills,
      openBillAppendDraft: state.openBillAppendDraft,
      openBillAppendBaselineQtyByLineKey: state.openBillAppendBaselineQtyByLineKey,
      openBillAppendKitchenQtyLockedByLineKey:
          state.openBillAppendKitchenQtyLockedByLineKey,
      openBillAppendCustomerConsent: state.openBillAppendCustomerConsent,
      openBillAppendConsentMeta: state.openBillAppendConsentMeta,
    );
  }

  void registerBill(PosTableBill bill) {
    registerOrMergeBill(bill);
  }

  void markPaid(String billId, {String? paymentMethod}) {
    emit(
      _stateWithBills(
        state.bills
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
      _stateWithBills([...paid, ...serverOpenBills, ...localUnpaidOnly]),
    );
  }
}
