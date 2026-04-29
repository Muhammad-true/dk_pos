import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

import 'pos_checkout_flow.dart';

bool _isWaiterOrderLabel(String value) {
  final v = value.trim().toLowerCase();
  return v.contains('официант') || v.contains('waiter');
}

Future<void> showOpenTableBillsDialog(BuildContext context) {
  final cubit = context.read<PosHallOrdersCubit>();
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: cubit,
        child: const _OpenBillsDialog(),
      );
    },
  );
}

class _OpenBillsDialog extends StatelessWidget {
  const _OpenBillsDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, state) {
        final open = state.openBills;

        return AlertDialog(
          backgroundColor: scheme.surfaceContainerLow,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Открытые счета по столам',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Данные с сервера по филиалу: любой неоплаченный заказ с меткой стола '
                '(касса, официант, другой терминал или старый тест). Не макет приложения.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: math.min(440, MediaQuery.sizeOf(context).width * 0.94),
            height: math.min(420, MediaQuery.sizeOf(context).height * 0.76),
            child: open.isEmpty
                ? Center(
                    child: Text(
                      'По филиалу нет неоплаченных счетов со столом в базе.\n'
                      'Свой новый счёт появится здесь после оформления с привязкой к столу '
                      '(у официанта — всегда со столом).',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: open.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final bill = open[i];
                      return _BillListTile(
                        bill: bill,
                        onOpen: () => _showBillDetail(context, bill),
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

class _BillListTile extends StatelessWidget {
  const _BillListTile({required this.bill, required this.onOpen});

  final PosTableBill bill;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final zone = bill.tableZone;
    final waiterOrder = _isWaiterOrderLabel(bill.orderTypeLabel);
    final zoneAccent = switch (zone) {
      PosTableZone.hall => const Color(0xFFB8956C),
      PosTableZone.veranda => const Color(0xFF2D8B7E),
      null => scheme.primary,
    };

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                child: Icon(
                  zone == PosTableZone.veranda
                      ? Icons.deck_rounded
                      : Icons.table_restaurant_rounded,
                  color: zoneAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.tableSummary,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bill.lines.length} поз. • ${bill.orderTypeLabel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (waiterOrder) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.room_service_rounded,
                              size: 13,
                              color: scheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Официант',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

Future<void> _showBillDetail(BuildContext outerContext, PosTableBill bill) {
  final canProcessPayments = outerContext
          .read<AuthBloc>()
          .state
          .user
          ?.canProcessPosPayments ==
      true;
  return showDialog<void>(
    context: outerContext,
    useRootNavigator: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;

      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(
          bill.tableSummary,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: math.min(400, MediaQuery.sizeOf(ctx).width * 0.94),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bill.orderTypeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...bill.lines.map(
                (l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.quantity}× ${l.name}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatSomoni(l.lineTotal),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
                    formatSomoni(bill.total),
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Назад'),
          ),
          if (canProcessPayments)
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await payOpenBill(outerContext, bill: bill);
                if (!outerContext.mounted) return;
                final stillOpen = outerContext
                    .read<PosHallOrdersCubit>()
                    .state
                    .openBills;
                if (stillOpen.isEmpty) {
                  Navigator.of(outerContext).pop();
                }
              },
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Оплатить'),
            )
          else
            FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Оплата только на кассе'),
            ),
        ],
      );
    },
  );
}
