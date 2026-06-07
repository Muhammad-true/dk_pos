import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/cash/presentation/cash_shift_report_dialog.dart';
import 'package:dk_pos/features/shifts/data/shift_close_preflight.dart';
import 'package:dk_pos/features/shifts/presentation/shift_close_guard.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';

String _formatLastEncashmentLine(CashEncashmentHint hint) {
  final at = hint.lastEncashmentAt;
  if (at == null) return '';
  final dt = DateTime.tryParse(at)?.toLocal();
  final when = dt == null
      ? at
      : '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  final amt = hint.lastEncashmentAmount;
  if (amt != null && amt > 0) {
    return 'Последняя инкассация: $when, ${formatSomoni(amt)}';
  }
  return 'Последняя инкассация: $when';
}

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
    final role = _normalizedRole;
    return role == 'admin';
  }

  String get _normalizedRole =>
      (context.read<AuthBloc>().state.user?.role ?? '').trim().toLowerCase();

  bool _cashierMayRunOperation(String opType) {
    if (_isAdmin) return true;
    return opType == 'encashment';
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

  Future<void> _closeShiftFlow() async {
    final snap = _snapshot;
    if (snap == null || !snap.hasOpenShift) return;
    if (!mounted) return;
    final allowed = await confirmShiftCloseAllowed(
      context,
      title: 'Закрыть кассовую смену?',
      confirmMessage:
          'Все заказы должны быть выданы или отменены. Сверьте суммы по учёту '
          'и укажите по факту: нал в ящике и по каждому банку.',
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

  Future<void> _operationFlow(String opType) async {
    final snap = _snapshot;
    if (snap == null || !snap.hasOpenShift) {
      await _openShiftFlow();
      return;
    }
    if (!_cashierMayRunOperation(opType)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Эта операция доступна только администратору'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => opType == 'encashment'
          ? _EncashmentDialog(
              snapshot: snap,
              isAdmin: _isAdmin,
            )
          : _CashOperationDialog(
              opType: opType,
              availableCash: snap.availableCash,
              expectedInDrawer: snap.expectedInDrawer,
              minReserve: snap.minReserve,
            ),
    );
    if (ok == true) await _reload();
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
                        label: 'По расчёту в ящике',
                        value: formatSomoni(snap.expectedInDrawer),
                        bold: true,
                      ),
                      _CashMetricRow(
                        label: 'Доступно для оплаты',
                        value: formatSomoni(snap.availableCash),
                        subtitle:
                            'Резерв ${formatSomoni(snap.minReserve)} не трогаем',
                      ),
                      _CashMetricRow(
                        label: 'Наличные продажи',
                        value: formatSomoni(snap.cashSalesIn),
                      ),
                      _CashMetricRow(
                        label: 'Внесения / выемки',
                        value:
                            '+${formatSomoni(snap.operationsIn)} / −${formatSomoni(snap.operationsOut)}',
                      ),
                    ] else ...[
                      Text(
                        'К инкассации по расчёту: ${formatSomoni(snap.availableCash)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (snap.encashmentHint?.lastEncashmentAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatLastEncashmentLine(snap.encashmentHint!),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'В ящике остаётся резерв ${formatSomoni(snap.minReserve)}',
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
                        OutlinedButton(
                          onPressed: () => _operationFlow('encashment'),
                          child: const Text('Инкассация'),
                        ),
                        if (_isAdmin) ...[
                          OutlinedButton(
                            onPressed: () => _operationFlow('change_in'),
                            child: const Text('Внесение'),
                          ),
                          OutlinedButton(
                            onPressed: () => _operationFlow('off_register'),
                            child: const Text('Вне кассы'),
                          ),
                          OutlinedButton(
                            onPressed: () => _operationFlow('supplier_cash'),
                            child: const Text('Поставщику'),
                          ),
                          OutlinedButton(
                            onPressed: () => _operationFlow('owner_payout'),
                            child: const Text('Владельцу'),
                          ),
                          OutlinedButton(
                            onPressed: () => _operationFlow('rent_cash'),
                            child: const Text('Аренда'),
                          ),
                        ],
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
              'Сколько нал в кассе — укажете при закрытии смены и инкассации.',
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
  final _actualCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _bankCtrls = <String, TextEditingController>{};
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
      for (final bank in preview.banks) {
        _bankCtrls[bank.key] = TextEditingController();
      }
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

  double? _parseAmount(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _bankCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || !preview.hasOpenShift) {
      setState(() => _error = 'Кассовая смена не открыта');
      return;
    }
    final actual = _parseAmount(_actualCtrl.text);
    if (actual == null || actual < 0) {
      setState(() => _error = 'Укажите, сколько нал в ящике по факту');
      return;
    }
    final nonCashActual = <Map<String, dynamic>>[];
    for (final bank in preview.banks) {
      final ctrl = _bankCtrls[bank.key];
      final parsed = _parseAmount(ctrl?.text ?? '');
      if (parsed == null || parsed < 0) {
        setState(() => _error = 'Укажите, сколько на счету «${bank.title}» (можно 0)');
        return;
      }
      nonCashActual.add({'key': bank.key, 'actual': parsed});
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().closeCashShift(
        closingActual: actual,
        nonCashActual: nonCashActual,
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

      if (result.report != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CashShiftReportDialog(
            report: result.report!,
            globalSync: result.globalSync,
          ),
        );
      } else {
        final msg = result.message ??
            (result.variance != null
                ? (result.variance!.abs() < 0.01
                      ? 'Смена закрыта. Касса сошлась.'
                      : 'Смена закрыта. Разница нал: ${formatSomoni(result.variance!)}')
                : 'Смена закрыта.');
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

  Widget _reconcileRow({
    required ThemeData theme,
    required String title,
    required double expected,
    required TextEditingController actualCtrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'По учёту',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatSomoni(expected),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: actualCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'По факту',
                    hintText: '0',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Закрыть кассовую смену'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Слева — сумма по учёту POS, справа — введите по факту '
                      '(пересчёт ящика, отчёт терминала / приложения банка).',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Наличные в ящике',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (preview != null)
                      _reconcileRow(
                        theme: theme,
                        title: 'Наличные',
                        expected: preview.expectedInDrawer,
                        actualCtrl: _actualCtrl,
                      ),
                    if (preview != null && preview.banks.isEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        preview.nonCashExpectedTotal > 0.009
                            ? 'Безнал за смену есть, но банки не настроены. '
                                'Добавьте их в админке POS → Способы оплаты.'
                            : 'Банки не настроены (админка POS → Способы оплаты). '
                                'Безнал по банкам вводить не нужно.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: preview.nonCashExpectedTotal > 0.009
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else if (preview != null && preview.banks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '2. Безнал по банкам',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Банки из настроек оплаты. Итого по учёту: '
                        '${formatSomoni(preview.nonCashExpectedTotal)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      ...preview.banks.map((bank) {
                        final ctrl = _bankCtrls[bank.key];
                        if (ctrl == null) return const SizedBox.shrink();
                        return _reconcileRow(
                          theme: theme,
                          title: bank.title,
                          expected: bank.expectedNet,
                          actualCtrl: ctrl,
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий (если есть расхождение)',
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

class _EncashmentDialog extends StatefulWidget {
  const _EncashmentDialog({
    required this.snapshot,
    required this.isAdmin,
  });

  final CashShiftSnapshot snapshot;
  final bool isAdmin;

  @override
  State<_EncashmentDialog> createState() => _EncashmentDialogState();
}

class _EncashmentDialogState extends State<_EncashmentDialog> {
  final _countedCtrl = TextEditingController();
  final _offRegisterAmountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _busy = false;
  bool _showPhysicalCount = false;
  bool _showOffRegisterEncashment = false;
  String? _error;

  CashEncashmentHint get _hint =>
      widget.snapshot.encashmentHint ??
      CashEncashmentHint(
        recommendedAmount: widget.snapshot.availableCash,
        expectedInDrawer: widget.snapshot.expectedInDrawer,
        minReserve: widget.snapshot.minReserve,
        openingBalance: widget.snapshot.openingBalance,
        cashSalesIn: widget.snapshot.cashSalesIn,
        cashRefundsOut: widget.snapshot.cashRefundsOut,
        operationsIn: widget.snapshot.operationsIn,
        operationsOut: widget.snapshot.operationsOut,
      );

  @override
  void dispose() {
    _countedCtrl.dispose();
    _offRegisterAmountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static String _formatAmountInput(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  double? _encashmentFromCounted(double countedInDrawer) {
    if (countedInDrawer < _hint.minReserve - 0.009) return null;
    return countedInDrawer - _hint.minReserve;
  }

  Future<void> _submitByCalculation() async {
    final amount = _hint.recommendedAmount;
    if (amount <= 0) {
      setState(() => _error = 'По расчёту нечего инкассировать');
      return;
    }
    await _runEncashment(amount: amount);
  }

  Future<void> _submitByPhysicalCount({required bool reconcileSurplus}) async {
    final counted = _parseAmount(_countedCtrl.text);
    if (counted == null || counted <= 0) {
      setState(() => _error = 'Укажите полную сумму наличных в ящике');
      return;
    }
    if (counted < _hint.minReserve - 0.009) {
      setState(
        () => _error =
            'В ящике меньше резерва (${formatSomoni(_hint.minReserve)})',
      );
      return;
    }
    await _runEncashment(
      countedInDrawer: counted,
      reconcileSurplus: reconcileSurplus,
    );
  }

  Future<void> _submitOffRegisterEncashment() async {
    final amount = _parseAmount(_offRegisterAmountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Укажите сумму инкассации');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().postOperation(
        opType: 'encashment_off_register',
        amount: amount,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Инкассация вне учёта: ${formatSomoni(amount)}. '
            'В сейф (не из выручки POS). Доступно в кассе: '
            '${formatSomoni(result.snapshot.availableCash)}',
          ),
        ),
      );
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

  Future<void> _runEncashment({
    double? amount,
    double? countedInDrawer,
    bool reconcileSurplus = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().postEncashment(
        amount: amount,
        countedInDrawer: countedInDrawer,
        reconcileSurplus: reconcileSurplus,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Инкассация выполнена. Доступно: '
            '${formatSomoni(result.snapshot.availableCash)}',
          ),
        ),
      );
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
    final scheme = theme.colorScheme;
    final hint = _hint;
    final counted = _showPhysicalCount ? _parseAmount(_countedCtrl.text) : null;
    final encFromPhysical =
        counted != null ? _encashmentFromCounted(counted) : null;
    final surplus = encFromPhysical != null
        ? encFromPhysical - hint.recommendedAmount
        : null;
    final hasSurplus = surplus != null && surplus > 0.02;

    return AlertDialog(
      title: const Text('Инкассация в сейф'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hint.lastEncashmentAt != null) ...[
              Text(
                _formatLastEncashmentLine(hint),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Состав суммы в учёте',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  _EncashmentBreakdownRow(
                    label: 'На начало смены',
                    value: formatSomoni(hint.openingBalance),
                  ),
                  _EncashmentBreakdownRow(
                    label: 'Наличные продажи',
                    value: '+ ${formatSomoni(hint.cashSalesIn)}',
                  ),
                  if (hint.cashRefundsOut > 0.009)
                    _EncashmentBreakdownRow(
                      label: 'Возвраты налом',
                      value: '− ${formatSomoni(hint.cashRefundsOut)}',
                    ),
                  if (hint.operationsIn > 0.009)
                    _EncashmentBreakdownRow(
                      label: 'Внесения',
                      value: '+ ${formatSomoni(hint.operationsIn)}',
                    ),
                  if (hint.operationsOut > 0.009)
                    _EncashmentBreakdownRow(
                      label: 'Выемки',
                      value: '− ${formatSomoni(hint.operationsOut)}',
                    ),
                  const Divider(height: 16),
                  _EncashmentBreakdownRow(
                    label: 'В ящике по расчёту',
                    value: formatSomoni(hint.expectedInDrawer),
                    bold: true,
                  ),
                  _EncashmentBreakdownRow(
                    label: 'Оставить (резерв)',
                    value: formatSomoni(hint.minReserve),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'К инкассации по расчёту: ${formatSomoni(hint.recommendedAmount)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Не инкассировали неделю — всё равно смотрите эту сумму: '
              'в неё входит остаток на начало смены и все наличные продажи.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || hint.recommendedAmount <= 0
                  ? null
                  : _submitByCalculation,
              icon: const Icon(Icons.savings_outlined),
              label: Text(
                'Инкассировать ${formatSomoni(hint.recommendedAmount)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _showPhysicalCount = !_showPhysicalCount),
              child: Text(
                _showPhysicalCount
                    ? 'Скрыть пересчёт ящика'
                    : 'Пересчитали ящик — другая сумма',
              ),
            ),
            if (_showPhysicalCount) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _countedCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Полная сумма наличных в ящике',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _countedCtrl.text = _formatAmountInput(
                            hint.expectedInDrawer > 0
                                ? hint.expectedInDrawer
                                : hint.recommendedAmount + hint.minReserve,
                          );
                          setState(() {});
                        },
                  child: const Text('Подставить по расчёту'),
                ),
              ),
              if (encFromPhysical != null && encFromPhysical > 0) ...[
                Text(
                  'К инкассации по пересчёту: ${formatSomoni(encFromPhysical)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasSurplus) ...[
                  const SizedBox(height: 6),
                  Text(
                    'В ящике на ${formatSomoni(surplus)} больше, чем в учёте POS. '
                    'По пересчёту можно инкассировать — учёт подстроится автоматически.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ],
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => setState(
                          () => _showOffRegisterEncashment =
                              !_showOffRegisterEncashment,
                        ),
                child: Text(
                  _showOffRegisterEncashment
                      ? 'Скрыть инкассацию вне учёта'
                      : 'Инкассация вне учёта кассы (больше выручки)',
                ),
              ),
              if (_showOffRegisterEncashment) ...[
                const SizedBox(height: 8),
                Text(
                  'Сумма уходит в сейф, но не списывается с наличных в ящике по учёту POS '
                  '(например, деньги не из продаж кассы).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _offRegisterAmountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Сумма инкассации вне кассы',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ],
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        if (_showOffRegisterEncashment && widget.isAdmin)
          FilledButton(
            onPressed: _busy ? null : _submitOffRegisterEncashment,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Вне учёта — в сейф'),
          )
        else if (_showPhysicalCount &&
            encFromPhysical != null &&
            encFromPhysical > 0)
          FilledButton(
            onPressed: _busy
                ? null
                : () => _submitByPhysicalCount(reconcileSurplus: false),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    hasSurplus
                        ? 'Инкассировать ${formatSomoni(encFromPhysical)}'
                        : 'По пересчёту',
                  ),
          ),
      ],
    );
  }
}

class _EncashmentBreakdownRow extends StatelessWidget {
  const _EncashmentBreakdownRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CashOperationDialog extends StatefulWidget {
  const _CashOperationDialog({
    required this.opType,
    required this.availableCash,
    this.expectedInDrawer = 0,
    this.minReserve = 0,
  });

  final String opType;
  final double availableCash;
  final double expectedInDrawer;
  final double minReserve;

  @override
  State<_CashOperationDialog> createState() => _CashOperationDialogState();
}

class _CashOperationDialogState extends State<_CashOperationDialog> {
  late final TextEditingController _amountCtrl;
  final _commentCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _amountCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() => _error = null);
  }

  double? _parseAmount(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = _parseAmount(_amountCtrl.text);
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Сумма должна быть больше нуля');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().postOperation(
        opType: widget.opType,
        amount: parsed,
        comment: _commentCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      final label = cashOpTypeLabels[widget.opType] ?? widget.opType;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label выполнено. Доступно: ${formatSomoni(result.snapshot.availableCash)}',
          ),
        ),
      );
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
    final title = cashOpTypeLabels[widget.opType] ?? 'Операция';
    final isOut = widget.opType != 'change_in';
    final isOffRegister = widget.opType == 'off_register';
    final isEncOffRegister = widget.opType == 'encashment_off_register';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isEncOffRegister)
            Text(
              'Инкассация в сейф без ограничения по выручке POS. '
              'Наличные в ящике по учёту не уменьшаются.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isOffRegister)
            Text(
              'Расход вне кассового ящика (не уменьшает нал в ящике). '
              'Списание со склада — в разделе «Склад».',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isOut && !isOffRegister && !isEncOffRegister)
            Text('Доступно: ${formatSomoni(widget.availableCash)}'),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Сумма',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
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
              : const Text('Подтвердить'),
        ),
      ],
    );
  }
}
