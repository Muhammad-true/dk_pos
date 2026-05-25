import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/constants/phone_defaults.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/core/input/tj_phone_dial_locked_formatter.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/cart/domain/cart_payment_adjustment.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/payments/data/local_payments_repository.dart';
import 'package:dk_pos/features/payments/data/local_payment_methods_repository.dart';
import 'package:dk_pos/features/loyalty/data/local_loyalty_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_online_order_edit_flow.dart';
import 'package:flutter/services.dart';

/// Тип заказа в корзине POS (совпадает с выбором в панели корзины).
enum PosCheckoutOrderType { takeAway, dineIn, delivery }

extension on PosCheckoutOrderType {
  String get label => switch (this) {
    PosCheckoutOrderType.takeAway => 'С собой',
    PosCheckoutOrderType.dineIn => 'На месте',
    PosCheckoutOrderType.delivery => 'Доставка',
  };
}

String _orderTypeLabelForSync(
  PosCheckoutOrderType orderType, {
  required bool waiterMode,
}) {
  final base = orderType.label;
  if (!waiterMode) return base;
  return '$base • Официант';
}

/// Индекс типа заказа в корзине (0 — с собой, 1 — на месте, 2 — доставка) по подписи открытого счёта.
int posOrderTypeIndexForOpenBill(PosTableBill bill) {
  final l = bill.orderTypeLabel.toLowerCase().trim();
  if (l.contains('доставк') || l.contains('delivery')) return 2;
  if (l.contains('самовывоз') ||
      l.contains('pickup') ||
      l.contains('takeaway') ||
      l.contains('to_go') ||
      l.contains('парковк') ||
      l.contains('parking')) {
    return 0;
  }
  if (l.contains('на месте') ||
      l.contains('dinein') ||
      l.contains('dine_in') ||
      l.contains('dine-in') ||
      l.contains('onsite') ||
      l.contains('on_site')) {
    return 1;
  }
  return 0;
}

Future<void> refreshOpenTableBillsIntoHall(BuildContext context) async {
  try {
    final repo = context.read<LocalOrdersRepository>();
    final dtos = await repo.fetchOpenTableBills(
      branchId: AppConfig.storeBranchId,
    );
    if (!context.mounted) return;
    final bills = dtos.map(posTableBillFromServerDto).toList();
    context.read<PosHallOrdersCubit>().mergeHydrateFromServer(bills);
  } catch (_) {
    // сеть — счёт на сервере уже обновлён, список подтянется по таймеру
  }
}

/// Оформление: стол (для «На месте»), оплата сейчас или позже, затем счёт и очистка корзины.
///
/// [appendToOpenBill]: только новые позиции в [cart]; счёт и стол берутся из счёта, оплата только позже
/// (полную сумму принимают из «Счета на оплату» после обновления с сервера).
Future<void> runPosCheckoutFlow(
  BuildContext context, {
  required PosCheckoutOrderType orderType,
  required CartState cart,
  bool waiterMode = false,
  PosTableBill? appendToOpenBill,
}) async {
  if (cart.isEmpty || !context.mounted) return;
  final user = context.read<AuthBloc>().state.user;
  final isWaiter = user?.isWaiter == true;
  final append = appendToOpenBill;

  late final bool effectiveWaiterMode;
  late final PosCheckoutOrderType effectiveOrderType;
  late final String effectiveOrderTypeLabel;

  int? tableNumber;
  PosTableZone? tableZone;

  if (append != null) {
    effectiveOrderTypeLabel = append.orderTypeLabel;
    final idx = posOrderTypeIndexForOpenBill(append);
    effectiveOrderType = switch (idx) {
      2 => PosCheckoutOrderType.delivery,
      1 => PosCheckoutOrderType.dineIn,
      _ => PosCheckoutOrderType.takeAway,
    };
    effectiveWaiterMode =
        waiterMode ||
        isWaiter ||
        append.orderTypeLabel.toLowerCase().contains('официант');
    tableNumber = append.tableNumber;
    tableZone = append.tableZone;
  } else {
    effectiveWaiterMode = waiterMode || isWaiter;
    effectiveOrderType = orderType;
    effectiveOrderTypeLabel = _orderTypeLabelForSync(
      effectiveOrderType,
      waiterMode: effectiveWaiterMode,
    );

    if (effectiveOrderType == PosCheckoutOrderType.dineIn) {
      if (effectiveWaiterMode) {
        final outcome = await showPosTablePickDialog(
          context,
          allowSkipTable: false,
        );
        if (!context.mounted) return;
        if (outcome is! PosTablePickChosen) {
          if (outcome == null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Для заказа «на месте» выберите стол в диалоге '
                  '(или нажмите «Оформить заказ» ещё раз).',
                ),
              ),
            );
          }
          return;
        }
        tableNumber = outcome.number;
        tableZone = outcome.zone;
      } else {
        final outcome = await showPosTablePickDialog(
          context,
          allowSkipTable: true,
        );
        if (!context.mounted) return;
        if (outcome == null) return;
        if (outcome is PosTablePickChosen) {
          tableNumber = outcome.number;
          tableZone = outcome.zone;
        }
      }
    }
  }

  bool payNow = false;
  if (append == null && !effectiveWaiterMode) {
    final timing = await _pickPayTiming(context);
    if (!context.mounted) return;
    if (timing == null) return;
    payNow = timing;
  }

  LocalPaymentMethod? paymentMethod;
  final paymentDiscount = _discountDraftFromCartAdjustment(
    context.read<CartBloc>().state.paymentAdjustment,
  );
  var payableTotal = paymentDiscount?.payableAmount ?? cart.total;
  if (payNow) {
    try {
      paymentMethod = await _pickPaymentMethod(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить способы оплаты: $e')),
      );
      return;
    }
    if (!context.mounted) return;
    if (paymentMethod == null) return;
  }
  _CashPaymentDraft? cashDraft;
  _MixedPaymentDraft? mixedDraft;
  bool? skipReceipt;
  if (payNow && paymentMethod != null) {
    if (paymentMethod.code == 'mixed') {
      mixedDraft = await _pickMixedPayment(context, total: payableTotal);
      if (!context.mounted || mixedDraft == null) return;
    } else if (paymentMethod.isCash) {
      cashDraft = await _pickCashReceived(context, total: payableTotal);
      if (!context.mounted || cashDraft == null) return;
    }
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    skipReceipt = await _pickReceiptChoice(context);
    if (!context.mounted || skipReceipt == null) return;
  }

  PosTableBill? openBillBefore;
  if (append == null && tableNumber != null && tableZone != null) {
    openBillBefore = context.read<PosHallOrdersCubit>().findOpenBillForTable(
      number: tableNumber,
      zone: tableZone,
    );
  }

  final hall = context.read<PosHallOrdersCubit>();
  final cartBloc = context.read<CartBloc>();

  late final String registeredId;
  if (append != null) {
    registeredId = append.id;
  } else {
    final lines = cart.sortedLines
        .map(
          (l) => PosTableBillLine(
            name: l.item.name,
            quantity: l.quantity,
            lineTotal: l.lineTotal,
          ),
        )
        .toList(growable: false);
    final bill = PosTableBill(
      id: 'tb-${DateTime.now().millisecondsSinceEpoch}',
      lines: lines,
      total: cart.total,
      orderTypeLabel: effectiveOrderTypeLabel,
      tableNumber: tableNumber,
      tableZone: tableZone,
      createdAt: DateTime.now(),
      isPaid: false,
      paymentMethod: null,
    );
    final registered = hall.registerOrMergeBill(bill);
    registeredId = registered.id;
  }

  final appendBaselineQtyByLineKey = append != null
      ? Map<String, int>.from(hall.state.openBillAppendBaselineQtyByLineKey)
      : null;

  final orderSync = await _syncLocalOrder(
    context,
    orderId: registeredId,
    cart: cart,
    orderTypeLabel: effectiveOrderTypeLabel,
    tableZone: tableZone,
    tableNumber: tableNumber,
    appendBaselineQtyByLineKey: appendBaselineQtyByLineKey,
  );
  if (!context.mounted) return;

  if (append != null && !orderSync.synced) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(orderSync.message ?? 'Не удалось сохранить заказ')),
    );
    return;
  }

  String? paymentHint;
  final orderHint = orderSync.message ?? '';
  var paymentAccepted = false;
  _PaymentAttemptResult? paymentResult;
  if (payNow) {
    final progressOverlay = _showBlockingPaymentOverlay(
      context,
      skipReceipt: skipReceipt ?? false,
    );
    try {
      paymentResult = mixedDraft != null
          ? await _runMixedLocalPayment(
              context,
              orderId: registeredId,
              total: payableTotal,
              mixed: mixedDraft,
              discountDraft: paymentDiscount,
              skipReceipt: skipReceipt ?? false,
            )
          : await _runLocalPayment(
              context,
              orderId: registeredId,
              total: payableTotal,
              paymentMethod: paymentMethod!,
              cashDraft: cashDraft,
              discountDraft: paymentDiscount,
              skipReceipt: skipReceipt ?? false,
            );
    } finally {
      progressOverlay?.close();
    }
    paymentAccepted = paymentResult.accepted;
    paymentHint = paymentResult.message;
    if (paymentAccepted) {
      if (!context.mounted) return;
      hall.markPaid(
        registeredId,
        paymentMethod: mixedDraft?.summaryTitle ?? paymentMethod!.title,
      );
    }
  }
  final consentEdit = append != null && hall.state.openBillAppendCustomerConsent;
  final consentMeta = hall.state.openBillAppendConsentMeta;
  final appendTotal = cart.total;

  cartBloc.add(const CartCleared());
  if (append != null) {
    hall.clearOpenBillAppend();
    await refreshOpenTableBillsIntoHall(context);
  }

  if (!context.mounted) return;
  final merged = append != null || openBillBefore != null;

  if (append != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          [
            'Счёт «${append.tableSummary}» обновлён на сервере. '
                'Оплату проведите в «Счета на оплату».',
            if (orderHint.isNotEmpty) orderHint,
          ].where((s) => s.isNotEmpty).join(' • '),
        ),
      ),
    );
    if (consentEdit && consentMeta != null) {
      await offerPrintConsentUpdatedReceipt(
        context,
        orderId: registeredId,
        total: appendTotal,
        meta: consentMeta,
      );
    }
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        [
          payNow
              ? (paymentAccepted
                    ? (merged
                          ? 'Добавлено к счёту и оплачено${_tablePlaceSnippet(effectiveOrderType, tableZone, tableNumber)}'
                          : 'Заказ оформлен и оплачен${_tablePlaceSnippet(effectiveOrderType, tableZone, tableNumber)}')
                    : 'Заказ оформлен${_tablePlaceSnippet(effectiveOrderType, tableZone, tableNumber)}, но оплата не подтверждена')
              : (merged
                    ? 'Позиции добавлены к открытому счёту${_tablePlaceSnippet(effectiveOrderType, tableZone, tableNumber)}'
                    : 'Счёт открыт${_tablePlaceSnippet(effectiveOrderType, tableZone, tableNumber)} — оплату можно провести позже'),
          if (orderHint.isNotEmpty) orderHint,
          if (paymentHint != null && paymentHint.isNotEmpty) paymentHint,
          if (mixedDraft != null) mixedDraft.summaryTitle,
          if (cashDraft != null)
            'Получено ${formatSomoni(cashDraft.received)}, сдача ${formatSomoni(cashDraft.change)}',
          if (paymentDiscount != null && paymentDiscount.totalDiscount > 0)
            'Скидка ${formatSomoni(paymentDiscount.totalDiscount)} (${formatSomoni(cart.total)} -> ${formatSomoni(paymentDiscount.payableAmount)})',
        ].join(' • '),
      ),
    ),
  );
  if (paymentResult?.retryPrintAvailable == true) {
    _showHardwareRetrySnackBar(
      context,
      orderId: paymentResult!.retryOrderId,
      total: paymentResult.retryTotal,
      paymentMethod: paymentResult.retryPaymentMethod,
      errorMessage: paymentResult.hardwareErrorMessage,
    );
  }
}

