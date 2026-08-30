import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill_merge.dart';
import 'package:dk_pos/features/pos/presentation/utils/website_order_delivery_meta.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_checkout_flow.dart';

class PosHallOrdersState extends Equatable {
  PosHallOrdersState({
    this.bills = const [],
    this.openBillAppendDraft,
    this.openBillAppendBaselineQtyByLineKey = const {},
    this.openBillAppendKitchenQtyLockedByLineKey = const {},
    this.openBillAppendCustomerConsent = false,
    this.openBillAppendConsentMeta,
  })  : openBillsSorted = _sortedOpenBills(bills),
        tableSessionBillsSorted = _sortedTableSessionBills(bills);

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

  /// Неоплаченные счета (бейдж «Счета на оплату»).
  final List<PosTableBill> openBillsSorted;

  /// Заказы, которые держат стол (только неоплаченные со столом).
  final List<PosTableBill> tableSessionBillsSorted;

  List<PosTableBill> get openBills => openBillsSorted;

  List<PosTableBill> get tableSessionBills => tableSessionBillsSorted;

  Set<String> get occupiedTableKeys {
    final keys = <String>{};
    for (final b in tableSessionBillsSorted) {
      if (b.tableNumber != null && b.tableZone != null) {
        keys.add(b.tableZone!.occupiedKey(b.tableNumber!));
      }
    }
    return keys;
  }

  Set<String> get handedOutTableKeys {
    final keys = <String>{};
    for (final b in tableSessionBillsSorted) {
      if (!b.isHandedOutSession) continue;
      if (b.tableNumber != null && b.tableZone != null) {
        keys.add(b.tableZone!.occupiedKey(b.tableNumber!));
      }
    }
    return keys;
  }

  static List<PosTableBill> _sortedOpenBills(List<PosTableBill> bills) {
    final list = bills.where((b) => !b.isPaid).toList();
    _sortByTableThenCreated(list);
    return list;
  }

  static List<PosTableBill> _sortedTableSessionBills(List<PosTableBill> bills) {
    final list = bills.where((b) => b.occupiesTable).toList();
    _sortByTableThenCreated(list);
    return list;
  }

