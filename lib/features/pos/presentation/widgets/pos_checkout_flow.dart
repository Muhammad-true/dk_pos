import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/constants/phone_defaults.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/payments/data/local_payments_repository.dart';
import 'package:dk_pos/features/payments/data/local_payment_methods_repository.dart';
import 'package:dk_pos/features/loyalty/data/local_loyalty_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

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

/// Оформление: стол (для «На месте»), оплата сейчас или позже, затем счёт и очистка корзины.
Future<void> runPosCheckoutFlow(
  BuildContext context, {
  required PosCheckoutOrderType orderType,
  required CartState cart,
  bool waiterMode = false,
}) async {
  if (cart.isEmpty || !context.mounted) return;
  final user = context.read<AuthBloc>().state.user;
  final isWaiter = user?.isWaiter == true;
  final effectiveWaiterMode = waiterMode || isWaiter;
  final effectiveOrderType = orderType;
  final effectiveOrderTypeLabel = _orderTypeLabelForSync(
    effectiveOrderType,
    waiterMode: effectiveWaiterMode,
  );

  int? tableNumber;
  PosTableZone? tableZone;

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

  bool payNow = false;
  if (!effectiveWaiterMode) {
    final timing = await _pickPayTiming(context);
    if (!context.mounted) return;
    if (timing == null) return;
    payNow = timing;
  }

  LocalPaymentMethod? paymentMethod;
  _PaymentDiscountDraft? paymentDiscount;
  var payableTotal = cart.total;
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
    paymentDiscount = await _pickPaymentDiscounts(context, total: cart.total);
    if (!context.mounted || paymentDiscount == null) return;
    payableTotal = paymentDiscount.payableAmount;
  }
  _CashPaymentDraft? cashDraft;
  if (payNow && paymentMethod != null && paymentMethod.isCash) {
    cashDraft = await _pickCashReceived(context, total: payableTotal);
    if (!context.mounted || cashDraft == null) return;
  }

  final lines = cart.sortedLines
      .map(
        (l) => PosTableBillLine(
          name: l.item.name,
          quantity: l.quantity,
          lineTotal: l.lineTotal,
        ),
      )
      .toList(growable: false);

  PosTableBill? openBillBefore;
  if (tableNumber != null && tableZone != null) {
    openBillBefore = context.read<PosHallOrdersCubit>().findOpenBillForTable(
      number: tableNumber,
      zone: tableZone,
    );
  }

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

  final hall = context.read<PosHallOrdersCubit>();
  final cartBloc = context.read<CartBloc>();
  final registered = hall.registerOrMergeBill(bill);
  final orderSync = await _syncLocalOrder(
    context,
    orderId: registered.id,
    cart: cart,
    orderTypeLabel: effectiveOrderTypeLabel,
    tableZone: tableZone,
    tableNumber: tableNumber,
  );
  if (!context.mounted) return;
  String? paymentHint;
  String? orderHint = orderSync.message;
  var paymentAccepted = false;
  _PaymentAttemptResult? paymentResult;
  if (payNow) {
    final progressOverlay = _showBlockingPaymentOverlay(context);
    try {
      paymentResult = await _runLocalPayment(
        context,
        orderId: registered.id,
        total: payableTotal,
        paymentMethod: paymentMethod!,
        cashDraft: cashDraft,
        discountDraft: paymentDiscount,
      );
    } finally {
      progressOverlay?.close();
    }
    paymentAccepted = paymentResult.accepted;
    paymentHint = paymentResult.message;
    if (paymentAccepted) {
      if (!context.mounted) return;
      hall.markPaid(registered.id, paymentMethod: paymentMethod.title);
    }
  }
  cartBloc.add(const CartCleared());

  if (!context.mounted) return;
  final merged = openBillBefore != null;
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
          if (orderHint != null && orderHint.isNotEmpty) orderHint,
          if (paymentHint != null && paymentHint.isNotEmpty) paymentHint,
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

