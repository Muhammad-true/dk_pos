import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';
import 'package:dk_pos/features/shifts/data/shift_close_preflight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Подтверждение закрытия смены и проверка незавершённых заказов.
///
/// [strictOrders] — для кассы/кассира: нельзя закрыть, пока есть заказы не в «Выдан».
/// [checkOpenCashShift] — при выходе кассира: напомнить закрыть кассовую смену.
Future<bool> confirmShiftCloseAllowed(
  BuildContext context, {
  required String title,
  String? confirmMessage,
  bool strictOrders = true,
  bool checkOpenCashShift = false,
}) async {
  final wantsClose = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        confirmMessage ??
            'После закрытия смены учёт времени остановится. Продолжить?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Нет, ещё работаем'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Да, закрыть'),
        ),
      ],
    ),
  );
  if (wantsClose != true || !context.mounted) return false;

  if (checkOpenCashShift) {
    try {
      final snap = await context.read<LocalCashRepository>().fetchActiveShift();
      if (snap.hasOpenShift && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Кассовая смена открыта'),
            content: const Text(
              'Сначала закройте кассовую смену: кошелёк на кассе → «Закрыть смену» '
              '(пересчёт ящика). После этого можно выходить.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
        return false;
      }
    } catch (_) {
      // Не блокируем выход при ошибке сети.
    }
  }

  if (!strictOrders) return true;

  try {
    final pre = await context.read<ShiftClosePreflightRepository>().fetchPreflight();
    if (!context.mounted) return false;
    if (!pre.canClose && pre.openOrders.isNotEmpty) {
      if (!context.mounted) return false;
      await showOpenOrdersBlockingDialog(context, pre);
      return false;
    }
    return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return false;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
    return false;
  }
}

Future<void> showOpenOrdersBlockingDialog(
  BuildContext context,
  ShiftClosePreflight pre,
) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Нельзя закрыть смену'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pre.hint ??
                  'Есть заказы, которые ещё не выданы. Сначала отметьте их как «Выдан» '
                  'или отмените.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Незавершённых: ${pre.blockingCount}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: pre.openOrders.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (_, i) {
                  final o = pre.openOrders[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          o.displayTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        o.statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Понятно, доработаем'),
        ),
      ],
    ),
  );
}

/// Выход: смена сотрудника + проверки по роли.
Future<bool> confirmLogoutWithShiftChecks(
  BuildContext context, {
  required String role,
}) async {
  final isCashRole = role == 'cashier' || role == 'admin';
  return confirmShiftCloseAllowed(
    context,
    title: 'Закрыть смену и выйти?',
    confirmMessage: isCashRole
        ? 'Все заказы на точке должны быть выданы или отменены. '
            'Закрыть вашу смену и выйти из программы?'
        : 'Закрыть вашу смену и выйти из программы?',
    strictOrders: isCashRole,
    checkOpenCashShift: isCashRole,
  );
}
