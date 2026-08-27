import 'dart:async';
import 'dart:math' as math;

import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:dk_pos/app/pos_board_layout/pos_board_layout_cubit.dart';
import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_cubit.dart';
import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_settings.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';
import 'package:dk_pos/features/pos/presentation/utils/cashier_table_headline.dart';
import 'package:dk_pos/features/pos/presentation/utils/pos_catalog_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'open_table_bill_cart_hydrate.dart';
import 'pos_bill_channel_chips.dart';
import 'pos_bill_line_remove_reason_dialog.dart';
import 'pos_bill_visual_style.dart';
import 'pos_change_order_table.dart';
import 'pos_change_order_type.dart';
import 'pos_checkout_flow.dart';
import 'pos_order_history_dialog.dart';

double _openBillsDialogWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (WindowLayout(width: w).isCompact) return w - 8;
  final cols = WindowLayout(width: w).cardGridColumns(minCellWidth: 220);
  if (cols >= 2) return math.min(1120, w * 0.96);
  return math.min(760, w * 0.98);
}

double _openBillsDialogHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  if (WindowLayout(width: MediaQuery.sizeOf(context).width).isCompact) {
    return h * 0.92;
  }
  return math.min(660, h * 0.88);
}

double _billDetailDialogWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (WindowLayout(width: w).isCompact) return w - 8;
  return math.min(680, w * 0.96);
}

double _billDetailDialogHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  // Запас под Wrap второстепенных + ряд «Дозаказ / Оплатить».
  const actionsReserve = 140.0;
  if (WindowLayout(width: MediaQuery.sizeOf(context).width).isCompact) {
    return math.max(280, h * 0.78 - actionsReserve);
  }
  return math.min(520, h * 0.68);
}

EdgeInsets _billsDialogInsetPadding(BuildContext context) {
  if (WindowLayout.of(context).isCompact) {
    return const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  }
  return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
}

/// [posHostContext] — контекст под деревом [PosScreen] (есть [MenuBloc], [CartBloc]).
/// Не использовать контекст самого диалога после `pop`: он становится unmounted.
Future<void> showOpenTableBillsDialog(BuildContext posHostContext) {
  final cubit = posHostContext.read<PosHallOrdersCubit>();
  return showDialog<void>(
    context: posHostContext,
    useRootNavigator: true,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: cubit,
        child: _OpenBillsDialog(posHostContext: posHostContext),
      );
    },
  );
}

class _OpenBillsDialog extends StatelessWidget {
  const _OpenBillsDialog({required this.posHostContext});

