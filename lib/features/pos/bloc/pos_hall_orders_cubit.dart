import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
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

  /// Сразу после дозаказа — без ожидания GET; WS-патч потом уточнит детали кухни.
  void replaceOpenBillFromCart({
    required PosTableBill template,
    required CartState cart,
  }) {
    final lines = cart.sortedLines
        .map(
          (l) => PosTableBillLine(
            name: l.item.name,
            quantity: l.quantity,
            lineTotal: l.lineTotal,
            menuItemId: l.item.id,
            lineKey: l.lineKey,
            unitPrice: l.item.price,
          ),
        )
        .toList(growable: false);
    final idx = state.bills.indexWhere((b) => b.id == template.id);
    if (idx < 0) {
      emit(
        _stateWithBills([
          ...state.bills,
          PosTableBill(
            id: template.id,
            lines: lines,
            total: cart.total,
            orderTypeLabel: template.orderTypeLabel,
            orderNumber: template.orderNumber,
            tableNumber: template.tableNumber,
            tableZone: template.tableZone,
            createdAt: template.createdAt,
            orderStatus: template.orderStatus,
            tableLabel: template.tableLabel,
            customerPhone: template.customerPhone,
            isDelivery: template.isDelivery,
            createdByUsername: template.createdByUsername,
            createdByRole: template.createdByRole,
            terminalId: template.terminalId,
            isWaiterOrder: template.isWaiterOrder,
            isTakeaway: template.isTakeaway,
            isCashierOrder: template.isCashierOrder,
          ),
        ]),
      );
      return;
    }
    final prev = state.bills[idx];
    final next = List<PosTableBill>.from(state.bills);
    next[idx] = PosTableBill(
      id: prev.id,
      lines: lines,
      total: cart.total,
      orderTypeLabel: prev.orderTypeLabel,
      orderNumber: prev.orderNumber,
      tableNumber: prev.tableNumber,
      tableZone: prev.tableZone,
      createdAt: prev.createdAt,
      isPaid: prev.isPaid,
      paymentMethod: prev.paymentMethod,
      orderStatus: prev.orderStatus,
      tableLabel: prev.tableLabel,
      customerPhone: prev.customerPhone,
      isDelivery: prev.isDelivery,
      createdByUsername: prev.createdByUsername,
      createdByRole: prev.createdByRole,
      terminalId: prev.terminalId,
      isWaiterOrder: prev.isWaiterOrder,
      isTakeaway: prev.isTakeaway,
      isCashierOrder: prev.isCashierOrder,
    );
    emit(_stateWithBills(next));
  }

  /// Точечное обновление счетов из WS `cashier.board_changed` (без GET open-table-bills).
  void applyOpenBillWsPatches({
    required List<LocalOpenTableBillDto> upserts,
    required Set<String> removeIds,
  }) {
    if (upserts.isEmpty && removeIds.isEmpty) return;

    var bills = List<PosTableBill>.from(state.bills);
    for (final id in removeIds) {
      if (id.isEmpty) continue;
      bills = bills.where((b) => b.isPaid || b.id != id).toList(growable: false);
    }
    for (final dto in upserts) {
      if (dto.id.isEmpty) continue;
      if (dto.status.trim().toLowerCase() == 'cancelled') {
        bills = bills.where((b) => b.isPaid || b.id != dto.id).toList(growable: false);
        continue;
      }
      final bill = posTableBillFromServerDto(dto);
      final idx = bills.indexWhere((b) => b.id == bill.id);
      if (idx >= 0) {
        bills[idx] = bill;
      } else {
        bills.add(bill);
      }
    }
    emit(_stateWithBills(bills));
  }

  /// Подтянуть открытые счета с сервера: они перезаписывают одноимённые id;
  /// локальные неоплаченные сохраняются только если sync ещё в процессе (см. ниже).
  void mergeHydrateFromServer(List<PosTableBill> serverOpenBills) {
    final serverIds = serverOpenBills.map((e) => e.id).toSet();
    final serverTableKeys = serverOpenBills
        .where((b) => b.tableNumber != null && b.tableZone != null)
        .map((b) => b.tableZone!.occupiedKey(b.tableNumber!))
        .toSet();
    final paid = state.bills.where((b) => b.isPaid).toList();
    final droppedStale = <String>[];
    final localUnpaidOnly = state.bills.where((b) {
      if (b.isPaid || serverIds.contains(b.id)) return false;
      final age = DateTime.now().difference(b.createdAt);
      if (b.tableNumber != null && b.tableZone != null) {
        final tableKey = b.tableZone!.occupiedKey(b.tableNumber!);
        if (!serverTableKeys.contains(tableKey)) {
          // Сервер считает стол свободным — локальный счёт устарел (оплата на другой кассе).
          if (age > const Duration(seconds: 30)) {
            droppedStale.add('${b.id} table=$tableKey');
            return false;
          }
          return true;
        }
        // На столе другой счёт с сервера — локальный дубликат убираем.
        droppedStale.add('${b.id} dup-table=$tableKey');
        return false;
      }
      return age < const Duration(seconds: 30);
    }).toList();
    if (droppedStale.isNotEmpty) {
      AppFileLogger.instance.info(
        'hall_orders',
        'dropped stale local bills: ${droppedStale.join('; ')}',
      );
    }
    final next = _stateWithBills([...paid, ...serverOpenBills, ...localUnpaidOnly]);
    if (next == state) return;
    emit(next);
  }
}
