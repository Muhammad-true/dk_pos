import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/cash/presentation/cash_shift_report_dialog.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';

Future<void> showPosCashManagementDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _PosCashManagementDialog(),
  );
}

Future<bool> ensureCashShiftOpen(BuildContext context) async {
  final repo = context.read<LocalCashRepository>();
  try {
    final snap = await repo.fetchActiveShift();
    if (snap.hasOpenShift) return true;
  } catch (_) {
    return true;
  }
  if (!context.mounted) return false;
  final opened = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _OpenCashShiftDialog(),
  );
  return opened == true;
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
    final role = context.read<AuthBloc>().state.user?.role ?? '';
    return role == 'admin';
  }

  Future<void> _openShiftFlow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _OpenCashShiftDialog(),
    );
    if (ok == true) await _reload();
  }

  Future<void> _closeShiftFlow() async {
    final snap = _snapshot;
    if (snap == null || !snap.hasOpenShift) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CloseCashShiftDialog(
        expected: snap.expectedInDrawer,
        isAdmin: _isAdmin,
      ),
    );
    if (ok == true) {
      if (mounted) Navigator.of(context).pop();
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
  if (!_isAdmin &&
        !{'change_in'}.contains(opType) &&
        opType != 'encashment') {
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
      builder: (ctx) => _CashOperationDialog(
        opType: opType,
        availableCash: snap.availableCash,
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
                    ] else
                      const Text(
                        'Смена открыта. Доступны внесение, инкассация и закрытие смены. '
                        'Подробный отчёт после закрытия — только у администратора.',
                      ),
                  ] else
                    const Text(
                      'Кассовая смена не открыта. Откройте смену и укажите размен в ящике.',
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
                          onPressed: () => _operationFlow('change_in'),
                          child: const Text('Внесение'),
                        ),
                        OutlinedButton(
                          onPressed: () => _operationFlow('encashment'),
                          child: const Text('Инкассация'),
                        ),
                        if (_isAdmin) ...[
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
  const _OpenCashShiftDialog();

  @override
  State<_OpenCashShiftDialog> createState() => _OpenCashShiftDialogState();
}

class _OpenCashShiftDialogState extends State<_OpenCashShiftDialog> {
  final _ctrl = TextEditingController(text: '1000');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? -1;
    if (amount < 0) {
      setState(() => _error = 'Укажите сумму размена');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LocalCashRepository>().openCashShift(
        openingBalance: amount,
      );
      if (!mounted) return;
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
    return AlertDialog(
      title: const Text('Открыть кассовую смену'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Пересчитайте монеты в ящике и введите сумму размена.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Размен в кассе (сомони)',
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
              : const Text('Открыть'),
        ),
      ],
    );
  }
}

class _CloseCashShiftDialog extends StatefulWidget {
  const _CloseCashShiftDialog({
    required this.expected,
    required this.isAdmin,
  });

  final double expected;
  final bool isAdmin;

  @override
  State<_CloseCashShiftDialog> createState() => _CloseCashShiftDialogState();
}

class _CloseCashShiftDialogState extends State<_CloseCashShiftDialog> {
  final _actualCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final actual = double.tryParse(_actualCtrl.text.replaceAll(',', '.'));
    if (actual == null || actual < 0) {
      setState(() => _error = 'Укажите фактическую сумму в ящике');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<LocalCashRepository>().closeCashShift(
        closingActual: actual,
        closeNotes: _notesCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (!context.mounted) return;
      if (widget.isAdmin && result.report != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => CashShiftReportDialog(report: result.report!),
        );
      } else {
        final msg = result.message ??
            (widget.isAdmin && result.variance != null
                ? (result.variance!.abs() < 0.01
                      ? 'Смена закрыта. Касса сошлась.'
                      : 'Смена закрыта. Разница: ${formatSomoni(result.variance!)}')
                : 'Смена закрыта.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
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
    return AlertDialog(
      title: const Text('Закрыть кассовую смену'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isAdmin)
            Text('По программе в ящике: ${formatSomoni(widget.expected)}')
          else
            const Text(
              'Посчитайте наличные в ящике и введите фактическую сумму. '
              'Отчёт о закрытии доступен администратору.',
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _actualCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Фактически посчитали',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Комментарий (если есть недостача)',
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
              : const Text('Закрыть смену'),
        ),
      ],
    );
  }
}

class _CashOperationDialog extends StatefulWidget {
  const _CashOperationDialog({
    required this.opType,
    required this.availableCash,
  });

  final String opType;
  final double availableCash;

  @override
  State<_CashOperationDialog> createState() => _CashOperationDialogState();
}

class _CashOperationDialogState extends State<_CashOperationDialog> {
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
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
        amount: amount,
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
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOut)
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
