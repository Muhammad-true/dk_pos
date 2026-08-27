import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/domain/pos_table_label_parse.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_checkout_flow.dart';

/// Результат смены стола для локального UI.
class PosChangeTableResult {
  const PosChangeTableResult({
    required this.tableLabel,
    this.tableNumber,
    this.tableZone,
    this.orderTypeLabel,
    this.cleared = false,
    this.noop = false,
  });

  final String tableLabel;
  final int? tableNumber;
  final PosTableZone? tableZone;
  /// Если при назначении стола «с собой» стало «На месте».
  final String? orderTypeLabel;
  final bool cleared;
  final bool noop;
}

bool posOrderLooksLikeDeliveryForTableChange({
  String? orderType,
  String? tableLabel,
}) {
  final t = (orderType ?? '').toLowerCase();
  final l = (tableLabel ?? '').toLowerCase();
  if (t.contains('доставк') || t.contains('delivery')) return true;
  if (l.contains('доставк') || l.contains('delivery')) return true;
  return false;
}

/// Снять метку стола (освободить) — тот же PATCH clearTable, без диалога выбора.
Future<PosChangeTableResult?> clearPosOrderTable(
  BuildContext context, {
  required String orderId,
}) async {
  try {
    final repo = context.read<LocalOrdersRepository>();
    final result = await repo.updateOrderTable(
      orderId: orderId,
      clearTable: true,
    );
    if (!context.mounted) return null;
    try {
      context.read<PosHallOrdersCubit>().updateBillTable(
            orderId: orderId,
            tableLabel: '',
            tableNumber: null,
            tableZone: null,
          );
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Стол освобождён')),
    );
    return PosChangeTableResult(
      tableLabel: '',
      cleared: true,
      noop: result.noop,
    );
  } catch (e) {
    if (!context.mounted) return null;
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return null;
  }
}

/// Диалог выбора + PATCH. Занятый стол не выбирается (snackbar).
Future<PosChangeTableResult?> changePosOrderTable(
  BuildContext context, {
  required String orderId,
  String? currentTableLabel,
  int? currentTableNumber,
  PosTableZone? currentTableZone,
  String? orderType,
}) async {
  if (posOrderLooksLikeDeliveryForTableChange(
    orderType: orderType,
    tableLabel: currentTableLabel,
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('У доставки стол не назначается')),
    );
    return null;
  }

  final parsedCurrent = parsePosTableLabel(currentTableLabel ?? '');
  final currentKey = (currentTableZone ?? parsedCurrent.zone) != null &&
          (currentTableNumber ?? parsedCurrent.number) != null
      ? (currentTableZone ?? parsedCurrent.zone)!
          .occupiedKey(currentTableNumber ?? parsedCurrent.number!)
      : null;

  final pick = await showPosTablePickDialog(
    context,
    allowSkipTable: true,
    title: currentKey == null ? 'Указать стол' : 'Куда перенести?',
    subtitle: currentKey == null
        ? 'Гость ещё без стола — выберите место. Занятые столы недоступны.'
        : 'Выберите свободный стол или освободите текущий. Занятые помечены.',
    currentOccupiedKey: currentKey,
    blockOccupied: true,
    skipTableLabel: currentKey == null ? 'Стол позже' : 'Освободить стол',
  );
  if (pick == null || !context.mounted) return null;

  final clear = pick is PosTablePickSkipTable;
  String nextLabel = '';
  int? nextNumber;
  PosTableZone? nextZone;
  if (pick is PosTablePickChosen) {
    nextNumber = pick.number;
    nextZone = pick.zone;
    nextLabel = '${pick.zone.shortLabel} • стол ${pick.number}';
  }

  try {
    final repo = context.read<LocalOrdersRepository>();
    final result = await repo.updateOrderTable(
      orderId: orderId,
      tableLabel: clear ? null : nextLabel,
      clearTable: clear,
    );
    if (!context.mounted) return null;

    final serverLabel = (result.tableLabel ?? nextLabel).trim();
    final parsed = parsePosTableLabel(serverLabel);
    final zone = parsed.zone ?? nextZone;
    final number = parsed.number ?? nextNumber;

    final orderTypeLabel = (result.orderType ?? '').trim().isEmpty
        ? (!clear && serverLabel.isNotEmpty ? 'На месте' : null)
        : result.orderType!.trim();

    if (context.mounted) {
      try {
        context.read<PosHallOrdersCubit>().updateBillTable(
              orderId: orderId,
              tableLabel: serverLabel,
              tableNumber: number,
              tableZone: zone,
              orderTypeLabel: orderTypeLabel,
            );
      } catch (_) {}
    }

    final summary = clear || serverLabel.isEmpty
        ? 'Стол снят'
        : 'Стол: ${zone != null && number != null ? '${zone.shortLabel} • стол $number' : serverLabel}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary)));

    return PosChangeTableResult(
      tableLabel: serverLabel,
      tableNumber: number,
      tableZone: zone,
      orderTypeLabel: orderTypeLabel,
      cleared: clear || serverLabel.isEmpty,
      noop: result.noop,
    );
  } catch (e) {
    if (!context.mounted) return null;
    final msg = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return null;
  }
}