String _tablePlaceSnippet(
  PosCheckoutOrderType orderType,
  PosTableZone? zone,
  int? tableNumber,
) {
  if (tableNumber != null) {
    if (zone != null) return ' • ${zone.shortLabel}, стол $tableNumber';
    return ' • Стол $tableNumber';
  }
  if (orderType == PosCheckoutOrderType.dineIn) {
    return ' • без стола';
  }
  return '';
}

/// Результат диалога стола: выбран стол, пропуск (на месте без стола) или `null` = отмена.
sealed class PosTablePickOutcome {}

final class PosTablePickChosen extends PosTablePickOutcome {
  PosTablePickChosen({required this.number, required this.zone});

  final int number;
  final PosTableZone zone;
}

final class PosTablePickSkipTable extends PosTablePickOutcome {}

/// Диалог выбора столика (зал / веранда / без стола / отмена).
Future<PosTablePickOutcome?> showPosTablePickDialog(
  BuildContext context, {
  bool allowSkipTable = true,
}) {
  // Overlay диалога не под [PosScreen], поэтому cubit нужно пробросить явно
  // (как в [showOpenTableBillsDialog]).
  final hallOrders = context.read<PosHallOrdersCubit>();
  return showDialog<PosTablePickOutcome?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: allowSkipTable,
    barrierColor: Colors.black54,
    builder: (_) => BlocProvider.value(
      value: hallOrders,
      child: _PickTableDialog(allowSkipTable: allowSkipTable),
    ),
  );
}

class _PickTableDialog extends StatefulWidget {
  const _PickTableDialog({required this.allowSkipTable});

  final bool allowSkipTable;

  static int get hallTableCount => AppConfig.posHallTableCount;
  static int get verandaTableCount => AppConfig.posVerandaTableCount;

  @override
  State<_PickTableDialog> createState() => _PickTableDialogState();
}