  static void _sortByTableThenCreated(List<PosTableBill> list) {
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

  static const _localBriefKeep = Duration(seconds: 45);

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
    for (final b in state.bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Счёт на столе (неоплаченный или оплаченная сессия), для дозаказа / занятости.
  PosTableBill? findOpenBillForTable({
    required int number,
    required PosTableZone zone,
  }) {
    for (final b in state.tableSessionBills) {
      if (b.tableNumber == number && b.tableZone == zone) {
        return b;
      }
    }
    return null;
  }

  /// Регистрирует счёт или дополняет уже открытый на том же столе (сессия).
  PosTableBill registerOrMergeBill(PosTableBill bill) {
    if (bill.tableNumber != null && bill.tableZone != null) {
      final idx = state.bills.indexWhere(
        (b) =>
            b.occupiesTable &&
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
                      orderStatus: b.orderStatus.trim().isEmpty
                          ? 'new'
                          : b.orderStatus,
                      tableSessionPhase: b.tableSessionPhase ?? 'active',
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
            modifiers: l.modifiers,
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
            total: cart.total + template.deliveryFee,
            orderTypeLabel: template.orderTypeLabel,
            orderNumber: template.orderNumber,
            tableNumber: template.tableNumber,
            tableZone: template.tableZone,
            createdAt: template.createdAt,
            isPaid: template.isPaid,
            paymentMethod: template.paymentMethod,
            orderStatus: template.orderStatus.isEmpty ? 'new' : template.orderStatus,
            tableLabel: template.tableLabel,
            customerPhone: template.customerPhone,
            isDelivery: template.isDelivery,
            createdByUsername: template.createdByUsername,
            createdByRole: template.createdByRole,
            terminalId: template.terminalId,
            isWaiterOrder: template.isWaiterOrder,
            isTakeaway: template.isTakeaway,
            isCashierOrder: template.isCashierOrder,
            deliveryFee: template.deliveryFee,
            tableSessionPhase: template.tableSessionPhase ?? 'active',
            tableSessionGraceMinutes: template.tableSessionGraceMinutes,
          ),
        ]),
      );
      return;
    }
    final prev = state.bills[idx];
    final next = List<PosTableBill>.from(state.bills);
    final linesTotal = cart.total;
    final discount = prev.discountAmount;
    final payable = discount > 0.009
        ? (linesTotal - discount).clamp(0.0, double.infinity)
        : linesTotal;
    next[idx] = PosTableBill(
      id: prev.id,
      lines: lines,
      total: payable + prev.deliveryFee,
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
      isOnlineOrder: prev.isOnlineOrder,
      subtotal: linesTotal,
      discountAmount: discount,
      deliveryFee: prev.deliveryFee,
      handedOutAt: prev.handedOutAt,
      tableSessionPhase: prev.tableSessionPhase,
      tableSessionEndsAt: prev.tableSessionEndsAt,
      tableSessionGraceMinutes: prev.tableSessionGraceMinutes,
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
      bills = bills.where((b) => b.id != id).toList(growable: false);
    }
    for (final dto in upserts) {
      if (dto.id.isEmpty) continue;
      if (dto.status.trim().toLowerCase() == 'cancelled') {
        bills = bills.where((b) => b.id != dto.id).toList(growable: false);
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

  /// Полный список после применения патчей (без повторного merge «оплаченных навсегда»).
  void replaceBillsFromPatchedList(List<PosTableBill> bills) {
    emit(_stateWithBills(bills));
  }

  /// Локально обновить стол счёта (после PATCH table; WS уточнит).
  void updateBillTable({
    required String orderId,
    required String tableLabel,
    int? tableNumber,
    PosTableZone? tableZone,
    String? orderTypeLabel,
  }) {
    final idx = state.bills.indexWhere((b) => b.id == orderId);
    if (idx < 0) return;
    final prev = state.bills[idx];
    final next = List<PosTableBill>.from(state.bills);
    final clear = tableLabel.trim().isEmpty;
    if (clear && prev.isPaid) {
      // Освободили стол у оплаченного — локально убираем из сессии.
      next.removeAt(idx);
    } else {
      final resolvedType = orderTypeLabel?.trim().isNotEmpty == true
          ? orderTypeLabel!.trim()
          : (clear
              ? (prev.orderTypeLabel.trim().isEmpty
                  ? 'На месте'
                  : prev.orderTypeLabel)
              : (prev.isTakeaway ? 'На месте' : prev.orderTypeLabel));
      next[idx] = prev.copyWith(
        clearTable: clear,
        tableLabel: clear ? '' : tableLabel,
        tableNumber: clear ? null : tableNumber,
        tableZone: clear ? null : tableZone,
        orderTypeLabel: resolvedType,
      );
    }
    emit(_stateWithBills(next));
  }

  /// Локально обновить тип заказа (после PATCH order-type; WS уточнит).
  void updateBillOrderType({
    required String orderId,
    required String orderTypeLabel,
    String tableLabel = '',
    int? tableNumber,
    PosTableZone? tableZone,
    bool clearTable = false,
  }) {
    final idx = state.bills.indexWhere((b) => b.id == orderId);
    if (idx < 0) return;
    final prev = state.bills[idx];
    final next = List<PosTableBill>.from(state.bills);
    if (clearTable && prev.isPaid && tableLabel.trim().isEmpty) {
      next.removeAt(idx);
    } else {
      next[idx] = prev.copyWith(
        orderTypeLabel: orderTypeLabel,
        clearTable: clearTable,
        tableLabel: clearTable
            ? ''
            : (tableLabel.trim().isNotEmpty ? tableLabel : prev.tableLabel),
        tableNumber: clearTable ? null : (tableNumber ?? prev.tableNumber),
        tableZone: clearTable ? null : (tableZone ?? prev.tableZone),
      );
    }
    emit(_stateWithBills(next));
  }

  /// Убрать локально оплаченные счета без занятости и сессии с истёкшим grace.
  void pruneExpiredTableSessions({DateTime? now}) {
    final t = now ?? DateTime.now();
    final before = state.bills.length;
    final next = state.bills.where((b) {
      if (!b.isPaid) return true;
      // Оплаченный больше не держит стол — не копим в локальном списке.
      if (!b.occupiesTable) return false;
      if (!b.hasTableAssignment) return false;
      final st = b.orderStatus.trim().toLowerCase();
      if (_activeTableStatuses.contains(st) || st.isEmpty) return true;
      if (st != 'done' &&
          (b.tableSessionPhase ?? '').toLowerCase() != 'handed_out') {
        return b.occupiesTable;
      }
      final ends = b.tableSessionEndsAt;
      if (ends != null) return t.isBefore(ends);
      final ho = b.handedOutAt;
      if (ho == null) return false;
      final grace = b.tableSessionGraceMinutes ?? 8;
      return t.isBefore(ho.add(Duration(minutes: grace)));
    }).toList(growable: false);
    if (next.length == before) return;
    emit(_stateWithBills(next));
  }

  /// Подтянуть счета с сервера: список сервера — источник правды;
  /// локальные id без сервера держим кратко (optimistic), не копим оплаченные вечно.
  void mergeHydrateFromServer(List<PosTableBill> serverOpenBills) {
    final serverIds = serverOpenBills.map((e) => e.id).toSet();
    final serverTableKeys = serverOpenBills
        .where((b) => b.tableNumber != null && b.tableZone != null)
        .map((b) => b.tableZone!.occupiedKey(b.tableNumber!))
        .toSet();
    final droppedStale = <String>[];
    final localKeep = state.bills.where((b) {
      if (serverIds.contains(b.id)) return false;
      final age = DateTime.now().difference(b.createdAt);
      if (age > _localBriefKeep) {
        droppedStale.add('${b.id} age=${age.inSeconds}s');
        return false;
      }
      if (b.tableNumber != null && b.tableZone != null) {
        final tableKey = b.tableZone!.occupiedKey(b.tableNumber!);
        if (serverTableKeys.contains(tableKey)) {
          droppedStale.add('${b.id} dup-table=$tableKey');
          return false;
        }
      }
      return true;
    }).toList();
    if (droppedStale.isNotEmpty) {
      AppFileLogger.instance.info(
        'hall_orders',
        'dropped stale local bills: ${droppedStale.join('; ')}',
      );
    }
    final next = _stateWithBills([...serverOpenBills, ...localKeep]);
    if (next == state) return;
    applyBillPromosFromOpenBills(serverOpenBills);
    emit(next);
  }
}

const _activeTableStatuses = {
  'new',
  'cooking',
  'awaiting_expeditor',
  'ready',
};