Future<LocalPaymentMethod?> _pickPaymentMethod(BuildContext context) async {
  final methods = await context
      .read<LocalPaymentMethodsRepository>()
      .fetchMethods();
  final visible = methods.where((m) => m.isActive).toList(growable: false);
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
            children: visible
                .map(
                  (method) => _PaymentPickTile(
                    label: method.title,
                    icon: method.isCash
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

class _PaymentDiscountDraft {
  const _PaymentDiscountDraft({
    required this.baseTotal,
    required this.promoCode,
    required this.promoDiscountAmount,
    required this.loyaltyDiscountAmount,
    required this.loyaltyCardNo,
    this.customer,
  });

  final double baseTotal;
  final String promoCode;
  final double promoDiscountAmount;
  final double loyaltyDiscountAmount;
  final String loyaltyCardNo;
  final LoyaltyCustomer? customer;

  int? get customerId => customer?.id;

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
      title: Text(
        'Скидки',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            _promoCodeCtrl.clear();
            _promoDiscountCtrl.clear();
            _loyaltyCardCtrl.clear();
            _loyaltyDiscountCtrl.clear();
            _selectedCustomer = null;
            setState(() {});
          },
          child: const Text('Без скидки'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                  _PaymentDiscountDraft(
                    baseTotal: widget.total,
                    promoCode: _promoCodeCtrl.text.trim(),
                    promoDiscountAmount: promoDiscount,
                    loyaltyDiscountAmount: loyaltyDiscount,
                    loyaltyCardNo: _loyaltyCardCtrl.text.trim().isNotEmpty
                        ? _loyaltyCardCtrl.text.trim()
                        : (_selectedCustomer?.cardCode ?? ''),
                    customer: _selectedCustomer,
                  ),
                )
              : null,
          child: const Text('Применить'),
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
    _phoneCtrl.text = kDefaultPhoneDialPrefix;
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
    final phone = _phoneCtrl.text.trim();
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
      String rawInput = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final received = _parseMoneyInput(rawInput) ?? 0.0;
          final change = received - total;
          final canAccept = received >= total && received > 0;

          void appendDigit(String digit) {
            if (!RegExp(r'^[0-9]$').hasMatch(digit)) return;
            if (rawInput == '0') {
              rawInput = digit;
            } else {
              rawInput += digit;
            }
            setState(() {});
          }

          void appendDot() {
            if (rawInput.contains('.')) return;
            if (rawInput.isEmpty) {
              rawInput = '0.';
            } else {
              rawInput = '$rawInput.';
            }
            setState(() {});
          }

          void backspace() {
            if (rawInput.isEmpty) return;
            rawInput = rawInput.substring(0, rawInput.length - 1);
            setState(() {});
          }

          void clearAll() {
            rawInput = '';
            setState(() {});
          }

          void setExact() {
            rawInput = total.toStringAsFixed(2);
            setState(() {});
          }

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
                      rawInput.isEmpty ? '0' : rawInput,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                    children: [
                      for (final d in [
                        '1',
                        '2',
                        '3',
                        '4',
                        '5',
                        '6',
                        '7',
                        '8',
                        '9',
                      ])
                        FilledButton.tonal(
                          onPressed: () => appendDigit(d),
                          child: Text(
                            d,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      FilledButton.tonal(
                        onPressed: appendDot,
                        child: Text(
                          '.',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => appendDigit('0'),
                        child: Text(
                          '0',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: backspace,
                        child: const Icon(Icons.backspace_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: setExact,
                          child: const Text('Ровно'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: clearAll,
                          child: const Text('Очистить'),
                        ),
                      ),
                    ],
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

double _dialogWidth(BuildContext context, double preferred) {
  return math.min(preferred, MediaQuery.sizeOf(context).width * 0.94);
}

class _PaymentPickTile extends StatelessWidget {
  const _PaymentPickTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
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

/// Оплата открытого счёта со списка столов.
Future<void> payOpenBill(
  BuildContext context, {
  required PosTableBill bill,
}) async {
  if (bill.isPaid || !context.mounted) return;
  final canProcessPayments =
      context.read<AuthBloc>().state.user?.canProcessPosPayments == true;
  if (!canProcessPayments) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Оплату может принимать только касса')),
    );
    return;
  }
  LocalPaymentMethod? method;
  try {
    method = await _pickPaymentMethod(context);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось загрузить способы оплаты: $e')),
    );
    return;
  }
  if (!context.mounted || method == null) return;
  final paymentDiscount = await _pickPaymentDiscounts(
    context,
    total: bill.total,
  );
  if (!context.mounted || paymentDiscount == null) return;
  final payableTotal = paymentDiscount.payableAmount;
  _CashPaymentDraft? cashDraft;
  if (method.isCash) {
    cashDraft = await _pickCashReceived(context, total: payableTotal);
    if (!context.mounted || cashDraft == null) return;
  }
  final progressOverlay = _showBlockingPaymentOverlay(context);
  late final _PaymentAttemptResult paymentResult;
  try {
    paymentResult = await _runLocalPayment(
      context,
      orderId: bill.id,
      total: payableTotal,
      paymentMethod: method,
      cashDraft: cashDraft,
      discountDraft: paymentDiscount,
    );
  } finally {
    progressOverlay?.close();
  }
  if (!paymentResult.accepted) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Оплата не подтверждена: ${paymentResult.message ?? "ошибка сервера оплаты"}',
        ),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  context.read<PosHallOrdersCubit>().markPaid(
    bill.id,
    paymentMethod: method.title,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        [
          'Оплачено: ${bill.tableSummary} • ${formatSomoni(bill.total)} • ${method.title}',
          if (cashDraft != null)
            'Получено ${formatSomoni(cashDraft.received)}, сдача ${formatSomoni(cashDraft.change)}',
          if (paymentDiscount.totalDiscount > 0)
            'Скидка ${formatSomoni(paymentDiscount.totalDiscount)} (${formatSomoni(bill.total)} -> ${formatSomoni(payableTotal)})',
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
}

Future<_PaymentAttemptResult> _runLocalPayment(
  BuildContext context, {
  required String orderId,
  required double total,
  required LocalPaymentMethod paymentMethod,
  _CashPaymentDraft? cashDraft,
  _PaymentDiscountDraft? discountDraft,
}) async {
  final repo = context.read<LocalPaymentsRepository>();
  final method = paymentMethod.isCash ? 'cash' : 'bank';
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
      retryPrintAvailable:
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
  BuildContext context,
) {
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
                      'Подтверждаем оплату и печатаем чек...',
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
            _retryReceiptPrint(
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

Future<void> _retryReceiptPrint(
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
}) async {
  final repo = context.read<LocalOrdersRepository>();
  final lines = cart.sortedLines
      .map(
        (l) => LocalOrderLineInput(
          menuItemId: l.item.id,
          quantity: l.quantity,
          unitPrice: l.item.price,
        ),
      )
      .toList(growable: false);

  final tableLabel = tableNumber != null
      ? (tableZone != null
            ? '${tableZone.shortLabel} • стол $tableNumber'
            : 'Стол $tableNumber')
      : null;

  try {
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
