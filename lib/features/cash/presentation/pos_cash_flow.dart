import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/cash/presentation/cash_shift_report_dialog.dart';
import 'package:dk_pos/features/shifts/data/shift_close_preflight.dart';
import 'package:dk_pos/features/shifts/presentation/shift_close_guard.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_numeric_keypad.dart';

Future<void> showPosCashManagementDialog(BuildContext context) async {
  final shiftWasClosed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _PosCashManagementDialog(),
  );
  if (shiftWasClosed == true && context.mounted) {
    await ensureCashShiftOpen(context);
  }
}

enum _OpenCashShiftResult { opened, logout }

Future<bool> ensureCashShiftOpen(BuildContext context) async {
  final repo = context.read<LocalCashRepository>();
  while (context.mounted) {
    try {
      final snap = await repo.fetchActiveShift();
      if (snap.hasOpenShift) return true;
    } on ApiException catch (e) {
      if (e.statusCode == 423 && context.mounted) {
        final logout = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Касса занята'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Проверить снова'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Выйти'),
              ),
            ],
          ),
        );
        if (logout == true && context.mounted) {
          await performPosSessionLogout(context, cashShiftNeverOpened: true);
          return false;
        }
        continue;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Касса: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Касса: $e')),
        );
      }
    }
    if (!context.mounted) return false;
    final result = await showDialog<_OpenCashShiftResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _OpenCashShiftDialog(mandatory: true),
    );
    if (result == _OpenCashShiftResult.opened) return true;
    if (result == _OpenCashShiftResult.logout) {
      if (context.mounted) {
        await performPosSessionLogout(context, cashShiftNeverOpened: true);
      }
      return false;
    }
  }
  return false;
}

class _PosCashManagementDialog extends StatefulWidget {
  const _PosCashManagementDialog();

  @override
  State<_PosCashManagementDialog> createState() => _PosCashManagementDialogState();
}

class _PosCashManagementDialogState extends State<_PosCashManagementDialog> {
  CashShiftSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await context.read<LocalCashRepository>().fetchActiveShift();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _isAdmin {
    final role = (context.read<AuthBloc>().state.user?.role ?? '')
        .trim()
        .toLowerCase();
    return role == 'admin';
  }

