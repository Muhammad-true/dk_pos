import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/payments/data/local_payments_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

/// Тип заказа в корзине POS (совпадает с выбором в панели корзины).
enum PosCheckoutOrderType {
  takeAway,
  dineIn,
  delivery,
}

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
  final effectiveOrderType =
      effectiveWaiterMode ? PosCheckoutOrderType.dineIn : orderType;
  final effectiveOrderTypeLabel = _orderTypeLabelForSync(
    effectiveOrderType,
    waiterMode: effectiveWaiterMode,
  );

  int? tableNumber;
  PosTableZone? tableZone;

  if (effectiveWaiterMode) {
    final outcome = await showPosTablePickDialog(context, allowSkipTable: false);
    if (!context.mounted) return;
    if (outcome is! PosTablePickChosen) return;
    tableNumber = outcome.number;
    tableZone = outcome.zone;
  } else {
    if (effectiveOrderType == PosCheckoutOrderType.dineIn) {
      final outcome = await showPosTablePickDialog(context, allowSkipTable: true);
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

  String? paymentMethod;
  if (payNow) {
    paymentMethod = await _pickPaymentMethod(context);
    if (!context.mounted) return;
    if (paymentMethod == null) return;
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
  String? hardwareHint;
  String? paymentHint;
  String? orderHint = orderSync.message;
  var paymentAccepted = false;
  if (payNow) {
    final paymentResult = await _runLocalPayment(
      context,
      orderId: registered.id,
      total: registered.total,
      paymentMethodLabel: paymentMethod ?? '',
    );
    paymentAccepted = paymentResult.accepted;
    paymentHint = paymentResult.message;
    if (paymentAccepted) {
      if (!context.mounted) return;
      hall.markPaid(registered.id, paymentMethod: paymentMethod);
      hardwareHint = await _runHardwarePostPayment(
        context,
        orderId: registered.id,
        total: registered.total,
        paymentMethodLabel: paymentMethod ?? '',
      );
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
          if (hardwareHint != null && hardwareHint.isNotEmpty) hardwareHint,
        ].join(' • '),
      ),
    ),
  );
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

  static const hallTableCount = 16;
  static const verandaTableCount = 12;

  /// Первый номер на веранде (после последнего стола зала).
  static int get firstVerandaNumber => hallTableCount + 1;

  /// Последний стол в заведении (сквозная нумерация).
  static int get lastTableNumber => hallTableCount + verandaTableCount;

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
                  Icon(Icons.table_restaurant_rounded,
                      color: scheme.primary, size: 24),
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
                              ? 'Номера сквозные: зал 1–${_PickTableDialog.hallTableCount}, '
                                  'веранда ${_PickTableDialog.firstVerandaNumber}–${_PickTableDialog.lastTableNumber}. '
                                  'Можно оформить без стола — кнопка внизу.'
                              : 'Номера сквозные: зал 1–${_PickTableDialog.hallTableCount}, '
                                  'веранда ${_PickTableDialog.firstVerandaNumber}–${_PickTableDialog.lastTableNumber}. '
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
                      return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
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
                              const SizedBox(height: 14),
                              _ZoneTableGrid(
                                title: 'Веранда',
                                subtitle:
                                    'столы ${_PickTableDialog.firstVerandaNumber}–${_PickTableDialog.lastTableNumber}',
                                zone: PosTableZone.veranda,
                                firstTableNumber:
                                    _PickTableDialog.firstVerandaNumber,
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
                      onPressed: () => Navigator.of(context).pop(
                        PosTablePickSkipTable(),
                      ),
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
              ? [
                  const Color(0xFF3D3428),
                  scheme.surfaceContainerHigh,
                ]
              : [
                  const Color(0xFFFFF6EB),
                  const Color(0xFFF2E4D4),
                ],
          const Color(0xFFB8956C),
          isDark ? const Color(0xFFD4A574) : const Color(0xFFC47A3A),
          const Color(0xFFB8956C),
        ),
      PosTableZone.veranda => (
          isDark
              ? [
                  const Color(0xFF1E3532),
                  scheme.surfaceContainerHigh,
                ]
              : [
                  const Color(0xFFEEF9F6),
                  const Color(0xFFD8EEE8),
                ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
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
          width: 400,
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

Future<String?> _pickPaymentMethod(BuildContext context) {
  return showDialog<String>(
    context: context,
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
          width: 460,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _PaymentPickTile(
                label: 'Наличными',
                icon: Icons.payments_rounded,
                onTap: () => Navigator.of(ctx).pop('Наличными'),
              ),
              _PaymentPickTile(
                label: 'Карта',
                icon: Icons.credit_card_rounded,
                onTap: () => Navigator.of(ctx).pop('Карта'),
              ),
              _PaymentPickTile(
                label: 'Онлайн перевод',
                icon: Icons.phone_iphone_rounded,
                onTap: () => Navigator.of(ctx).pop('Онлайн перевод'),
              ),
              _PaymentPickTile(
                label: 'ДС',
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => Navigator.of(ctx).pop('ДС'),
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
  final method = await _pickPaymentMethod(context);
  if (!context.mounted || method == null) return;
  final paymentResult = await _runLocalPayment(
    context,
    orderId: bill.id,
    total: bill.total,
    paymentMethodLabel: method,
  );
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
  context.read<PosHallOrdersCubit>().markPaid(bill.id, paymentMethod: method);
  final hardwareHint = await _runHardwarePostPayment(
    context,
    orderId: bill.id,
    total: bill.total,
    paymentMethodLabel: method,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        [
          'Оплачено: ${bill.tableSummary} • ${formatSomoni(bill.total)} • $method',
          if (paymentResult.message != null && paymentResult.message!.isNotEmpty)
            paymentResult.message!,
          if (hardwareHint != null && hardwareHint.isNotEmpty) hardwareHint,
        ].join(' • '),
      ),
    ),
  );
}

Future<_PaymentAttemptResult> _runLocalPayment(
  BuildContext context, {
  required String orderId,
  required double total,
  required String paymentMethodLabel,
}) async {
  final repo = context.read<LocalPaymentsRepository>();
  final method = _normalizePaymentMethod(paymentMethodLabel);
  final idempotencyKey = '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
  try {
    final result = await repo.acceptPayment(
      orderId: orderId,
      amount: total,
      paymentMethod: method,
      idempotencyKey: idempotencyKey,
    );
    return _PaymentAttemptResult(
      accepted: true,
      message: result.idempotent
          ? 'Оплата уже была подтверждена ранее'
          : 'Оплата подтверждена локальным сервером',
    );
  } on ApiException catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.message);
  } catch (e) {
    return _PaymentAttemptResult(accepted: false, message: e.toString());
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
      ? (tableZone != null ? '${tableZone.shortLabel} • стол $tableNumber' : 'Стол $tableNumber')
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
    return _OrderSyncResult(synced: false, message: 'Локальный заказ: ${e.message}');
  } catch (e) {
    return _OrderSyncResult(synced: false, message: 'Локальный заказ: ${e.toString()}');
  }
}

Future<String?> _runHardwarePostPayment(
  BuildContext context, {
  required String orderId,
  required double total,
  required String paymentMethodLabel,
}) async {
  final repo = context.read<LocalHardwareRepository>();
  final method = _normalizePaymentMethod(paymentMethodLabel);
  try {
    final receipt = await repo.printReceipt(
      orderId: orderId,
      totalAmount: total,
      paymentMethod: method,
    );

    if (_isCashMethod(method)) {
      await repo.openDrawer(paymentMethod: method);
      return 'Чек: ${receipt.receiptNumber}, касса открыта (${receipt.mode})';
    }
    return 'Чек: ${receipt.receiptNumber} (${receipt.mode})';
  } on ApiException catch (e) {
    return 'Оборудование: ${e.message}';
  } catch (e) {
    return 'Оборудование: ${e.toString()}';
  }
}

String _normalizePaymentMethod(String label) {
  final v = label.trim().toLowerCase();
  if (v.contains('нал')) return 'cash';
  if (v.contains('кар')) return 'card';
  if (v.contains('онлайн')) return 'online';
  if (v == 'дс') return 'ds';
  return 'card';
}

bool _isCashMethod(String paymentMethod) => paymentMethod == 'cash';

class _PaymentAttemptResult {
  const _PaymentAttemptResult({
    required this.accepted,
    required this.message,
  });

  final bool accepted;
  final String? message;
}

class _OrderSyncResult {
  const _OrderSyncResult({
    required this.synced,
    required this.message,
  });

  final bool synced;
  final String? message;
}