  final BuildContext posHostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, state) {
        final open = state.openBills;

        return AlertDialog(
          insetPadding: _billsDialogInsetPadding(context),
          backgroundColor: scheme.surfaceContainerLow,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Счета на оплату',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Все неоплаченные заказы филиала: стол, «с собой», доставка, онлайн после «Принять». '
                'Новые сайт-заказы сначала во входящих — без дубля в списке счетов. Данные с сервера.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: _openBillsDialogWidth(context),
            height: _openBillsDialogHeight(context),
            child: open.isEmpty
                ? Center(
                    child: Text(
                      'Нет неоплаченных счетов по этому филиалу.\n'
                      'После оформления заказа с оплатой «позже» он появится здесь.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : BlocBuilder<PosBoardLayoutCubit, PosBoardLayoutState>(
                    buildWhen: (p, c) => p.billsLayout != c.billsLayout,
                    builder: (context, layoutState) {
                      return BlocBuilder<PosCashierBoardCubit,
                          PosCashierBoardSettings>(
                        builder: (context, cardUi) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              Widget billTile(PosTableBill bill,
                                  {required bool compact}) {
                                return _BillListTile(
                                  bill: bill,
                                  compact: compact,
                                  onOpen: () => _showBillDetail(
                                    posHostContext,
                                    bill,
                                  ),
                                  onChangeTable: bill.isDelivery
                                      ? null
                                      : () => changePosOrderTable(
                                          posHostContext,
                                          orderId: bill.id,
                                          currentTableLabel: bill.tableLabel,
                                          currentTableNumber: bill.tableNumber,
                                          currentTableZone: bill.tableZone,
                                          orderType: bill.orderTypeLabel,
                                        ),
                                );
                              }

                              ListView listView() => ListView.separated(
                                    itemCount: open.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (_, i) =>
                                        billTile(open[i], compact: false),
                                  );

                              if (layoutState.billsLayout !=
                                  PosBoardLayout.cards) {
                                return listView();
                              }

                              final maxW = constraints.maxWidth;
                              if (!maxW.isFinite || maxW < 80) {
                                return listView();
                              }

                              final autoCols = WindowLayout(width: maxW)
                                  .cardGridColumns(minCellWidth: 240);
                              if (autoCols <= 1) return listView();

                              const spacing = 10.0;
                              final aspect = cardUi.billsGridAspectRatio(
                                columns: autoCols,
                              );
                              final cellW =
                                  (maxW - spacing * (autoCols - 1)) / autoCols;
                              final cellH = cellW / aspect;
                              // Слишком низкая ячейка при крупном шрифте —
                              // список надёжнее, чем «пустые» обрезанные карточки.
                              if (!cellW.isFinite ||
                                  !cellH.isFinite ||
                                  cellW < 150 ||
                                  cellH < 118) {
                                return listView();
                              }

                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: autoCols,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                  childAspectRatio: aspect,
                                ),
                                itemCount: open.length,
                                itemBuilder: (_, i) =>
                                    billTile(open[i], compact: true),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}

String _kitchenLineStatusLabel(PosTableBillLine line) {
  final st = (line.kitchenLineStatus ?? 'pending').toLowerCase().trim();
  return switch (st) {
    'accepted' => 'Кухня: принято',
    'ready' => 'Кухня: готово',
    'pending' => 'Кухня: ожидает',
    _ => 'Кухня: $st',
  };
}

Future<void> _refreshOpenBillsHall(BuildContext posHostContext) async {
  try {
    final repo = posHostContext.read<LocalOrdersRepository>();
    final dtos = await repo.fetchOpenTableBills(
      branchId: AppConfig.storeBranchId,
    );
    if (!posHostContext.mounted) return;
    final bills = dtos.map(posTableBillFromServerDto).toList();
    posHostContext.read<PosHallOrdersCubit>().mergeHydrateFromServer(bills);
    applyBillPromosFromOpenBills(bills);
  } catch (e, st) {
    AppFileLogger.instance.error('hall_orders', 'dialog refresh failed', e, st);
  }
}

class _BillDetailDialog extends StatefulWidget {
  const _BillDetailDialog({
    required this.posHostContext,
    required this.initialBill,
    required this.canProcessPayments,
  });

  final BuildContext posHostContext;
  final PosTableBill initialBill;
  final bool canProcessPayments;

  @override
  State<_BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends State<_BillDetailDialog> {
  late PosTableBill _bill;
  bool _busy = false;
  bool _restoredCustomerDisplayMenu = false;
  final ScrollController _linesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bill = widget.initialBill;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(syncOpenBillToCustomerDisplay(widget.posHostContext, _bill));
    });
  }

  @override
  void dispose() {
    if (!_restoredCustomerDisplayMenu && widget.posHostContext.mounted) {
      restoreCustomerDisplayMenuFromContext(widget.posHostContext);
    }
    _linesScrollController.dispose();
    super.dispose();
  }

  void _markCustomerDisplayReturnedToMenu() {
    _restoredCustomerDisplayMenu = true;
  }

  Future<void> _syncBillOnCustomerDisplay() async {
    if (!mounted) return;
    await syncOpenBillToCustomerDisplay(widget.posHostContext, _bill);
  }

  Future<void> _changeTable() async {
    setState(() => _busy = true);
    try {
      // Контекст детали счёта — overlay без Bloc'ов PosScreen.
      // Выбор стола и PATCH нуждаются в posHostContext.
      final host = widget.posHostContext;
      if (!host.mounted) return;
      final result = await changePosOrderTable(
        host,
        orderId: _bill.id,
        currentTableLabel: _bill.tableLabel,
        currentTableNumber: _bill.tableNumber,
        currentTableZone: _bill.tableZone,
        orderType: _bill.orderTypeLabel,
      );
      if (!mounted || result == null) return;
      setState(() {
        _bill = _bill.copyWith(
          clearTable: result.cleared,
          tableLabel: result.tableLabel,
          tableNumber: result.tableNumber,
          tableZone: result.tableZone,
          orderTypeLabel: result.orderTypeLabel ?? 'На месте',
        );
      });
      unawaited(_syncBillOnCustomerDisplay());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeOrderType() async {
    setState(() => _busy = true);
    try {
      final host = widget.posHostContext;
      if (!host.mounted) return;
      final result = await changePosOrderType(
        host,
        orderId: _bill.id,
        currentOrderType: _bill.orderTypeLabel,
        currentTableLabel: _bill.tableLabel,
      );
      if (!mounted || result == null) return;
      setState(() {
        _bill = _bill.copyWith(
          orderTypeLabel: result.orderTypeLabel,
          clearTable: result.tableCleared,
          tableLabel: result.tableLabel,
          tableNumber: result.tableNumber,
          tableZone: result.tableZone,
        );
      });
      unawaited(_syncBillOnCustomerDisplay());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _freeTable() async {
    setState(() => _busy = true);
    try {
      final host = widget.posHostContext;
      if (!host.mounted) return;
      final result = await clearPosOrderTable(host, orderId: _bill.id);
      if (!mounted || result == null) return;
      setState(() {
        _bill = _bill.copyWith(clearTable: true, orderTypeLabel: 'На месте');
      });
      unawaited(_syncBillOnCustomerDisplay());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnCustomerDisplayToMenuWithCart() async {
    final host = widget.posHostContext;
    if (!host.mounted) return;
    _markCustomerDisplayReturnedToMenu();
    final customerDisplay = CustomerDisplayWindowService.instance;
    if (!customerDisplay.isOpen) return;
    await customerDisplay.returnToMenuMode(
      menu: host.read<MenuBloc>().state,
      cart: host.read<CartBloc>().state,
    );
    scheduleCustomerDisplayCartSync(host);
  }

  Future<void> _onOrderCancelledEmpty(String orderNumber) async {
    final host = widget.posHostContext;
    final hall = host.read<PosHallOrdersCubit>();
    if (hall.state.openBillAppendDraft?.id == _bill.id) {
      hall.clearOpenBillAppend();
    }
    await _refreshOpenBillsHall(host);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!host.mounted) return;
    final label = orderNumber.trim().isNotEmpty ? '№$orderNumber' : '';
    ScaffoldMessenger.of(host).showSnackBar(
      SnackBar(
        content: Text(
          label.isEmpty
              ? 'Заказ отменён — позиций не осталось'
              : 'Заказ $label отменён — позиций не осталось',
        ),
      ),
    );
  }

  int _lineIndexOf(PosTableBillLine line) {
    final mid = line.menuItemId?.trim() ?? '';
    for (var i = 0; i < _bill.lines.length; i++) {
      final l = _bill.lines[i];
      if (mid.isNotEmpty && l.menuItemId?.trim() == mid) return i;
    }
    return _bill.lines.indexOf(line);
  }

  void _applyLineQuantityAt(int index, int newQty) {
    if (index < 0 || index >= _bill.lines.length) return;
    clearOrderPaymentAdjustment(_bill.id);
    final l = _bill.lines[index];
    if (newQty <= 0) {
      _removeLineAt(index);
      return;
    }
    final unit =
        l.unitPrice ??
        (l.quantity > 0 ? l.lineTotal / l.quantity : l.lineTotal);
    final nl = List<PosTableBillLine>.from(_bill.lines);
    nl[index] = PosTableBillLine(
      name: l.name,
      quantity: newQty,
      lineTotal: unit * newQty,
      menuItemId: l.menuItemId,
      lineKey: l.lineKey,
      unitPrice: unit,
      kitchenLineStatus: l.kitchenLineStatus,
      kitchenStationId: l.kitchenStationId,
      modifiers: l.modifiers,
    );
    final nt = nl.fold<double>(0, (s, e) => s + e.lineTotal);
    final payable = _bill.hasPromoDiscount
        ? (nt - _bill.promoDiscountAmount).clamp(0.0, double.infinity)
        : nt;
    setState(() {
      _bill = PosTableBill(
        id: _bill.id,
        lines: nl,
        total: payable,
        subtotal: nt,
        orderTypeLabel: _bill.orderTypeLabel,
        orderNumber: _bill.orderNumber,
        tableNumber: _bill.tableNumber,
        tableZone: _bill.tableZone,
        createdAt: _bill.createdAt,
        isPaid: _bill.isPaid,
        paymentMethod: _bill.paymentMethod,
        orderStatus: _bill.orderStatus,
        tableLabel: _bill.tableLabel,
        customerPhone: _bill.customerPhone,
        isDelivery: _bill.isDelivery,
        createdByUsername: _bill.createdByUsername,
        createdByRole: _bill.createdByRole,
        terminalId: _bill.terminalId,
        isWaiterOrder: _bill.isWaiterOrder,
        isTakeaway: _bill.isTakeaway,
        isCashierOrder: _bill.isCashierOrder,
        isOnlineOrder: _bill.isOnlineOrder,
        discountAmount: _bill.discountAmount,
        deliveryCourier: _bill.deliveryCourier,
        deliveryMethod: _bill.deliveryMethod,
        deliveryZone: _bill.deliveryZone,
        dto: _bill.dto,
      );
    });
    unawaited(_syncBillOnCustomerDisplay());
  }

  void _removeLineAt(int index) {
    clearOrderPaymentAdjustment(_bill.id);
    final nl = List<PosTableBillLine>.from(_bill.lines)..removeAt(index);
    final nt = nl.fold<double>(0, (s, e) => s + e.lineTotal);
    final payable = _bill.hasPromoDiscount
        ? (nt - _bill.promoDiscountAmount).clamp(0.0, double.infinity)
        : nt;
    setState(() {
      _bill = PosTableBill(
        id: _bill.id,
        lines: nl,
        total: payable,
        subtotal: nt,
        orderTypeLabel: _bill.orderTypeLabel,
        orderNumber: _bill.orderNumber,
        tableNumber: _bill.tableNumber,
        tableZone: _bill.tableZone,
        createdAt: _bill.createdAt,
        isPaid: _bill.isPaid,
        paymentMethod: _bill.paymentMethod,
        orderStatus: _bill.orderStatus,
        tableLabel: _bill.tableLabel,
        customerPhone: _bill.customerPhone,
        isDelivery: _bill.isDelivery,
        createdByUsername: _bill.createdByUsername,
        createdByRole: _bill.createdByRole,
        terminalId: _bill.terminalId,
        isWaiterOrder: _bill.isWaiterOrder,
        isTakeaway: _bill.isTakeaway,
        isCashierOrder: _bill.isCashierOrder,
        isOnlineOrder: _bill.isOnlineOrder,
        discountAmount: _bill.discountAmount,
        deliveryCourier: _bill.deliveryCourier,
        deliveryMethod: _bill.deliveryMethod,
        deliveryZone: _bill.deliveryZone,
        dto: _bill.dto,
      );
    });
    unawaited(_syncBillOnCustomerDisplay());
  }

  Future<bool> _confirmSwipeRemoveLine(PosTableBillLine line) async {
    final mid = line.menuItemId?.trim() ?? '';
    if (mid.isEmpty) return false;
    if (_busy) return false;
    final index = _lineIndexOf(line);
    if (index < 0) return false;
    final newQty = line.quantity > 1 ? line.quantity - 1 : 0;

    String? reason;
    if (line.needsRemovalReason) {
      reason = await pickBillLineRemoveReason(context);
      if (!mounted || reason == null) return false;
    }

    setState(() => _busy = true);
    try {
      final lineKey = line.lineKey?.trim();
      final result = await widget.posHostContext
          .read<LocalOrdersRepository>()
          .patchOrderLineQuantity(
            orderId: _bill.id,
            menuItemId: mid,
            lineKey: lineKey != null && lineKey.isNotEmpty ? lineKey : null,
            quantity: newQty,
            reason: reason,
          );
      if (result.orderCancelledEmpty) {
        await _onOrderCancelledEmpty(result.number);
        return false;
      }
      if (newQty > 0) {
        _applyLineQuantityAt(index, newQty);
        unawaited(_refreshOpenBillsHall(widget.posHostContext));
        return false;
      }
      return true;
    } on ApiException catch (e) {
      if (widget.posHostContext.mounted) {
        ScaffoldMessenger.of(
          widget.posHostContext,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (e) {
      if (widget.posHostContext.mounted) {
        ScaffoldMessenger.of(
          widget.posHostContext,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDismissedLineAt(int index) {
    _removeLineAt(index);
    unawaited(_refreshOpenBillsHall(widget.posHostContext));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = posBillVisualStyle(_bill, scheme);

    final hasPaymentDiscount =
        orderHasConfiguredPaymentDiscount(_bill.id) || _bill.hasPromoDiscount;
    final orderCancelled =
        _bill.orderStatus.trim().toLowerCase() == 'cancelled';

    return AlertDialog(
      insetPadding: _billsDialogInsetPadding(context),
      backgroundColor: scheme.surfaceContainerLow,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: style.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: style.accent.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(style.icon, color: style.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.categoryLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: style.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_bill.displayOrderNumber.isNotEmpty)
                              Text(
                                '№ ${_bill.displayOrderNumber}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: style.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.canProcessPayments) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: hasPaymentDiscount ? 'Скидка' : 'Скидка %',
                  onPressed: _busy
                      ? null
                      : () async {
                          await configureOrderPaymentDiscount(
                            widget.posHostContext,
                            orderId: _bill.id,
                            orderTotal: orderSubtotalForPayment(_bill),
                          );
                          if (mounted) setState(() {});
                        },
                  style: IconButton.styleFrom(
                    foregroundColor: hasPaymentDiscount
                        ? const Color(0xFFEF6C00)
                        : scheme.onSurfaceVariant,
                  ),
                  icon: const Icon(Icons.percent_rounded),
                ),
              ],
              IconButton(
                tooltip: 'Закрыть',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _bill.tableNumber != null
                ? _bill.tableSummary
                : (_bill.isDelivery ? _bill.tableSummary : 'Без стола'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cashierTableHeadlineColor(
                scheme,
                assigned: _bill.tableNumber != null,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: _billDetailDialogWidth(context),
        height: _billDetailDialogHeight(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _bill.orderTypeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            PosBillChannelChips(bill: _bill),
            if (_bill.isDelivery && _bill.deliveryMethod != null) ...[
              const SizedBox(height: 6),
              Text(
                'Способ: ${_bill.deliveryMethod}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_bill.isDelivery && _bill.deliveryZone != null) ...[
              const SizedBox(height: 2),
              Text(
                'Радиус/зона: ${_bill.deliveryZone}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_bill.isDelivery && _bill.deliveryCourier != null) ...[
              const SizedBox(height: 2),
              Text(
                'Курьер: ${_bill.deliveryCourier}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_bill.hasPromoDiscount) ...[
              const SizedBox(height: 6),
              Text(
                'Промокод ${_bill.promoCode}: −${formatSomoni(_bill.promoDiscountAmount)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF7B1FA2),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 6),
            if (_bill.isHandedOutUnpaid) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Заказ уже выдан, оплата ещё не прошла. Можно добавить товары — '
                  'новые блюда снова уйдут на кухню.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Свайп влево: убрать 1 шт. (или всю строку, если 1 шт.). '
              'Если кухня ещё не приняла — убирается сразу. '
              'После «Принято» или «Готово» — укажите причину.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _linesScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _linesScrollController,
                      primary: false,
                      padding: EdgeInsets.zero,
                      itemCount: _bill.lines.length,
                      itemBuilder: (context, i) {
                        final l = _bill.lines[i];
                        final removable =
                            l.menuItemId?.trim().isNotEmpty ?? false;
                        final lineTile = _BillLineSwipeTile(
                          line: l,
                          theme: theme,
                          scheme: scheme,
                        );
                        // Нельзя убирать [Dismissible] на время `_busy`: иначе виджет
                        // снимается с дерева до завершения [confirmDismiss], анимация
                        // обрывается и [onDismissed] не вызывается — строка визуально
                        // остаётся до закрытия диалога. Блокировка — overlay + кнопки.
                        if (!removable) {
                          return lineTile;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey('${_bill.id}_${l.menuItemId}_$i'),
                            direction: DismissDirection.endToStart,
                            dismissThresholds: const {
                              DismissDirection.endToStart: 0.28,
                            },
                            confirmDismiss: (_) => _confirmSwipeRemoveLine(l),
                            onDismissed: (_) => _onDismissedLineAt(i),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Убрать',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: scheme.onError,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 30,
                                    color: scheme.onError,
                                  ),
                                ],
                              ),
                            ),
                            child: lineTile,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_busy)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (_bill.hasPromoDiscount) ...[
              Row(
                children: [
                  Text('Сумма позиций', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    formatSomoni(_bill.subtotalBeforeDiscount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Промокод ${_bill.promoCode ?? ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7B1FA2),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '−${formatSomoni(_bill.promoDiscountAmount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7B1FA2),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Text(
                  _bill.hasPromoDiscount ? 'К оплате' : 'Итого',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  formatSomoni(_bill.total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actionsAlignment: MainAxisAlignment.start,
      actions: [
        SizedBox(
          width: _billDetailDialogWidth(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: _billActionBtnStyle(),
                    onPressed: _busy
                        ? null
                        : () => showPosOrderHistoryDialog(
                              context,
                              orderId: _bill.id,
                              orderNumber:
                                  _bill.displayOrderNumber.isNotEmpty
                                  ? _bill.displayOrderNumber
                                  : _bill.orderNumber,
                            ),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('История'),
                  ),
                  if (!orderCancelled) ...[
                    OutlinedButton.icon(
                      style: _billActionBtnStyle(),
                      onPressed: _busy ? null : () => _changeOrderType(),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Тип'),
                    ),
                    if (!_bill.isDelivery) ...[
                      OutlinedButton.icon(
                        style: _billActionBtnStyle(),
                        onPressed: _busy ? null : () => _changeTable(),
                        icon: const Icon(
                          Icons.table_restaurant_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _bill.tableNumber != null ||
                                  _bill.tableLabel.trim().isNotEmpty
                              ? 'Стол'
                              : 'Стол+',
                        ),
                      ),
                      if (_bill.tableNumber != null ||
                          _bill.tableLabel.trim().isNotEmpty)
                        OutlinedButton.icon(
                          style: _billActionBtnStyle(),
                          onPressed: _busy ? null : () => _freeTable(),
                          icon: const Icon(
                            Icons.event_available_rounded,
                            size: 18,
                          ),
                          label: const Text('Освободить'),
                        ),
                    ],
                  ],
                  if (widget.canProcessPayments)
                    OutlinedButton.icon(
                      style: _billActionBtnStyle(),
                      onPressed:
                          _busy ||
                              _bill.lines.isEmpty ||
                              _bill.total <= 0 ||
                              orderCancelled
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await printOpenBillReceipt(
                                  widget.posHostContext,
                                  bill: _bill,
                                );
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Чек'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await _refreshOpenBillsHall(
                                  widget.posHostContext,
                                );
                                if (!widget.posHostContext.mounted) return;
                                final fresh = widget.posHostContext
                                    .read<PosHallOrdersCubit>()
                                    .findOpenBillByOrderId(_bill.id);
                                if (fresh != null) {
                                  _bill = fresh;
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                              if (!widget.posHostContext.mounted) return;
                              final nav = Navigator.of(
                                context,
                                rootNavigator: true,
                              );
                              nav.pop();
                              nav.pop();
                              if (!widget.posHostContext.mounted) return;
                              final menuState = widget.posHostContext
                                  .read<MenuBloc>()
                                  .state;
                              if (menuState.loading ||
                                  menuState.categoryRoots.isEmpty) {
                                ScaffoldMessenger.of(
                                  widget.posHostContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Дождитесь загрузки меню и повторите.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final hydrated =
                                  hydrateOpenTableBillIntoCartLines(
                                    menuRoots: menuState.categoryRoots,
                                    bill: _bill,
                                  );
                              widget.posHostContext.read<CartBloc>().add(
                                CartActiveCheckReplaced(hydrated.cartLines),
                              );
                              widget.posHostContext.read<CartBloc>().add(
                                CartOrderTypeIndexChanged(
                                  posOrderTypeIndexForOpenBill(_bill),
                                ),
                              );
                              final menuPath =
                                  initialMenuPathForProductPicker(
                                    menuState.categoryRoots,
                                  );
                              if (menuPath.isNotEmpty) {
                                widget.posHostContext.read<MenuBloc>().add(
                                  MenuCatalogPathSet(menuPath),
                                );
                              }
                              widget.posHostContext
                                  .read<PosHallOrdersCubit>()
                                  .startOpenBillAppend(
                                    _bill,
                                    baselineQtyByLineKey:
                                        hydrated.baselineQtyByLineKey,
                                    kitchenQtyLockedByLineKey:
                                        hydrated.kitchenQtyLockedByLineKey,
                                  );
                              final buf = StringBuffer();
                              if (hydrated.cartLines.isEmpty &&
                                  _bill.lines.isNotEmpty) {
                                buf.write(
                                  'Строки счёта не подставились в корзину — добавьте товары вручную. ',
                                );
                              } else if (hydrated.skippedLines > 0) {
                                buf.write(
                                  'Не найдено в меню: ${hydrated.skippedLines} поз. ',
                                );
                              }
                              buf.write(
                                hydrated.cartLines.isEmpty
                                    ? 'Затем нажмите «Добавить к счёту».'
                                    : 'Добавьте позиции при необходимости и нажмите «Добавить к счёту».',
                              );
                              if (!widget.posHostContext.mounted) return;
                              ScaffoldMessenger.of(
                                widget.posHostContext,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(buf.toString().trim()),
                                ),
                              );
                              await _returnCustomerDisplayToMenuWithCart();
                            },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('Дозаказ'),
                    ),
                  ),
                  if (widget.canProcessPayments) ...[
                    if (!_bill.isPaid) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          onPressed:
                              _busy ||
                                  _bill.lines.isEmpty ||
                                  _bill.total <= 0 ||
                                  orderCancelled
                              ? null
                              : () async {
                                  _markCustomerDisplayReturnedToMenu();
                                  Navigator.of(context).pop();
                                  await payOpenBill(
                                    widget.posHostContext,
                                    bill: _bill,
                                  );
                                  if (!widget.posHostContext.mounted) {
                                    return;
                                  }
                                  final stillOpen = widget.posHostContext
                                      .read<PosHallOrdersCubit>()
                                      .state
                                      .openBills;
                                  if (stillOpen.isEmpty) {
                                    Navigator.of(
                                      widget.posHostContext,
                                      rootNavigator: true,
                                    ).pop();
                                  }
                                },
                          icon: const Icon(Icons.payments_rounded),
                          label: const Text('Оплатить'),
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: null,
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Только касса'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  ButtonStyle _billActionBtnStyle() {
    return OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

Future<void> _showBillDetail(BuildContext posHostContext, PosTableBill bill) {
  final canProcessPayments =
      posHostContext.read<AuthBloc>().state.user?.canProcessPosPayments == true;
  final hallOrders = posHostContext.read<PosHallOrdersCubit>();
  return showDialog<void>(
    context: posHostContext,
    useRootNavigator: true,
    builder: (ctx) => BlocProvider.value(
      value: hallOrders,
      child: _BillDetailDialog(
        posHostContext: posHostContext,
        initialBill: bill,
        canProcessPayments: canProcessPayments,
      ),
    ),
  );
}

class _BillLineSwipeTile extends StatelessWidget {
  const _BillLineSwipeTile({
    required this.line,
    required this.theme,
    required this.scheme,
  });

  final PosTableBillLine line;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${line.quantity}× ${line.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (line.isKitchenLine) ...[
                      const SizedBox(height: 4),
                      Text(
                        _kitchenLineStatusLabel(line),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatSomoni(line.lineTotal),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillListTile extends StatelessWidget {
  const _BillListTile({
    required this.bill,
    required this.onOpen,
    this.onChangeTable,
    this.compact = false,
  });

  final PosTableBill bill;
  final VoidCallback onOpen;
  final VoidCallback? onChangeTable;
  final bool compact;

  Widget _categoryBadge(ThemeData theme, PosBillVisualStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.accent.withValues(alpha: 0.42)),
      ),
      child: Text(
        style.categoryLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: style.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _iconBox(
    PosBillVisualStyle style, {
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size >= 46 ? 14 : 12),
        border: Border.all(color: style.accent.withValues(alpha: 0.45)),
      ),
      alignment: Alignment.center,
      child: Icon(style.icon, color: style.accent, size: iconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = posBillVisualStyle(bill, scheme);
    final ui = context.watch<PosCashierBoardCubit>().state;
    final titleBase = theme.textTheme.titleMedium?.fontSize ?? 16;
    final bodyBase = theme.textTheme.bodyMedium?.fontSize ?? 14;
    final tableAssigned = bill.tableNumber != null;
    final tableTop = ui.showTableOnTop
        ? (tableAssigned
              ? cashierTableHeadline(
                  bill.tableZone != null
                      ? '${bill.tableZone!.shortLabel} • стол ${bill.tableNumber}'
                      : 'Стол ${bill.tableNumber}',
                )
              : (bill.isDelivery ? bill.tableSummary : 'Без стола'))
        : null;
    final pad = compact ? ui.cardPadding * 0.75 : ui.cardPadding * 0.9;
    final tableColor = cashierTableHeadlineColor(
      scheme,
      assigned: tableAssigned,
    );

    return Material(
      color: style.surfaceTint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: style.accent.withValues(alpha: 0.38)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: style.accent),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: compact
                        ? LayoutBuilder(
                            builder: (context, cell) {
                              // Крупный масштаб не должен «съедать» карточку:
                              // уменьшаем текст, но оставляем содержимое видимым.
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: cell.maxWidth.isFinite
                                      ? cell.maxWidth
                                      : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (tableTop != null) ...[
                                        Text(
                                          tableTop,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: (titleBase + 6) *
                                                ui.tableHeadlineScale,
                                            height: 1.05,
                                            color: tableColor,
                                          ),
                                        ),
                                        SizedBox(height: ui.sectionGap * 0.6),
                                      ],
                                      Row(
                                        children: [
                                          _iconBox(
                                            style,
                                            size: 40,
                                            iconSize: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          _categoryBadge(theme, style),
                                          if (onChangeTable != null) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              tooltip: tableAssigned
                                                  ? 'Сменить стол'
                                                  : 'Указать стол',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              onPressed: onChangeTable,
                                              icon: Icon(
                                                Icons.swap_horiz_rounded,
                                                color: style.accent,
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (bill.hasPromoDiscount) ...[
                                                Text(
                                                  formatSomoni(
                                                    bill.subtotalBeforeDiscount,
                                                  ),
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    fontSize: (bodyBase - 2) *
                                                        ui.titleScale,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                              ],
                                              Text(
                                                formatSomoni(bill.total),
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: style.accent,
                                                  fontSize: titleBase *
                                                      ui.titleScale,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (bill.displayOrderNumber.isNotEmpty)
                                        Text(
                                          '№ ${bill.displayOrderNumber}',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: style.accent,
                                            fontSize:
                                                bodyBase * ui.titleScale,
                                          ),
                                        ),
                                      if (!ui.showTableOnTop)
                                        Text(
                                          tableAssigned
                                              ? bill.tableSummary
                                              : (bill.isDelivery
                                                  ? bill.tableSummary
                                                  : 'Без стола'),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: tableColor,
                                            fontSize: titleBase *
                                                ui.tableHeadlineScale *
                                                0.85,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${bill.lines.length} поз. · ${bill.orderTypeLabel}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontSize:
                                              bodyBase * ui.itemTextScale,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Row(
                            children: [
                              _iconBox(style, size: 48, iconSize: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tableTop != null) ...[
                                      Text(
                                        tableTop,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize:
                                                  (titleBase + 6) *
                                                  ui.tableHeadlineScale,
                                              height: 1.05,
                                              color: tableColor,
                                            ),
                                      ),
                                      SizedBox(height: ui.sectionGap * 0.5),
                                    ],
                                    Row(
                                      children: [
                                        _categoryBadge(theme, style),
                                        if (bill.isHandedOutUnpaid) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.secondaryContainer
                                                  .withValues(alpha: 0.7),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Выдан',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                        ],
                                        if (onChangeTable != null) ...[
                                          const Spacer(),
                                          TextButton.icon(
                                            onPressed: onChangeTable,
                                            icon: const Icon(
                                              Icons.table_restaurant_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              tableAssigned
                                                  ? 'Стол'
                                                  : 'Указать стол',
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (bill.displayOrderNumber.isNotEmpty) ...[
                                      Text(
                                        '№ ${bill.displayOrderNumber}',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: style.accent,
                                              fontSize:
                                                  titleBase * ui.titleScale,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    if (!ui.showTableOnTop)
                                      Text(
                                        tableAssigned
                                            ? bill.tableSummary
                                            : (bill.isDelivery
                                                ? bill.tableSummary
                                                : 'Без стола'),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: tableColor,
                                            ),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${bill.lines.length} поз. · ${bill.orderTypeLabel}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontSize:
                                                bodyBase * ui.itemTextScale,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    PosBillChannelChips(bill: bill),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (bill.hasPromoDiscount) ...[
                                    Text(
                                      formatSomoni(bill.subtotalBeforeDiscount),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                    ),
                                    Text(
                                      'Промо ${bill.promoCode}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: const Color(0xFF7B1FA2),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    formatSomoni(bill.total),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: style.accent,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