class _PickTableDialogState extends State<_PickTableDialog> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: screen.height * 0.92,
          minHeight: 260,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.table_restaurant_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Выбор столика',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.allowSkipTable
                              ? 'Зал: столы 1–${_PickTableDialog.hallTableCount}, '
                                    'веранда: столы 1–${_PickTableDialog.verandaTableCount}. '
                                    'Можно оформить без стола — кнопка внизу.'
                              : 'Зал: столы 1–${_PickTableDialog.hallTableCount}, '
                                    'веранда: столы 1–${_PickTableDialog.verandaTableCount}. '
                                    'Стол обязателен.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Стол занят, если на нём уже есть неоплаченный счёт. '
                          'Новый заказ на этот стол будет добавлен к тому же счёту.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w >= 680
                          ? 8
                          : w >= 500
                          ? 7
                          : w >= 380
                          ? 6
                          : 5;
                      return BlocBuilder<
                        PosHallOrdersCubit,
                        PosHallOrdersState
                      >(
                        builder: (context, hallState) {
                          final occupiedKeys = <String>{};
                          for (final b in hallState.openBills) {
                            if (b.tableNumber != null && b.tableZone != null) {
                              occupiedKeys.add(
                                b.tableZone!.occupiedKey(b.tableNumber!),
                              );
                            }
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ZoneTableGrid(
                                title: 'Зал',
                                subtitle:
                                    'столы 1–${_PickTableDialog.hallTableCount}',
                                zone: PosTableZone.hall,
                                firstTableNumber: 1,
                                tableCount: _PickTableDialog.hallTableCount,
                                crossAxisCount: cols,
                                headerColor: const Color(0xFFB8956C),
                                icon: Icons.restaurant_rounded,
                                occupiedKeys: occupiedKeys,
                                onPick: (n) => Navigator.of(context).pop(
                                  PosTablePickChosen(
                                    number: n,
                                    zone: PosTableZone.hall,
                                  ),
                                ),
                              ),
                              if (_PickTableDialog.verandaTableCount > 0) ...[
                                const SizedBox(height: 14),
                                _ZoneTableGrid(
                                  title: 'Веранда',
                                  subtitle:
                                      'столы 1–${_PickTableDialog.verandaTableCount}',
                                  zone: PosTableZone.veranda,
                                  firstTableNumber: 1,
                                  tableCount:
                                      _PickTableDialog.verandaTableCount,
                                  crossAxisCount: cols,
                                  headerColor: const Color(0xFF2D8B7E),
                                  icon: Icons.deck_rounded,
                                  occupiedKeys: occupiedKeys,
                                  onPick: (n) => Navigator.of(context).pop(
                                    PosTablePickChosen(
                                      number: n,
                                      zone: PosTableZone.veranda,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  if (widget.allowSkipTable)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(PosTablePickSkipTable()),
                      icon: const Icon(Icons.table_bar_rounded, size: 18),
                      label: const Text('Без стола'),
                    ),
                  if (widget.allowSkipTable) const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneTableGrid extends StatelessWidget {
  const _ZoneTableGrid({
    required this.title,
    required this.subtitle,
    required this.zone,
    required this.firstTableNumber,
    required this.tableCount,
    required this.crossAxisCount,
    required this.headerColor,
    required this.icon,
    required this.occupiedKeys,
    required this.onPick,
  });

  final String title;
  final String subtitle;
  final PosTableZone zone;

  /// Сквозной номер первого столика в этой зоне.
  final int firstTableNumber;
  final int tableCount;
  final int crossAxisCount;
  final Color headerColor;
  final IconData icon;
  final Set<String> occupiedKeys;
  final void Function(int number) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 26,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: headerColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.38,
              ),
              itemCount: tableCount,
              itemBuilder: (context, i) {
                final n = firstTableNumber + i;
                final occupied = occupiedKeys.contains(zone.occupiedKey(n));
                return _TableStoolTile(
                  zone: zone,
                  number: n,
                  occupied: occupied,
                  onTap: () => onPick(n),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TableStoolTile extends StatelessWidget {
  const _TableStoolTile({
    required this.zone,
    required this.number,
    required this.occupied,
    required this.onTap,
  });

  final PosTableZone zone;
  final int number;
  final bool occupied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (gradientColors, borderColor, iconColor, splash) = switch (zone) {
      PosTableZone.hall => (
        isDark
            ? [const Color(0xFF3D3428), scheme.surfaceContainerHigh]
            : [const Color(0xFFFFF6EB), const Color(0xFFF2E4D4)],
        const Color(0xFFB8956C),
        isDark ? const Color(0xFFD4A574) : const Color(0xFFC47A3A),
        const Color(0xFFB8956C),
      ),
      PosTableZone.veranda => (
        isDark
            ? [const Color(0xFF1E3532), scheme.surfaceContainerHigh]
            : [const Color(0xFFEEF9F6), const Color(0xFFD8EEE8)],
        const Color(0xFF2D8B7E),
        isDark ? const Color(0xFF5EC4B5) : const Color(0xFF1F6B62),
        const Color(0xFF2D8B7E),
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: splash.withValues(alpha: 0.22),
        highlightColor: splash.withValues(alpha: 0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_restaurant_rounded,
                    size: 16,
                    color: iconColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$number',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (occupied)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Занят',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `true` — оплатить сейчас, `false` — открыть счёт (оплата позже), `null` — отмена.
Future<bool?> _pickPayTiming(BuildContext context) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(
          'Когда оплатить?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: _dialogWidth(context, 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Можно принять оплату сразу или оставить открытый счёт и оплатить, когда гость подойдёт к кассе.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Оплатить сейчас'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(false),
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Оплатить позже (счёт на стол)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
        ],
      );
    },
  );
}

const _mixedPaymentPicker = LocalPaymentMethod(
  id: null,
  code: 'mixed',
  title: 'Смешанная',
  type: 'mixed',
  isActive: true,
  sortOrder: -1,
  details: {},
  isSystem: true,
);

Future<LocalPaymentMethod?> _pickPaymentMethod(BuildContext context) async {
  final methods = await context
      .read<LocalPaymentMethodsRepository>()
      .fetchMethods();
  final visible = methods.where((m) => m.isActive).toList(growable: false);
  final tiles = [_mixedPaymentPicker, ...visible];
  return showDialog<LocalPaymentMethod>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(
          'Способ оплаты',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: _dialogWidth(context, 460),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: tiles
                .map(
                  (method) => _PaymentPickTile(
                    label: method.title,
                    icon: method.code == 'mixed'
                        ? Icons.call_split_rounded
                        : method.isCash
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded,
                    onTap: () => Navigator.of(ctx).pop(method),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
        ],
      );
    },
  );
}

class _CashPaymentDraft {
  const _CashPaymentDraft({required this.received, required this.change});

  final double received;
  final double change;
}

class _MixedPaymentDraft {
  const _MixedPaymentDraft({
    required this.cashAmount,
    required this.bankMethod,
    required this.bankAmount,
    this.cashReceived,
    this.cashChange,
  });

  final double cashAmount;
  final LocalPaymentMethod bankMethod;
  final double bankAmount;
  final double? cashReceived;
  final double? cashChange;

  String get summaryTitle {
    final cashPart = formatSomoni(cashAmount);
    final bankPart = formatSomoni(bankAmount);
    return 'Наличные $cashPart + ${bankMethod.title} $bankPart';
  }
}

final Map<String, _PaymentDiscountDraft> _orderPaymentAdjustmentsById = {};

/// Скидка для оплаты счёта из «Счета на оплату» (кнопка % рядом с «Оплатить»).
Future<void> configureOrderPaymentDiscount(
  BuildContext context, {
  required String orderId,
  required double orderTotal,
}) async {
  final draft = await _pickPaymentDiscounts(context, total: orderTotal);
  if (!context.mounted || draft == null) return;
  _orderPaymentAdjustmentsById[orderId] = draft;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        draft.totalDiscount > 0
            ? 'Скидка ${formatSomoni(draft.totalDiscount)} — к оплате ${formatSomoni(draft.payableAmount)}'
            : 'Скидки сброшены',
      ),
    ),
  );
}

/// Скидка для активного чека (кнопка % в корзине).
Future<void> configureCartPaymentDiscount(
  BuildContext context, {
  required double cartTotal,
}) async {
  final draft = await _pickPaymentDiscounts(context, total: cartTotal);
  if (!context.mounted || draft == null) return;
  context.read<CartBloc>().add(
    CartPaymentAdjustmentChanged(
      CartPaymentAdjustment(
        baseTotal: draft.baseTotal,
        promoCode: draft.promoCode,
        promoDiscountAmount: draft.promoDiscountAmount,
        loyaltyDiscountAmount: draft.loyaltyDiscountAmount,
        loyaltyCardNo: draft.loyaltyCardNo,
        customerId: draft.customerId,
      ),
    ),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        draft.totalDiscount > 0
            ? 'Скидка ${formatSomoni(draft.totalDiscount)} — к оплате ${formatSomoni(draft.payableAmount)}'
            : 'Скидки применены',
      ),
    ),
  );
}

_PaymentDiscountDraft? _discountDraftFromCartAdjustment(
  CartPaymentAdjustment? adjustment,
) {
  if (adjustment == null) return null;
  return _PaymentDiscountDraft(
    baseTotal: adjustment.baseTotal,
    promoCode: adjustment.promoCode,
    promoDiscountAmount: adjustment.promoDiscountAmount,
    loyaltyDiscountAmount: adjustment.loyaltyDiscountAmount,
    loyaltyCardNo: adjustment.loyaltyCardNo,
    explicitCustomerId: adjustment.customerId,
  );
}

/// `true` — без чека, `false` — с чеком, `null` — отмена.
Future<bool?> _pickReceiptChoice(BuildContext context) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.of(ctx).pop();
        },
        child: Dialog(
        backgroundColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: SizedBox(
            width: _dialogWidth(ctx, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Печать чека',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Отмена',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Как провести оплату?',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print_rounded, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              'С чеком',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print_disabled_outlined, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              'Без чека',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      );
    },
  );
}

class _PaymentDiscountDraft {
  const _PaymentDiscountDraft({
    required this.baseTotal,
    required this.promoCode,
    required this.promoDiscountAmount,
    required this.loyaltyDiscountAmount,
    required this.loyaltyCardNo,
    this.customer,
    this.explicitCustomerId,
    this.skipReceipt = false,
  });

  final double baseTotal;
  final String promoCode;
  final double promoDiscountAmount;
  final double loyaltyDiscountAmount;
  final String loyaltyCardNo;
  final LoyaltyCustomer? customer;
  final int? explicitCustomerId;
  final bool skipReceipt;

  int? get customerId => explicitCustomerId ?? customer?.id;

  double get totalDiscount => promoDiscountAmount + loyaltyDiscountAmount;
  double get payableAmount => baseTotal - totalDiscount;
}

double? _parseMoneyInput(String value) {
  final normalized = value.replaceAll(',', '.').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

double _safeDiscountAmount(String raw) {
  final parsed = _parseMoneyInput(raw);
  if (parsed == null || !parsed.isFinite || parsed < 0) return 0;
  return parsed;
}

Future<_PaymentDiscountDraft?> _pickPaymentDiscounts(
  BuildContext context, {
  required double total,
}) {
  return showDialog<_PaymentDiscountDraft>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _PaymentDiscountDialog(total: total),
  );
}

class _PaymentDiscountDialog extends StatefulWidget {
  const _PaymentDiscountDialog({required this.total});

  final double total;

  @override
  State<_PaymentDiscountDialog> createState() => _PaymentDiscountDialogState();
}

class _PaymentDiscountDialogState extends State<_PaymentDiscountDialog> {
  late final TextEditingController _promoCodeCtrl;
  late final TextEditingController _promoDiscountCtrl;
  late final TextEditingController _loyaltyDiscountCtrl;
  late final TextEditingController _loyaltyCardCtrl;
  LoyaltyCustomer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _promoCodeCtrl = TextEditingController();
    _promoDiscountCtrl = TextEditingController();
    _loyaltyDiscountCtrl = TextEditingController();
    _loyaltyCardCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _promoCodeCtrl.dispose();
    _promoDiscountCtrl.dispose();
    _loyaltyDiscountCtrl.dispose();
    _loyaltyCardCtrl.dispose();
    super.dispose();
  }

  _PaymentDiscountDraft _buildDraft({
    required double promoDiscount,
    required double loyaltyDiscount,
    bool skipReceipt = false,
  }) {
    return _PaymentDiscountDraft(
      baseTotal: widget.total,
      promoCode: _promoCodeCtrl.text.trim(),
      promoDiscountAmount: promoDiscount,
      loyaltyDiscountAmount: loyaltyDiscount,
      loyaltyCardNo: _loyaltyCardCtrl.text.trim().isNotEmpty
          ? _loyaltyCardCtrl.text.trim()
          : (_selectedCustomer?.cardCode ?? ''),
      customer: _selectedCustomer,
      skipReceipt: skipReceipt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedCustomer = _selectedCustomer;
    final promoDiscount = _safeDiscountAmount(_promoDiscountCtrl.text);
    final loyaltyDiscountRaw = _safeDiscountAmount(_loyaltyDiscountCtrl.text);
    final maxLoyaltyDiscount = selectedCustomer == null
        ? 0.0
        : math.min(
            selectedCustomer.pointsBalance,
            widget.total - promoDiscount,
          );
    final loyaltyDiscount = selectedCustomer == null
        ? 0.0
        : math.min(loyaltyDiscountRaw, maxLoyaltyDiscount);
    final totalDiscount = promoDiscount + loyaltyDiscount;
    final payable = widget.total - totalDiscount;
    final canSubmit = payable > 0;

    return AlertDialog(
      backgroundColor: scheme.surfaceContainerLow,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Скидки и промокод',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            tooltip: 'Без скидки',
            onPressed: () {
              _promoCodeCtrl.clear();
              _promoDiscountCtrl.clear();
              _loyaltyCardCtrl.clear();
              _loyaltyDiscountCtrl.clear();
              _selectedCustomer = null;
              setState(() {});
            },
            icon: const Icon(Icons.money_off_csred_outlined),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            tooltip: 'Отмена',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          primary: false,
          child: SizedBox(
            width: _dialogWidth(context, 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Сумма до скидки: ${formatSomoni(widget.total)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promoCodeCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Промокод (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promoDiscountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Скидка по промокоду',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _loyaltyCardCtrl,
              onChanged: (_) {},
              decoration: const InputDecoration(
                labelText: 'Номер карты лояльности (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickLoyaltyCustomer(context);
                      if (!mounted || picked == null) return;
                      setState(() {
                        _selectedCustomer = picked;
                        if (_loyaltyCardCtrl.text.trim().isEmpty) {
                          _loyaltyCardCtrl.text = picked.cardCode ?? '';
                        }
                      });
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Найти клиента'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final created = await _createLoyaltyCustomer(context);
                      if (!mounted || created == null) return;
                      setState(() {
                        _selectedCustomer = created;
                        _loyaltyCardCtrl.text = created.cardCode ?? '';
                      });
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Новый клиент'),
                  ),
                ),
              ],
            ),
            if (selectedCustomer != null) ...[
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedCustomer.fullName} • ${selectedCustomer.phone}'
                          '\nБаллы: ${selectedCustomer.pointsBalance.toStringAsFixed(2)}'
                          '${selectedCustomer.tier != null ? ' • ${selectedCustomer.tier!.title} (${selectedCustomer.tier!.accrualPercent.toStringAsFixed(2)}%)' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Убрать клиента',
                        onPressed: () => setState(() {
                          _selectedCustomer = null;
                          _loyaltyDiscountCtrl.clear();
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _loyaltyDiscountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              enabled: selectedCustomer != null,
              decoration: InputDecoration(
                labelText: selectedCustomer != null
                    ? 'Списать баллы'
                    : 'Сначала выберите клиента',
                hintText: selectedCustomer != null
                    ? 'Макс: ${maxLoyaltyDiscount.toStringAsFixed(2)}'
                    : '0',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Итого скидка: ${formatSomoni(totalDiscount)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'К оплате: ${formatSomoni(payable > 0 ? payable : 0)}',
              style: theme.textTheme.titleLarge?.copyWith(
                color: canSubmit
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFD32F2F),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!canSubmit) ...[
              const SizedBox(height: 8),
              Text(
                'Сумма к оплате должна быть больше 0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD32F2F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
                if (selectedCustomer == null && loyaltyDiscountRaw > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Для накопительной скидки нужно выбрать клиента',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD32F2F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                    _buildDraft(
                      promoDiscount: promoDiscount,
                      loyaltyDiscount: loyaltyDiscount,
                    ),
                  )
              : null,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

Future<LoyaltyCustomer?> _pickLoyaltyCustomer(BuildContext context) {
  return showDialog<LoyaltyCustomer>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _LoyaltyCustomerSearchDialog(),
  );
}

Future<LoyaltyCustomer?> _createLoyaltyCustomer(BuildContext context) {
  return showDialog<LoyaltyCustomer>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _LoyaltyCustomerCreateDialog(),
  );
}

class _LoyaltyCustomerSearchDialog extends StatefulWidget {
  const _LoyaltyCustomerSearchDialog();

  @override
  State<_LoyaltyCustomerSearchDialog> createState() =>
      _LoyaltyCustomerSearchDialogState();
}

class _LoyaltyCustomerSearchDialogState
    extends State<_LoyaltyCustomerSearchDialog> {
  final _queryCtrl = TextEditingController();
  Timer? _scanDebounce;
  int _searchToken = 0;
  bool _autoScan = true;
  bool _loading = true;
  String? _error;
  List<LoyaltyCustomer> _customers = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search({bool tryAutoPick = false}) async {
    final token = ++_searchToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalLoyaltyRepository>();
      final data = await repo.searchCustomers(
        query: _queryCtrl.text.trim(),
        limit: 80,
      );
      if (!mounted || token != _searchToken) return;
      setState(() {
        _customers = data;
      });
      if (tryAutoPick && _autoScan) {
        final picked = _tryPickExactMatch(data, _queryCtrl.text);
        if (picked != null && mounted) {
          Navigator.of(context).pop(picked);
        }
      }
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && token == _searchToken) setState(() => _loading = false);
    }
  }

  void _onQueryChanged(String value) {
    if (!_autoScan) return;
    _scanDebounce?.cancel();
    _scanDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _search(tryAutoPick: true);
    });
  }

  LoyaltyCustomer? _tryPickExactMatch(
    List<LoyaltyCustomer> customers,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return null;
    final queryPhone = _normalizePhoneLike(query);
    for (final c in customers) {
      if (c.isBlacklisted) continue;
      final qr = c.qrCode.trim().toLowerCase();
      final card = (c.cardCode ?? '').trim().toLowerCase();
      final phone = _normalizePhoneLike(c.phone);
      if (qr == query || card == query) return c;
      if (queryPhone.isNotEmpty && phone == queryPhone) return c;
    }
    return null;
  }

  String _normalizePhoneLike(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Поиск клиента'),
      content: SizedBox(
        width: _dialogWidth(context, 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Телефон / карта / QR / имя (сканер)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _search(tryAutoPick: true),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _search(tryAutoPick: true),
                  child: const Text('Найти'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Авто-скан: при точном совпадении клиент выберется автоматически.',
                    style: theme.bodySmall,
                  ),
                ),
                Switch(
                  value: _autoScan,
                  onChanged: (v) => setState(() => _autoScan = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(
                _error!,
                style: theme.bodyMedium?.copyWith(color: scheme.error),
              ),
            if (!_loading)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = _customers[index];
                    return ListTile(
                      title: Text(c.fullName),
                      subtitle: Text(
                        '${c.phone} • Баллы: ${c.pointsBalance.toStringAsFixed(2)}'
                        '${c.cardCode != null && c.cardCode!.isNotEmpty ? ' • Карта: ${c.cardCode}' : ''}',
                      ),
                      trailing: c.tier != null ? Text(c.tier!.title) : null,
                      onTap: c.isBlacklisted
                          ? null
                          : () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _LoyaltyCustomerCreateDialog extends StatefulWidget {
  const _LoyaltyCustomerCreateDialog();

  @override
  State<_LoyaltyCustomerCreateDialog> createState() =>
      _LoyaltyCustomerCreateDialogState();
}

class _LoyaltyCustomerCreateDialogState
    extends State<_LoyaltyCustomerCreateDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _siteQrCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = TjPhoneDialLockedFormatter.ensureStored(_phoneCtrl.text);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cardCtrl.dispose();
    _siteQrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = TjPhoneDialLockedFormatter.ensureStored(_phoneCtrl.text);
    if (phone.isEmpty) {
      setState(() => _error = 'Телефон обязателен');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalLoyaltyRepository>();
      final customer = await repo.createCustomer(
        phone: phone,
        fullName: _nameCtrl.text.trim(),
        cardCode: _cardCtrl.text.trim().isEmpty ? null : _cardCtrl.text.trim(),
        qrCode: _siteQrCtrl.text.trim().isEmpty ? null : _siteQrCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(customer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Новый клиент'),
      content: SizedBox(
        width: _dialogWidth(context, 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Имя (если пусто: Новый клиент)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: const [TjPhoneDialLockedFormatter()],
              decoration: InputDecoration(
                labelText: 'Телефон *',
                hintText: '$kDefaultPhoneDialPrefix…',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardCtrl,
              decoration: const InputDecoration(
                labelText: 'Код карты (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _siteQrCtrl,
              decoration: const InputDecoration(
                labelText: 'Код с сайта donerkebab.tj (необязательно)',
                hintText: 'DK-… из личного кабинета на сайте',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }
}

/// Цифровая клавиатура как на экране «Наличные».
class _PosMoneyKeypad extends StatelessWidget {
  const _PosMoneyKeypad({
    required this.onDigit,
    required this.onDot,
    required this.onBackspace,
    this.onExact,
    this.onClear,
    this.exactLabel = 'Ровно',
  });

  final void Function(String digit) onDigit;
  final VoidCallback onDot;
  final VoidCallback onBackspace;
  final VoidCallback? onExact;
  final VoidCallback? onClear;
  final String exactLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digitStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
              FilledButton.tonal(
                onPressed: () => onDigit(d),
                child: Text(d, style: digitStyle),
              ),
            FilledButton.tonal(
              onPressed: onDot,
              child: Text('.', style: digitStyle),
            ),
            FilledButton.tonal(
              onPressed: () => onDigit('0'),
              child: Text('0', style: digitStyle),
            ),
            FilledButton.tonal(
              onPressed: onBackspace,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        if (onExact != null || onClear != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (onExact != null)
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onExact,
                    child: Text(exactLabel),
                  ),
                ),
              if (onExact != null && onClear != null) const SizedBox(width: 8),
              if (onClear != null)
                Expanded(
                  child: TextButton(
                    onPressed: onClear,
                    child: const Text('Очистить'),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MoneyRawInputController {
  String raw = '';

  double get value => _parseMoneyInput(raw) ?? 0.0;

  void appendDigit(String digit) {
    if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
    if (raw == '0') {
      raw = digit;
    } else {
      raw += digit;
    }
  }

  void appendDot() {
    if (raw.contains('.')) return;
    raw = raw.isEmpty ? '0.' : '$raw.';
  }

  void backspace() {
    if (raw.isEmpty) return;
    raw = raw.substring(0, raw.length - 1);
  }

  void clear() => raw = '';

  void setValue(double amount) {
    raw = amount.toStringAsFixed(2);
  }

  String get display => raw.isEmpty ? '0' : raw;
}

Future<_CashPaymentDraft?> _pickCashReceived(
  BuildContext context, {
  required double total,
}) {
  return showDialog<_CashPaymentDraft>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      final input = _MoneyRawInputController();
      return StatefulBuilder(
        builder: (context, setState) {
          final received = input.value;
          final change = received - total;
          final canAccept = received >= total && received > 0;

          return AlertDialog(
            backgroundColor: scheme.surfaceContainerLow,
            title: Text(
              'Наличные',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: _dialogWidth(context, 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Сумма к оплате: ${formatSomoni(total)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Получено от клиента',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      input.display,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PosMoneyKeypad(
                    onDigit: (d) => setState(() => input.appendDigit(d)),
                    onDot: () => setState(() => input.appendDot()),
                    onBackspace: () => setState(() => input.backspace()),
                    onExact: () => setState(() => input.setValue(total)),
                    onClear: () => setState(() => input.clear()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    change < 0
                        ? 'Не хватает: ${formatSomoni(change.abs())}'
                        : 'Сдача: ${formatSomoni(change)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: change < 0
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: canAccept
                    ? () => Navigator.of(ctx).pop(
                        _CashPaymentDraft(
                          received: received,
                          change: change < 0 ? 0 : change,
                        ),
                      )
                    : null,
                child: const Text('Подтвердить'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<_MixedPaymentDraft?> _pickMixedPayment(
  BuildContext context, {
  required double total,
}) async {
  final methods = await context
      .read<LocalPaymentMethodsRepository>()
      .fetchMethods();
  final banks = methods.where((m) => m.isActive && m.isBank).toList(growable: false);
  if (!context.mounted) return null;
  if (banks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Нет активных банков. Добавьте способы оплаты в настройках.'),
      ),
    );
    return null;
  }

  return showDialog<_MixedPaymentDraft>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      var step = 0;
      final cashInput = _MoneyRawInputController();
      final receivedInput = _MoneyRawInputController();
      LocalPaymentMethod? selectedBank;
      double savedCashAmount = 0;

      return StatefulBuilder(
        builder: (context, setState) {
          final cashAmount = cashInput.value;
          final received = receivedInput.raw.isEmpty ? cashAmount : receivedInput.value;
          final bankAmount = (total - savedCashAmount).clamp(0.0, total).toDouble();
          final change = received - savedCashAmount;

          final canNextFromCash = cashAmount > 0 && cashAmount < total - 0.009;
          final canNextFromReceived =
              received >= savedCashAmount - 0.009 && received > 0;
          final canConfirm = selectedBank != null && bankAmount > 0.009;

          String stepTitle() => switch (step) {
            0 => 'Смешанная — наличными',
            1 => 'Смешанная — получено',
            _ => 'Смешанная — банк',
          };

          Widget stepBody() {
            if (step == 0) {
              final previewBank = (total - cashAmount).clamp(0.0, total).toDouble();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Сумма к оплате: ${formatSomoni(total)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Наличными по счёту',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      cashInput.display,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PosMoneyKeypad(
                    onDigit: (d) => setState(() => cashInput.appendDigit(d)),
                    onDot: () => setState(() => cashInput.appendDot()),
                    onBackspace: () => setState(() => cashInput.backspace()),
                    onClear: () => setState(() => cashInput.clear()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cashAmount > 0 && cashAmount < total
                        ? 'На банк: ${formatSomoni(previewBank)}'
                        : 'Введите сумму меньше итога — остаток уйдёт на банк',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cashAmount > 0 && cashAmount < total
                          ? const Color(0xFF2E7D32)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }
            if (step == 1) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Наличными по счёту: ${formatSomoni(savedCashAmount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'На банк: ${formatSomoni(bankAmount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1565C0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Получено от клиента',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      receivedInput.raw.isEmpty
                          ? savedCashAmount.toStringAsFixed(2)
                          : receivedInput.display,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PosMoneyKeypad(
                    onDigit: (d) => setState(() => receivedInput.appendDigit(d)),
                    onDot: () => setState(() => receivedInput.appendDot()),
                    onBackspace: () => setState(() => receivedInput.backspace()),
                    onExact: () => setState(() => receivedInput.setValue(savedCashAmount)),
                    onClear: () => setState(() => receivedInput.clear()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    change < 0
                        ? 'Не хватает: ${formatSomoni(change.abs())}'
                        : 'Сдача: ${formatSomoni(change < 0 ? 0 : change)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: change < 0
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Итого: ${formatSomoni(total)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Наличные ${formatSomoni(savedCashAmount)} • Банк ${formatSomoni(bankAmount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Куда перевести остаток',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: banks
                      .map(
                        (bank) => _PaymentPickTile(
                          label: bank.title,
                          icon: Icons.account_balance_rounded,
                          onTap: () => setState(() => selectedBank = bank),
                          selected: selectedBank?.id == bank.id,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: scheme.surfaceContainerLow,
            title: Text(
              stepTitle(),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            content: SizedBox(
              width: _dialogWidth(context, 420),
              child: stepBody(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (step == 0) {
                    Navigator.of(ctx).pop();
                  } else {
                    setState(() => step -= 1);
                  }
                },
                child: Text(step == 0 ? 'Отмена' : 'Назад'),
              ),
              if (step < 2)
                FilledButton(
                  onPressed: (step == 0 && canNextFromCash) ||
                          (step == 1 && canNextFromReceived)
                      ? () {
                          setState(() {
                            if (step == 0) {
                              savedCashAmount = cashAmount;
                              receivedInput.clear();
                              step = 1;
                            } else {
                              step = 2;
                            }
                          });
                        }
                      : null,
                  child: const Text('Далее'),
                )
              else
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.of(ctx).pop(
                          _MixedPaymentDraft(
                            cashAmount: savedCashAmount,
                            bankMethod: selectedBank!,
                            bankAmount: bankAmount,
                            cashReceived: received,
                            cashChange: change < 0 ? 0 : change,
                          ),
                        )
                      : null,
                  child: const Text('Подтвердить'),
                ),
            ],
          );
        },
      );
    },
  );
}

double _dialogWidth(BuildContext context, double preferred) {
  return math.min(preferred, MediaQuery.sizeOf(context).width * 0.94);
}

class _PaymentPickTile extends StatelessWidget {
  const _PaymentPickTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Итог проведения оплаты на кассе (печать чека выполняется локальным сервером вместе с оплатой).
final class PayPosOrderOutcome {
  const PayPosOrderOutcome({required this.paid, this.paymentMethodTitle});

  final bool paid;
  final String? paymentMethodTitle;
}

/// Оплата заказа по `orderId`: те же диалоги, что у открытого счёта (способ, скидки, наличные).
///
/// Используется для заказов на экране кассира и для счетов по столам ([payOpenBill]).
Future<PayPosOrderOutcome> payPosOrderAtCashier(
  BuildContext context, {
  required String orderId,
  required double orderTotal,
  required String paidSummarySubject,
}) async {
  if (!context.mounted) {
    return const PayPosOrderOutcome(paid: false);
  }
  final canProcessPayments =
      context.read<AuthBloc>().state.user?.canProcessPosPayments == true;
  if (!canProcessPayments) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оплату может принимать только касса')),
    );
    return const PayPosOrderOutcome(paid: false);
  }
  final paymentDiscount = _orderPaymentAdjustmentsById[orderId];
  final payableTotal = paymentDiscount?.payableAmount ?? orderTotal;
  LocalPaymentMethod? method;
  try {
    method = await _pickPaymentMethod(context);
  } catch (e) {
    if (!context.mounted) {
      return const PayPosOrderOutcome(paid: false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось загрузить способы оплаты: $e')),
    );
    return const PayPosOrderOutcome(paid: false);
  }
  if (!context.mounted || method == null) {
    return const PayPosOrderOutcome(paid: false);
  }
  _CashPaymentDraft? cashDraft;
  _MixedPaymentDraft? mixedDraft;
  if (method.code == 'mixed') {
    mixedDraft = await _pickMixedPayment(context, total: payableTotal);
    if (!context.mounted || mixedDraft == null) {
      return const PayPosOrderOutcome(paid: false);
    }
  } else if (method.isCash) {
    cashDraft = await _pickCashReceived(context, total: payableTotal);
    if (!context.mounted || cashDraft == null) {
      return const PayPosOrderOutcome(paid: false);
    }
  }
  await Future<void>.delayed(Duration.zero);
  if (!context.mounted) {
    return const PayPosOrderOutcome(paid: false);
  }
  final skipReceipt = await _pickReceiptChoice(context);
  if (!context.mounted || skipReceipt == null) {
    return const PayPosOrderOutcome(paid: false);
  }
  final progressOverlay = _showBlockingPaymentOverlay(
    context,
    skipReceipt: skipReceipt,
  );
  late final _PaymentAttemptResult paymentResult;
  try {
    paymentResult = mixedDraft != null
        ? await _runMixedLocalPayment(
            context,
            orderId: orderId,
            total: payableTotal,
            mixed: mixedDraft,
            discountDraft: paymentDiscount,
            skipReceipt: skipReceipt,
          )
        : await _runLocalPayment(
            context,
            orderId: orderId,
            total: payableTotal,
            paymentMethod: method,
            cashDraft: cashDraft,
            discountDraft: paymentDiscount,
            skipReceipt: skipReceipt,
          );
  } finally {
    progressOverlay?.close();
  }
  if (paymentResult.accepted) {
    _orderPaymentAdjustmentsById.remove(orderId);
  }
  if (!paymentResult.accepted) {
    if (!context.mounted) {
      return const PayPosOrderOutcome(paid: false);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Оплата не подтверждена: ${paymentResult.message ?? "ошибка сервера оплаты"}',
        ),
      ),
    );
    return const PayPosOrderOutcome(paid: false);
  }
  if (!context.mounted) {
    return PayPosOrderOutcome(
      paid: true,
      paymentMethodTitle: mixedDraft?.summaryTitle ?? method.title,
    );
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        [
          'Оплачено: $paidSummarySubject • ${formatSomoni(orderTotal)} • ${mixedDraft?.summaryTitle ?? method.title}',
          if (skipReceipt) 'Без печати чека',
          if (mixedDraft != null) mixedDraft.summaryTitle,
          if (cashDraft != null)
            'Получено ${formatSomoni(cashDraft.received)}, сдача ${formatSomoni(cashDraft.change)}',
          if (paymentDiscount != null && paymentDiscount.totalDiscount > 0)
            'Скидка ${formatSomoni(paymentDiscount.totalDiscount)} (${formatSomoni(orderTotal)} -> ${formatSomoni(payableTotal)})',
          if (paymentResult.message != null &&
              paymentResult.message!.isNotEmpty)
            paymentResult.message!,
        ].join(' • '),
      ),
    ),
  );
  if (paymentResult.retryPrintAvailable) {
    _showHardwareRetrySnackBar(
      context,
      orderId: paymentResult.retryOrderId,
      total: paymentResult.retryTotal,
      paymentMethod: paymentResult.retryPaymentMethod,
      errorMessage: paymentResult.hardwareErrorMessage,
    );
  }
  return PayPosOrderOutcome(
    paid: true,
    paymentMethodTitle: mixedDraft?.summaryTitle ?? method.title,
  );
}

/// Оплата открытого счёта со списка столов.
Future<void> payOpenBill(
  BuildContext context, {
  required PosTableBill bill,
}) async {
  if (bill.isPaid || !context.mounted) return;
  final outcome = await payPosOrderAtCashier(
    context,
    orderId: bill.id,
    orderTotal: bill.total,
    paidSummarySubject: bill.tableSummary,
  );
  if (!outcome.paid || !context.mounted) return;
  context.read<PosHallOrdersCubit>().markPaid(
    bill.id,
    paymentMethod: outcome.paymentMethodTitle,
  );
}

Future<_PaymentAttemptResult> _runMixedLocalPayment(
  BuildContext context, {
  required String orderId,
  required double total,
  required _MixedPaymentDraft mixed,
  _PaymentDiscountDraft? discountDraft,
  bool skipReceipt = false,
}) async {
  final repo = context.read<LocalPaymentsRepository>();
  final idempotencyKey = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
  final splits = <Map<String, dynamic>>[
    {
      'paymentMethod': 'cash',
      'amount': mixed.cashAmount,
      if (mixed.cashReceived != null) 'cashReceived': mixed.cashReceived,
      if (mixed.cashChange != null) 'cashChange': mixed.cashChange,
    },
    {
      'paymentMethod': mixed.bankMethod.code,
      'amount': mixed.bankAmount,
      if (mixed.bankMethod.id != null) 'paymentMethodId': mixed.bankMethod.id,
    },
  ];
  try {
    final result = await repo.acceptPayment(
      orderId: orderId,
      amount: total,
      paymentMethod: 'mixed',
      idempotencyKey: idempotencyKey,
      paymentSplits: splits,
      promoCode: discountDraft?.promoCode,
      promoDiscountAmount: discountDraft?.promoDiscountAmount,
      loyaltyDiscountAmount: discountDraft?.loyaltyDiscountAmount,
      loyaltyCardNo: discountDraft?.loyaltyCardNo,
      customerId: discountDraft?.customerId,
      skipReceipt: skipReceipt,
    );
    final hardwareHint = result.hardware?.buildHint();
    final baseMessage = result.idempotent
        ? 'Смешанная оплата уже была подтверждена ранее'
        : 'Смешанная оплата подтверждена';
    return _PaymentAttemptResult(
      accepted: true,
      message: (hardwareHint != null && hardwareHint.isNotEmpty)
          ? '$baseMessage • $hardwareHint'
          : baseMessage,
      retryPrintAvailable: !skipReceipt &&
          result.hardware?.attempted == true &&
          (result.hardware?.error?.trim().isNotEmpty == true),
      hardwareErrorMessage: result.hardware?.error,
      retryOrderId: orderId,
      retryTotal: total,
      retryPaymentMethod: 'mixed',
    );
  } on ApiException catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.message);
  } catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.toString());
  }
}

Future<_PaymentAttemptResult> _runLocalPayment(
  BuildContext context, {
  required String orderId,
  required double total,
  required LocalPaymentMethod paymentMethod,
  _CashPaymentDraft? cashDraft,
  _PaymentDiscountDraft? discountDraft,
  bool skipReceipt = false,
}) async {
  final repo = context.read<LocalPaymentsRepository>();
  final method = paymentMethod.isCash ? 'cash' : paymentMethod.code;
  final idempotencyKey = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
  try {
    final result = await repo.acceptPayment(
      orderId: orderId,
      amount: total,
      paymentMethod: method,
      paymentMethodId: paymentMethod.id,
      idempotencyKey: idempotencyKey,
      cashReceived: cashDraft?.received,
      cashChange: cashDraft?.change,
      promoCode: discountDraft?.promoCode,
      promoDiscountAmount: discountDraft?.promoDiscountAmount,
      loyaltyDiscountAmount: discountDraft?.loyaltyDiscountAmount,
      loyaltyCardNo: discountDraft?.loyaltyCardNo,
      customerId: discountDraft?.customerId,
      skipReceipt: skipReceipt,
    );
    final hardwareHint = result.hardware?.buildHint();
    final baseMessage = result.idempotent
        ? 'Оплата уже была подтверждена ранее'
        : 'Оплата подтверждена локальным сервером';
    return _PaymentAttemptResult(
      accepted: true,
      message: (hardwareHint != null && hardwareHint.isNotEmpty)
          ? '$baseMessage • $hardwareHint'
          : baseMessage,
      retryPrintAvailable: !skipReceipt &&
          result.hardware?.attempted == true &&
          (result.hardware?.error?.trim().isNotEmpty == true),
      hardwareErrorMessage: result.hardware?.error,
      retryOrderId: orderId,
      retryTotal: total,
      retryPaymentMethod: method,
    );
  } on ApiException catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.message);
  } catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.toString());
  }
}

_BlockingPaymentOverlayHandle? _showBlockingPaymentOverlay(
  BuildContext context, {
  bool skipReceipt = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final entry = OverlayEntry(
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: Material(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      skipReceipt
                          ? 'Подтверждаем оплату...'
                          : 'Подтверждаем оплату и печатаем чек...',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  overlay.insert(entry);
  return _BlockingPaymentOverlayHandle(entry);
}

class _BlockingPaymentOverlayHandle {
  const _BlockingPaymentOverlayHandle(this._entry);

  final OverlayEntry _entry;

  void close() {
    _entry.remove();
  }
}

void _showHardwareRetrySnackBar(
  BuildContext context, {
  required String orderId,
  required double total,
  required String paymentMethod,
  String? errorMessage,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final err = (errorMessage ?? '').trim();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        err.isNotEmpty ? 'Печать не выполнена: $err' : 'Печать не выполнена',
      ),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Повторить печать',
        onPressed: () {
          unawaited(
            retryPosReceiptPrint(
              context,
              orderId: orderId,
              total: total,
              paymentMethod: paymentMethod,
            ),
          );
        },
      ),
    ),
  );
}

/// Повторная печать фискального чека по уже оплаченному заказу (локальный сервер печати).
Future<void> retryPosReceiptPrint(
  BuildContext context, {
  required String orderId,
  required double total,
  required String paymentMethod,
}) async {
  try {
    final repo = context.read<LocalHardwareRepository>();
    final receipt = await repo.printReceipt(
      orderId: orderId,
      totalAmount: total,
      paymentMethod: paymentMethod,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Чек напечатан: № ${receipt.receiptNumber} (${receipt.mode})',
        ),
      ),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Повтор печати не удался: ${e.message}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Повтор печати не удался: $e')));
  }
}

Future<_OrderSyncResult> _syncLocalOrder(
  BuildContext context, {
  required String orderId,
  required CartState cart,
  required String orderTypeLabel,
  required PosTableZone? tableZone,
  required int? tableNumber,
  Map<String, int>? appendBaselineQtyByLineKey,
}) async {
  final repo = context.read<LocalOrdersRepository>();

  final List<LocalOrderLineInput> lines;
  final baseline = appendBaselineQtyByLineKey;
  if (baseline != null && baseline.isNotEmpty) {
    final cartQtyByKey = <String, int>{
      for (final l in cart.sortedLines) l.lineKey: l.quantity,
    };
    var didPatch = false;
    for (final e in baseline.entries) {
      final lineKey = e.key;
      final baseQty = e.value;
      final cartQty = cartQtyByKey[lineKey] ?? 0;
      if (cartQty < baseQty) {
        String? menuItemId;
        for (final l in cart.sortedLines) {
          if (l.lineKey == lineKey) {
            menuItemId = l.item.id;
            break;
          }
        }
        menuItemId ??= lineKey.split('::').first;
        final mid = menuItemId;
        if (mid == null || mid.isEmpty) continue;
        try {
          await repo.patchOrderLineQuantity(
            orderId: orderId,
            menuItemId: mid,
            quantity: cartQty,
          );
          didPatch = true;
        } on ApiException catch (e) {
          return _OrderSyncResult(
            synced: false,
            message: e.message,
          );
        } catch (e) {
          return _OrderSyncResult(
            synced: false,
            message: e.toString(),
          );
        }
      }
    }
    lines = [];
    for (final line in cart.sortedLines) {
      final baseQty = baseline[line.lineKey] ?? 0;
      final delta = line.quantity - baseQty;
      if (delta > 0) {
        lines.add(
          LocalOrderLineInput(
            menuItemId: line.item.id,
            quantity: delta,
            unitPrice: line.item.price,
            lineKey: line.lineKey,
            modifiers: line.modifiers.map((m) => m.toJson()).toList(),
          ),
        );
      } else if (delta < 0) {
        return _OrderSyncResult(
          synced: false,
          message:
              'Несогласованное состояние корзины: повторите после обновления.',
        );
      }
    }
    if (lines.isEmpty && !didPatch) {
      return _OrderSyncResult(
        synced: false,
        message:
            'Нет изменений для сохранения: добавьте позиции или уменьшите количество по счёту.',
      );
    }
  } else {
    lines = cart.sortedLines
        .map(
          (l) => LocalOrderLineInput(
            menuItemId: l.item.id,
            quantity: l.quantity,
            unitPrice: l.item.price,
            lineKey: l.lineKey,
            modifiers: l.modifiers.map((m) => m.toJson()).toList(),
          ),
        )
        .toList(growable: false);
  }

  final tableLabel = tableNumber != null
      ? (tableZone != null
            ? '${tableZone.shortLabel} • стол $tableNumber'
            : 'Стол $tableNumber')
      : null;

  try {
    if (lines.isNotEmpty) {
      final result = await repo.createOrUpdateOrder(
        orderId: orderId,
        lines: lines,
        totalAmount: cart.total,
        orderType: orderTypeLabel,
        tableLabel: tableLabel,
      );
      return _OrderSyncResult(
        synced: true,
        message: result.created
            ? 'Локальный заказ создан: ${result.number}'
            : 'Локальный заказ обновлен: ${result.number}',
      );
    }
    if (appendBaselineQtyByLineKey != null &&
        appendBaselineQtyByLineKey.isNotEmpty) {
      return const _OrderSyncResult(
        synced: true,
        message: 'Счёт обновлён на сервере',
      );
    }
    return const _OrderSyncResult(
      synced: false,
      message: 'Нет позиций для синхронизации',
    );
  } on ApiException catch (e) {
    return _OrderSyncResult(
      synced: false,
      message: 'Локальный заказ: ${e.message}',
    );
  } catch (e) {
    return _OrderSyncResult(
      synced: false,
      message: 'Локальный заказ: ${e.toString()}',
    );
  }
}

class _PaymentAttemptResult {
  const _PaymentAttemptResult({
    required this.accepted,
    required this.message,
    this.retryPrintAvailable = false,
    this.hardwareErrorMessage,
    this.retryOrderId = '',
    this.retryTotal = 0,
    this.retryPaymentMethod = 'card',
  });

  final bool accepted;
  final String? message;
  final bool retryPrintAvailable;
  final String? hardwareErrorMessage;
  final String retryOrderId;
  final double retryTotal;
  final String retryPaymentMethod;
}

class _OrderSyncResult {
  const _OrderSyncResult({required this.synced, required this.message});

  final bool synced;
  final String? message;
}
