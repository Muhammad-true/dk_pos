import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/pos/presentation/utils/cashier_table_headline.dart';

/// Диалог «История» заказа: смена стола и др. события.
Future<void> showPosOrderHistoryDialog(
  BuildContext context, {
  required String orderId,
  String? orderNumber,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => _PosOrderHistoryDialog(
      orderId: orderId,
      orderNumber: orderNumber,
    ),
  );
}

class _PosOrderHistoryDialog extends StatefulWidget {
  const _PosOrderHistoryDialog({
    required this.orderId,
    this.orderNumber,
  });

  final String orderId;
  final String? orderNumber;

  @override
  State<_PosOrderHistoryDialog> createState() => _PosOrderHistoryDialogState();
}

class _PosOrderHistoryDialogState extends State<_PosOrderHistoryDialog> {
  bool _loading = true;
  String? _error;
  List<LocalOrderEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await context
          .read<LocalOrdersRepository>()
          .fetchOrderEvents(widget.orderId);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _formatWhen(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$min';
  }

  String _displayTable(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Без стола';
    return cashierTableHeadline(t);
  }

  String _eventTitle(LocalOrderEvent e) {
    if (e.eventType == 'table_changed') {
      if (e.cleared) {
        return 'Стол снят';
      }
      if (e.fromLabel.isEmpty && e.toLabel.isNotEmpty) {
        return 'Стол назначен';
      }
      return 'Смена стола';
    }
    return e.eventType;
  }

  String _eventBody(LocalOrderEvent e) {
    if (e.eventType == 'table_changed') {
      final from = _displayTable(e.fromLabel);
      final to = _displayTable(e.toLabel);
      if (e.cleared) {
        return e.fromLabel.isEmpty ? 'Стол освобождён' : 'Было: $from';
      }
      if (e.fromLabel.isEmpty) {
        return to;
      }
      return '$from → $to';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final compact = WindowLayout(width: w).isCompact;
    final numLabel = (widget.orderNumber ?? '').trim();

    return AlertDialog(
      backgroundColor: scheme.surfaceContainerLow,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: 24,
      ),
      title: Text(
        numLabel.isEmpty ? 'История заказа' : 'История · № $numLabel',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: compact ? w - 48 : 420,
        height: compact ? 360 : 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('Повторить'),
                      ),
                    ],
                  )
                : _events.isEmpty
                    ? Center(
                        child: Text(
                          'Пока нет записей о смене стола',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final e = _events[_events.length - 1 - i];
                          final when = _formatWhen(e.createdAtIso);
                          final who = e.actorUsername;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              e.eventType == 'table_changed'
                                  ? Icons.table_restaurant_rounded
                                  : Icons.history_rounded,
                              color: scheme.primary,
                            ),
                            title: Text(
                              _eventTitle(e),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_eventBody(e)),
                                if (when.isNotEmpty || who.isNotEmpty)
                                  Text(
                                    [
                                      if (when.isNotEmpty) when,
                                      if (who.isNotEmpty) who,
                                    ].join(' · '),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: when.isNotEmpty || who.isNotEmpty,
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
  }
}
