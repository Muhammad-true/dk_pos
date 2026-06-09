import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/pos/presentation/utils/pos_catalog_navigation.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

import 'open_table_bill_cart_hydrate.dart';
import 'pos_bill_channel_chips.dart';
import 'pos_bill_line_remove_reason_dialog.dart';
import 'pos_checkout_flow.dart';

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
  if (WindowLayout(width: MediaQuery.sizeOf(context).width).isCompact) {
    return h * 0.9;
  }
  return math.min(620, h * 0.82);
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = WindowLayout(width: constraints.maxWidth)
                          .cardGridColumns(minCellWidth: 240);
                      if (cols <= 1) {
                        return ListView.separated(
                          itemCount: open.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final bill = open[i];
                            return _BillListTile(
                              bill: bill,
                              onOpen: () => _showBillDetail(posHostContext, bill),
                            );
                          },
                        );
                      }
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: cols >= 3 ? 2.4 : 2.2,
                        ),
                        itemCount: open.length,
                        itemBuilder: (_, i) {
                          final bill = open[i];
                          return _BillListTile(
                            bill: bill,
                            compact: true,
                            onOpen: () => _showBillDetail(posHostContext, bill),
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
    final dtos = await repo.fetchOpenTableBills(branchId: AppConfig.storeBranchId);
    if (!posHostContext.mounted) return;
    final bills = dtos.map(posTableBillFromServerDto).toList();
    posHostContext.read<PosHallOrdersCubit>().mergeHydrateFromServer(bills);
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
  final ScrollController _linesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bill = widget.initialBill;
  }

  @override
  void dispose() {
    _linesScrollController.dispose();
    super.dispose();
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
    final l = _bill.lines[index];
    if (newQty <= 0) {
      _removeLineAt(index);
      return;
    }
    final unit = l.unitPrice ??
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
    );
    final nt = nl.fold<double>(0, (s, e) => s + e.lineTotal);
    setState(() {
      _bill = PosTableBill(
        id: _bill.id,
        lines: nl,
        total: nt,
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
      );
    });
  }

  void _removeLineAt(int index) {
    final nl = List<PosTableBillLine>.from(_bill.lines)..removeAt(index);
    final nt = nl.fold<double>(0, (s, e) => s + e.lineTotal);
    setState(() {
      _bill = PosTableBill(
        id: _bill.id,
        lines: nl,
        total: nt,
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
      );
    });
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
        ScaffoldMessenger.of(widget.posHostContext).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return false;
    } catch (e) {
      if (widget.posHostContext.mounted) {
        ScaffoldMessenger.of(widget.posHostContext).showSnackBar(
          SnackBar(content: Text('$e')),
        );
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

    return AlertDialog(
      insetPadding: _billsDialogInsetPadding(context),
      backgroundColor: scheme.surfaceContainerLow,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_bill.displayOrderNumber.isNotEmpty) ...[
            Text(
              '№ ${_bill.displayOrderNumber}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            _bill.tableSummary,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
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
                                    style: theme.textTheme.titleMedium?.copyWith(
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
            Row(
              children: [
                Text(
                  'Итого',
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Назад'),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await _refreshOpenBillsHall(widget.posHostContext);
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
                  final nav = Navigator.of(context, rootNavigator: true);
                  nav.pop();
                  nav.pop();
                  if (!widget.posHostContext.mounted) return;
                  final menuState = widget.posHostContext.read<MenuBloc>().state;
                  if (menuState.loading || menuState.categoryRoots.isEmpty) {
                    ScaffoldMessenger.of(widget.posHostContext).showSnackBar(
                      const SnackBar(
                        content: Text('Дождитесь загрузки меню и повторите.'),
                      ),
                    );
                    return;
                  }
                  final hydrated = hydrateOpenTableBillIntoCartLines(
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
                  final menuPath = initialMenuPathForProductPicker(
                    menuState.categoryRoots,
                  );
                  if (menuPath.isNotEmpty) {
                    widget.posHostContext.read<MenuBloc>().add(
                          MenuCatalogPathSet(menuPath),
                        );
                  }
                  widget.posHostContext.read<PosHallOrdersCubit>().startOpenBillAppend(
                        _bill,
                        baselineQtyByLineKey: hydrated.baselineQtyByLineKey,
                        kitchenQtyLockedByLineKey: hydrated.kitchenQtyLockedByLineKey,
                      );
                  final buf = StringBuffer();
                  if (hydrated.cartLines.isEmpty && _bill.lines.isNotEmpty) {
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
                  ScaffoldMessenger.of(widget.posHostContext).showSnackBar(
                    SnackBar(content: Text(buf.toString().trim())),
                  );
                },
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Добавить товар'),
        ),
        if (widget.canProcessPayments) ...[
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => configureOrderPaymentDiscount(
                      widget.posHostContext,
                      orderId: _bill.id,
                      orderTotal: _bill.total,
                    ),
            icon: const Icon(Icons.percent_rounded),
            label: const Text('Скидка'),
          ),
          FilledButton.icon(
            onPressed: _busy ||
                    _bill.lines.isEmpty ||
                    _bill.total <= 0 ||
                    _bill.orderStatus.trim().toLowerCase() == 'cancelled'
                ? null
                : () async {
                    Navigator.of(context).pop();
                    await payOpenBill(widget.posHostContext, bill: _bill);
                    if (!widget.posHostContext.mounted) return;
                    final stillOpen = widget.posHostContext
                        .read<PosHallOrdersCubit>()
                        .state
                        .openBills;
                    if (stillOpen.isEmpty) {
                      Navigator.of(widget.posHostContext, rootNavigator: true).pop();
                    }
                  },
            icon: const Icon(Icons.payments_rounded),
            label: const Text('Оплатить'),
          ),
        ] else
          FilledButton.tonalIcon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline_rounded),
            label: const Text('Оплата только на кассе'),
          ),
      ],
    );
  }
}

Future<void> _showBillDetail(BuildContext posHostContext, PosTableBill bill) {
  final canProcessPayments = posHostContext
          .read<AuthBloc>()
          .state
          .user
          ?.canProcessPosPayments ==
      true;
  return showDialog<void>(
    context: posHostContext,
    useRootNavigator: true,
    builder: (ctx) => _BillDetailDialog(
      posHostContext: posHostContext,
      initialBill: bill,
      canProcessPayments: canProcessPayments,
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
    this.compact = false,
  });

  final PosTableBill bill;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zone = bill.tableZone;
    final zoneAccent = switch (zone) {
      PosTableZone.hall => const Color(0xFFB8956C),
      PosTableZone.veranda => const Color(0xFF2D8B7E),
      null => scheme.primary,
    };

    final billIcon = bill.isDelivery ||
            (bill.tableNumber == null &&
                bill.orderTypeLabel.toLowerCase().contains('доставк'))
        ? Icons.delivery_dining_rounded
        : bill.tableNumber != null
            ? (zone == PosTableZone.veranda
                ? Icons.deck_rounded
                : Icons.table_restaurant_rounded)
            : Icons.receipt_long_rounded;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: zoneAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: zoneAccent.withValues(alpha: 0.45),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(billIcon, color: zoneAccent, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          formatSomoni(bill.total),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (bill.displayOrderNumber.isNotEmpty)
                      Text(
                        '№ ${bill.displayOrderNumber}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    Text(
                      bill.tableSummary,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.lines.length} поз. · ${bill.orderTypeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: zoneAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: zoneAccent.withValues(alpha: 0.45),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(billIcon, color: zoneAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (bill.displayOrderNumber.isNotEmpty) ...[
                            Text(
                              '№ ${bill.displayOrderNumber}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            bill.tableSummary,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              '${bill.lines.length} поз.',
                              bill.orderTypeLabel,
                              if (bill.isHandedOutUnpaid) 'выдан',
                            ].join(' • '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          PosBillChannelChips(bill: bill),
                        ],
                      ),
                    ),
                    Text(
                      formatSomoni(bill.total),
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