  Future<void> _openShiftFlow() async {
    final result = await showDialog<_OpenCashShiftResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _OpenCashShiftDialog(mandatory: true),
    );
    if (result == _OpenCashShiftResult.opened) {
      await _reload();
    } else if (result == _OpenCashShiftResult.logout && mounted) {
      Navigator.of(context).pop();
      if (context.mounted) {
        await performPosSessionLogout(context, cashShiftNeverOpened: true);
      }
    }
  }

  Future<void> _encashmentFlow() async {
    final snap = _snapshot;
    if (snap == null || !snap.hasOpenShift) return;
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EncashmentDialog(snapshot: snap),
    );
    if (done == true && mounted) await _reload();
  }

  Future<void> _closeShiftFlow() async {
    final snap = _snapshot;
    if (snap == null || !snap.hasOpenShift) return;
    if (!mounted) return;

    final available = snap.availableCash;
    if (available > 0.009) {
      final goEncash = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Инкассация не сделана'),
          content: Text(
            'По учёту сверх размена доступно ${formatSomoni(available)}. '
            'Если закрыть смену сейчас, эти деньги останутся в ящике '
            'и перейдут на следующую смену.\n\n'
            'Сначала сделайте инкассацию (пересчёт → в сейф, размен останется), '
            'либо закройте без неё, если нал должен остаться.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Закрыть без инкассации'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Инкассация'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (goEncash == null) return;
      if (goEncash == true) {
        await _encashmentFlow();
        return;
      }
    }

    final allowed = await confirmShiftCloseAllowed(
      context,
      title: 'Закрыть кассовую смену?',
      confirmMessage:
          'Все заказы должны быть выданы или отменены. '
          'Данные по учёту уйдут в global; сверку «по факту» сделаете в админке.',
      strictOrders: true,
    );
    if (!allowed || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CloseCashShiftDialog(isAdmin: _isAdmin),
    );
    if (ok == true) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = _snapshot;

    return AlertDialog(
      title: const Text('Касса'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text(_error!, style: TextStyle(color: theme.colorScheme.error))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snap != null && snap.hasOpenShift) ...[
                    if (_isAdmin) ...[
                      _CashMetricRow(
                        label: 'Выручка нал',
                        value: formatSomoni(snap.cashSalesIn),
                      ),
                      if ((snap.encashmentHint?.recommendedAmount ?? 0) > 0.009 ||
                          snap.operationsOut > 0.009)
                        _CashMetricRow(
                          label: 'Выемки (в т.ч. инкассация)',
                          value: '−${formatSomoni(snap.operationsOut)}',
                        ),
                      _CashMetricRow(
                        label: 'По расчёту в ящике',
                        value: formatSomoni(snap.expectedInDrawer),
                        bold: true,
                        subtitle: 'Это ожидаемый факт при закрытии',
                      ),
                      _CashMetricRow(
                        label: 'Доступно к инкассации',
                        value: formatSomoni(snap.availableCash),
                        subtitle:
                            'Резерв ${formatSomoni(snap.minReserve)} не трогаем',
                      ),
                    ] else ...[
                      Text(
                        'Смена открыта. Перед закрытием сделайте инкассацию, '
                        'если нал нужно убрать в сейф (размен останется в ящике).',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Принятие смены и деньги на баланс — в глобальной админке.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ] else
                    const Text(
                      'Кассовая смена не открыта. Нажмите «Открыть смену».',
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (snap?.hasOpenShift != true)
                        FilledButton.icon(
                          onPressed: _openShiftFlow,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Открыть смену'),
                        )
                      else ...[
                        FilledButton.icon(
                          onPressed: _encashmentFlow,
                          icon: const Icon(Icons.savings_outlined),
                          label: const Text('Инкассация'),
                        ),
                        FilledButton.tonal(
                          onPressed: _closeShiftFlow,
                          child: const Text('Закрыть смену'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : _reload,
          child: const Text('Обновить'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _CashMetricRow extends StatelessWidget {
  const _CashMetricRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.bold = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OpenCashShiftDialog extends StatefulWidget {
  const _OpenCashShiftDialog({this.mandatory = false});

  /// На кассе смену нельзя пропустить без открытия.
  final bool mandatory;

  @override
  State<_OpenCashShiftDialog> createState() => _OpenCashShiftDialogState();
}

class _OpenCashShiftDialogState extends State<_OpenCashShiftDialog> {
  bool _busy = false;
  bool _loadingInfo = true;
  String? _error;
  double? _carriedOver;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final suggestion = await context.read<LocalCashRepository>().fetchOpeningSuggestion();
      if (!mounted) return;
      setState(() {
        _carriedOver = suggestion.suggestedOpeningBalance;
        _loadingInfo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInfo = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LocalCashRepository>().openCashShift();
      if (!mounted) return;
      Navigator.of(context).pop(_OpenCashShiftResult.opened);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    Navigator.of(context).pop(_OpenCashShiftResult.logout);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !widget.mandatory,
      child: AlertDialog(
        title: const Text('Открыть смену'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Смена откроется без пересчёта ящика. '
              'Чтобы убрать нал в сейф — Касса → «Инкассация» '
              '(пересчёт; размен останется в ящике).',
            ),
            if (widget.mandatory) ...[
              const SizedBox(height: 8),
              Text(
                'Или выйдите, чтобы войти под другим пользователем.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (_loadingInfo)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_carriedOver != null && _carriedOver! > 0.009)
              Text(
                'В учёте на начало: ${formatSomoni(_carriedOver!)} (остаток с прошлого закрытия).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (widget.mandatory)
            TextButton.icon(
              onPressed: _busy ? null : _logout,
              icon: Icon(Icons.logout_rounded, color: scheme.error),
              label: Text('Выход', style: TextStyle(color: scheme.error)),
            )
          else
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(null),
              child: const Text('Отмена'),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Открыть смену'),
          ),
        ],
      ),
    );
  }
}

class _CloseCashShiftDialog extends StatefulWidget {
  const _CloseCashShiftDialog({
    required this.isAdmin,
  });

  final bool isAdmin;

  @override
  State<_CloseCashShiftDialog> createState() => _CloseCashShiftDialogState();
}

class _CloseCashShiftDialogState extends State<_CloseCashShiftDialog> {
  final _notesCtrl = TextEditingController();
  bool _busy = false;
  bool _loading = true;
  String? _error;
  CashCloseShiftPreview? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final preview =
          await context.read<LocalCashRepository>().fetchCloseShiftPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || !preview.hasOpenShift) {
      setState(() => _error = 'Кассовая смена не открыта');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Без «по факту»: только закрытие + отправка учёта в global.
      final result = await context.read<LocalCashRepository>().closeCashShift(
        closeNotes: _notesCtrl.text,
      );
      if (!mounted) return;

      if (!result.closed) {
        setState(() {
          _error = result.message ?? 'Не удалось закрыть смену';
          _busy = false;
        });
        return;
      }

      if (result.report != null && widget.isAdmin) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CashShiftReportDialog(
            report: result.report!,
            globalSync: result.globalSync,
          ),
        );
      } else {
        final msg = result.message ?? 'Смена закрыта. Данные отправлены в global.';
        final syncMsg = result.globalSync?.message;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                syncMsg != null && syncMsg.isNotEmpty ? '$msg\n$syncMsg' : msg,
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.rawBody is Map) {
        final map = Map<String, dynamic>.from(e.rawBody as Map);
        if (map['openOrders'] is List) {
          final pre = ShiftClosePreflight.fromJson(map);
          await showOpenOrdersBlockingDialog(context, pre);
          setState(() => _busy = false);
          return;
        }
      }
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Закрыть кассовую смену'),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Закроем смену и отправим учёт в global. '
                    'Факт по налу введёте при принятии смены в админке.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 14),
                    _CashMetricRow(
                      label: 'Выручка нал (учёт)',
                      value: formatSomoni(preview.cashSalesIn),
                    ),
                    if (preview.encashmentDone)
                      _CashMetricRow(
                        label: 'Инкассация',
                        value: '−${formatSomoni(preview.encashmentTotal)}',
                      )
                    else
                      _CashMetricRow(
                        label: 'Инкассация',
                        value: 'не было',
                      ),
                    if (preview.openingBalance > 0.009)
                      _CashMetricRow(
                        label: 'Остаток на открытии',
                        value: formatSomoni(preview.openingBalance),
                      ),
                    _CashMetricRow(
                      label: 'В ящике по учёту (факт)',
                      value: formatSomoni(preview.expectedInDrawer),
                      bold: true,
                      subtitle: preview.encashmentDone
                          ? 'Нал продажи минус инкассация'
                          : 'Без инкассации = вся выручка нал (+остаток)',
                    ),
                    if (preview.banks.isNotEmpty)
                      _CashMetricRow(
                        label: 'Безнал по учёту',
                        value: formatSomoni(preview.nonCashExpectedTotal),
                      ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || _loading ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Закрыть смену'),
        ),
      ],
    );
  }
}

double? _parseCashAmount(String raw) {
  final t = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Пересчёт ящика → в сейф всё сверх резерва размена.
class _EncashmentDialog extends StatefulWidget {
  const _EncashmentDialog({required this.snapshot});

  final CashShiftSnapshot snapshot;

  @override
  State<_EncashmentDialog> createState() => _EncashmentDialogState();
}

class _EncashmentDialogState extends State<_EncashmentDialog> {
  late final TextEditingController _countCtrl;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expected = widget.snapshot.expectedInDrawer;
    _countCtrl = TextEditingController();
    if (expected > 0.009) {
      posMoneySetAmount(_countCtrl, expected);
    }
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  double get _reserve => widget.snapshot.minReserve;

  double? get _counted => _parseCashAmount(_countCtrl.text);

  double? get _toSafe {
    final counted = _counted;
    if (counted == null) return null;
    final v = counted - _reserve;
    return v > 0.009 ? v : 0;
  }

  Future<void> _submit() async {
    final counted = _counted;
    if (counted == null || counted < 0) {
      setState(() => _error = 'Укажите, сколько наличных в ящике');
      return;
    }
    if (counted + 0.009 < _reserve) {
      setState(
        () => _error =
            'В ящике меньше резерва размена (${formatSomoni(_reserve)})',
      );
      return;
    }
    final toSafe = _toSafe ?? 0;
    if (toSafe <= 0.009) {
      setState(() => _error = 'Нечего инкассировать после резерва');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().postEncashment(
        countedInDrawer: counted,
        reconcileSurplus: true,
      );
      if (!mounted) return;
      final msg =
          'В сейф: ${formatSomoni(result.operation.amount)}. '
          'В ящике остаётся размен ~${formatSomoni(_reserve)}.';
      final hw = result.hardwareHint;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hw != null && hw.isNotEmpty ? '$msg\n$hw' : msg)),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = widget.snapshot;
    final toSafe = _toSafe;
    final hint = snap.encashmentHint;

    return AlertDialog(
      title: const Text('Инкассация'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Пересчитайте нал в ящике. В сейф уйдёт сумма сверх размена '
                '(${formatSomoni(_reserve)} останется в кассе).',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'По учёту в ящике: ${formatSomoni(snap.expectedInDrawer)}',
                style: theme.textTheme.bodySmall,
              ),
              if (hint != null && hint.recommendedAmount > 0.009) ...[
                const SizedBox(height: 2),
                Text(
                  'Рекомендуется в сейф: ${formatSomoni(hint.recommendedAmount)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              PosMoneyKeypadInput(
                controller: _countCtrl,
                label: 'Нал в ящике (факт)',
                presetAmount: snap.expectedInDrawer > 0.009
                    ? snap.expectedInDrawer
                    : null,
                presetLabel: 'По учёту',
                onChanged: () => setState(() {}),
              ),
              if (toSafe != null) ...[
                const SizedBox(height: 10),
                Text(
                  toSafe > 0.009
                      ? 'В сейф: ${formatSomoni(toSafe)}'
                      : 'После резерва инкассировать нечего',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('В сейф'),
        ),
      ],
    );
  }
}
