import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';

/// Результат смены типа заказа.
class PosChangeOrderTypeResult {
  const PosChangeOrderTypeResult({
    required this.orderTypeLabel,
    this.tableLabel = '',
    this.tableNumber,
    this.tableZone,
    this.tableCleared = false,
    this.noop = false,
  });

  final String orderTypeLabel;
  final String tableLabel;
  final int? tableNumber;
  final PosTableZone? tableZone;
  final bool tableCleared;
  final bool noop;
}

const kPosOrderTypeLabels = ['С собой', 'На месте', 'Доставка'];

String normalizePosOrderTypeLabel(String? raw) {
  final l = (raw ?? '').toLowerCase().trim();
  if (l.contains('доставк') || l.contains('delivery')) return 'Доставка';
  if (l.contains('самовывоз') ||
      l.contains('с собой') ||
      l.contains('pickup') ||
      l.contains('takeaway') ||
      l.contains('to_go') ||
      l.contains('парковк') ||
      l.contains('parking')) {
    return 'С собой';
  }
  if (l.contains('на месте') ||
      l.contains('dine') ||
      l.contains('зал') ||
      l.contains('onsite') ||
      l.contains('on_site')) {
    return 'На месте';
  }
  return (raw ?? '').trim().isEmpty ? 'С собой' : raw!.trim();
}

/// Диалог выбора типа + PATCH. На кухню уходит через backend WS.
Future<PosChangeOrderTypeResult?> changePosOrderType(
  BuildContext context, {
  required String orderId,
  String? currentOrderType,
  String? currentTableLabel,
}) async {
  final current = normalizePosOrderTypeLabel(currentOrderType);
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Способ заказа'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Сейчас: $current',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final label in kPosOrderTypeLabels)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: label == current
                        ? theme.colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(label),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Text(
              '«С собой» и «Доставка» снимают стол. «На месте» — укажите стол отдельно.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
  if (picked == null || !context.mounted) return null;
  if (picked == current) {
    return PosChangeOrderTypeResult(
      orderTypeLabel: current,
      tableLabel: currentTableLabel ?? '',
      noop: true,
    );
  }

  try {
    final repo = context.read<LocalOrdersRepository>();
    final result = await repo.updateOrderType(
      orderId: orderId,
      orderType: picked,
    );
    if (!context.mounted) return null;

    final serverType =
        normalizePosOrderTypeLabel(result.orderType ?? picked);
    final serverLabel = (result.tableLabel ?? '').trim();
    final cleared = serverLabel.isEmpty &&
        (picked == 'С собой' || picked == 'Доставка');
    final parsed = parsePosTableLabel(serverLabel);

    try {
      context.read<PosHallOrdersCubit>().updateBillOrderType(
            orderId: orderId,
            orderTypeLabel: serverType,
            tableLabel: serverLabel,
            tableNumber: parsed.number,
            tableZone: parsed.zone,
            clearTable: cleared || serverLabel.isEmpty,
          );
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Тип заказа: $serverType')),
    );

    return PosChangeOrderTypeResult(
      orderTypeLabel: serverType,
      tableLabel: serverLabel,
      tableNumber: parsed.number,
      tableZone: parsed.zone,
      tableCleared: cleared || serverLabel.isEmpty,
      noop: result.noop,
    );
  } catch (e) {
    if (!context.mounted) return null;
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return null;
  }
}
