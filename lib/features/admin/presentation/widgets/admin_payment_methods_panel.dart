import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/payments/data/local_payment_methods_repository.dart';

class AdminPaymentMethodsPanel extends StatefulWidget {
  const AdminPaymentMethodsPanel({super.key});

  @override
  State<AdminPaymentMethodsPanel> createState() =>
      _AdminPaymentMethodsPanelState();
}

class _AdminPaymentMethodsPanelState extends State<AdminPaymentMethodsPanel> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<LocalPaymentMethod> _methods = const [];

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
      final repo = context.read<LocalPaymentMethodsRepository>();
      final list = await repo.fetchMethods(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _methods = list;
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

  Future<void> _openCreateOrEdit({LocalPaymentMethod? method}) async {
    final result = await showDialog<_MethodFormResult>(
      context: context,
      builder: (_) => _PaymentMethodFormDialog(initial: method),
    );
    if (!mounted || result == null) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<LocalPaymentMethodsRepository>();
      if (method == null) {
        await repo.createBankMethod(
          title: result.title,
          code: result.code,
          sortOrder: result.sortOrder,
          isActive: result.isActive,
          details: result.details,
        );
      } else {
        await repo.updateBankMethod(
          id: method.id ?? 0,
          title: result.title,
          code: result.code,
          sortOrder: result.sortOrder,
          isActive: result.isActive,
          details: result.details,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(method == null ? 'Банк добавлен' : 'Банк обновлен'),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive(LocalPaymentMethod method) async {
    if (method.id == null || method.isSystem) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отключить банк?'),
        content: Text(
          'Способ оплаты "${method.title}" останется в истории, но исчезнет из кассы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<LocalPaymentMethodsRepository>().archiveMethod(
        id: method.id!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Банк отключен')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Способы оплаты (касса)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: _loading || _saving ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              'Наличные всегда доступны. Здесь вы добавляете банки (ДС, Эсхата и т.д.), которые увидит кассир.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error))
            else
              ..._methods.map((m) {
                final subtitleParts = <String>[];
                subtitleParts.add(m.type == 'cash' ? 'Системный' : 'Банк');
                subtitleParts.add('code: ${m.code}');
                subtitleParts.add('sort: ${m.sortOrder}');
                if (!m.isActive) subtitleParts.add('отключен');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    m.isCash
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded,
                    color: m.isActive ? scheme.primary : scheme.outline,
                  ),
                  title: Text(m.title),
                  subtitle: Text(subtitleParts.join(' • ')),
                  trailing: m.isSystem
                      ? const Text('Системный')
                      : Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Редактировать',
                              onPressed: _saving
                                  ? null
                                  : () => _openCreateOrEdit(method: m),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Отключить',
                              onPressed: _saving ? null : () => _archive(m),
                              icon: const Icon(Icons.block_rounded),
                            ),
                          ],
                        ),
                );
              }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _openCreateOrEdit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить банк'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodFormResult {
  const _MethodFormResult({
    required this.title,
    required this.code,
    required this.sortOrder,
    required this.isActive,
    required this.details,
  });

  final String title;
  final String code;
  final int sortOrder;
  final bool isActive;
  final Map<String, dynamic> details;
}

class _PaymentMethodFormDialog extends StatefulWidget {
  const _PaymentMethodFormDialog({this.initial});

  final LocalPaymentMethod? initial;

  @override
  State<_PaymentMethodFormDialog> createState() =>
      _PaymentMethodFormDialogState();
}

class _PaymentMethodFormDialogState extends State<_PaymentMethodFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _accountNoCtrl;
  late final TextEditingController _commentCtrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final details = widget.initial?.details ?? const <String, dynamic>{};
    _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
    _codeCtrl = TextEditingController(text: widget.initial?.code ?? '');
    _sortCtrl = TextEditingController(
      text: '${widget.initial?.sortOrder ?? 100}',
    );
    _bankNameCtrl = TextEditingController(
      text: details['bankName']?.toString() ?? '',
    );
    _accountNoCtrl = TextEditingController(
      text: details['accountNo']?.toString() ?? '',
    );
    _commentCtrl = TextEditingController(
      text: details['comment']?.toString() ?? '',
    );
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _codeCtrl.dispose();
    _sortCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNoCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Редактировать банк' : 'Новый банк'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название в кассе *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Код (латиница/цифры) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Банк (полное название)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Номер счета/терминала',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Порядок',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Активен в кассе'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            final code = _codeCtrl.text.trim().toLowerCase();
            final sort = int.tryParse(_sortCtrl.text.trim()) ?? 100;
            if (title.isEmpty || code.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Заполните название и код')),
              );
              return;
            }
            Navigator.of(context).pop(
              _MethodFormResult(
                title: title,
                code: code,
                sortOrder: sort,
                isActive: _isActive,
                details: {
                  'bankName': _bankNameCtrl.text.trim(),
                  'accountNo': _accountNoCtrl.text.trim(),
                  'comment': _commentCtrl.text.trim(),
                },
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
