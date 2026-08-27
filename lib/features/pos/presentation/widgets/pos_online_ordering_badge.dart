import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/pos/data/local_online_ordering_repository.dart';

/// Индикатор приёма онлайн-заказов + пауза + напоминание перед закрытием.
class PosOnlineOrderingBadge extends StatefulWidget {
  const PosOnlineOrderingBadge({super.key, this.compact = true});

  final bool compact;

  @override
  State<PosOnlineOrderingBadge> createState() => _PosOnlineOrderingBadgeState();
}

class _PosOnlineOrderingBadgeState extends State<PosOnlineOrderingBadge> {
  OnlineOrderingStatus? _status;
  Timer? _timer;
  bool _busy = false;
  bool _closeHintShown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final repo = context.read<LocalOnlineOrderingRepository>();
      final s = await repo.fetchStatus();
      if (!mounted) return;
      setState(() => _status = s);
      _maybeRemindClose(s);
    } catch (_) {}
  }

  void _maybeRemindClose(OnlineOrderingStatus? s) {
    if (s == null || _closeHintShown) return;
    final m = s.minutesUntilClose;
    if (m == null || m > 30 || m < 0) return;
    if (!s.asapAvailable) return;
    _closeHintShown = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'До конца онлайн-приёма ~$m мин (${s.workingHours}). '
          'Можно поставить паузу без закрытия смены.',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Пауза',
          onPressed: () => unawaited(_setPaused(true)),
        ),
      ),
    );
  }

  Future<void> _setPaused(bool paused) async {
    setState(() => _busy = true);
    try {
      await context.read<LocalOnlineOrderingRepository>().setPaused(paused);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paused ? 'Онлайн-заказы на паузе' : 'Приём онлайн снова открыт'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSheet() async {
    await _refresh();
    if (!mounted) return;
    final s = _status;
    final role = context.read<AuthBloc>().state.user?.role;
    final canPause = role == 'admin' || role == 'cashier';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Онлайн-заказы',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(s?.shortLabel ?? 'Нет данных'),
                if (s != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (s.paused) 'Пауза включена',
                      'Смена: ${s.shiftOpen ? "открыта" : "закрыта"}',
                      'Касса на связи: ${s.posOnline ? "да" : "нет"}',
                      'В часах: ${s.withinHours ? "да" : "нет"}',
                      if (s.workingHours.isNotEmpty) 'Часы: ${s.workingHours}',
                      if (s.closedMessage.isNotEmpty) s.closedMessage,
                    ].join('\n'),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
                if (canPause) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await _setPaused(!(s?.paused ?? false));
                          },
                    child: Text(
                      (s?.paused ?? false)
                          ? 'Снять паузу онлайн'
                          : 'Поставить паузу онлайн',
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final scheme = Theme.of(context).colorScheme;
    final ok = s?.asapAvailable == true;
    final warn = s != null && !ok && s.scheduledAvailable;
    final color = s == null
        ? scheme.outline
        : ok
            ? scheme.primary
            : warn
                ? scheme.tertiary
                : scheme.error;

    return IconButton(
      tooltip: s?.shortLabel ?? 'Онлайн-заказы',
      onPressed: _busy ? null : _openSheet,
      icon: Badge(
        isLabelVisible: s?.paused == true || (s != null && !s.available),
        smallSize: 8,
        backgroundColor: color,
        child: Icon(
          ok
              ? Icons.cloud_done_rounded
              : warn
                  ? Icons.schedule_rounded
                  : Icons.cloud_off_rounded,
          color: color,
        ),
      ),
    );
  }
}
