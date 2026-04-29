import 'dart:async';
import 'dart:math' as math;

import 'package:dk_pos/core/constants/phone_defaults.dart';
import 'package:dk_pos/features/loyalty/data/local_loyalty_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AdminLoyaltyPanel extends StatefulWidget {
  const AdminLoyaltyPanel({super.key});

  @override
  State<AdminLoyaltyPanel> createState() => _AdminLoyaltyPanelState();
}

class _AdminLoyaltyPanelState extends State<AdminLoyaltyPanel> {
  final _searchCtrl = TextEditingController();
  final _newNameCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  final _newCardCtrl = TextEditingController();
  Timer? _scanDebounce;
  bool _autoScan = true;
  bool _loading = false;
  bool _savingCreate = false;
  String? _error;
  List<LoyaltyCustomer> _customers = const [];
  List<LoyaltyTier> _tiers = const [];

  @override
  void initState() {
    super.initState();
    _newPhoneCtrl.text = kDefaultPhoneDialPrefix;
    _reload();
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    _searchCtrl.dispose();
    _newNameCtrl.dispose();
    _newPhoneCtrl.dispose();
    _newCardCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalLoyaltyRepository>();
      final results = await Future.wait([
        repo.fetchTiers(),
        repo.searchCustomers(query: _searchCtrl.text.trim(), includeBlacklisted: true),
      ]);
      if (!mounted) return;
      final query = _searchCtrl.text.trim();
      final normalized = _normalizeScanValue(query);
      final ranked = List<LoyaltyCustomer>.from(results[1] as List<LoyaltyCustomer>);
      if (query.isNotEmpty) {
        ranked.sort((a, b) {
          final ax = _isExactCustomerMatch(a, query, normalized) ? 1 : 0;
          final bx = _isExactCustomerMatch(b, query, normalized) ? 1 : 0;
          if (ax != bx) return bx - ax;
          return b.id.compareTo(a.id);
        });
      }
      setState(() {
        _tiers = results[0] as List<LoyaltyTier>;
        _customers = ranked;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    if (!_autoScan) return;
    _scanDebounce?.cancel();
    _scanDebounce = Timer(const Duration(milliseconds: 220), _reload);
  }

  String _normalizeScanValue(String value) {
    return value.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  bool _isExactCustomerMatch(LoyaltyCustomer c, String rawQuery, String normalizedQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return false;
    final qr = c.qrCode.trim().toLowerCase();
    final card = (c.cardCode ?? '').trim().toLowerCase();
    if (qr == q || (card.isNotEmpty && card == q)) return true;
    if (normalizedQuery.isEmpty) return false;
    final phone = _normalizeScanValue(c.phone);
    return phone == normalizedQuery;
  }

  Future<void> _createCustomer() async {
    final phone = _newPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Телефон обязателен');
      return;
    }
    setState(() {
      _savingCreate = true;
      _error = null;
    });
    try {
      await context.read<LocalLoyaltyRepository>().createCustomer(
            phone: phone,
            fullName: _newNameCtrl.text.trim().isEmpty ? null : _newNameCtrl.text.trim(),
            cardCode: _newCardCtrl.text.trim().isEmpty ? null : _newCardCtrl.text.trim(),
          );
      if (!mounted) return;
      _newNameCtrl.clear();
      _newPhoneCtrl.text = kDefaultPhoneDialPrefix;
      _newCardCtrl.clear();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Клиент создан')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingCreate = false);
    }
  }

  Future<void> _toggleBlacklist(LoyaltyCustomer customer) async {
    try {
      final reason = await _askText(
        context,
        title: customer.isBlacklisted ? 'Снять из ЧС' : 'Добавить в ЧС',
        label: 'Причина',
      );
      if (!mounted || reason == null) return;
      await context.read<LocalLoyaltyRepository>().setBlacklist(
            customerId: customer.id,
            blacklisted: !customer.isBlacklisted,
            reason: reason.trim().isEmpty ? null : reason.trim(),
          );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _adjustPoints(LoyaltyCustomer customer) async {
    final value = await _askText(
      context,
      title: 'Изменить баллы: ${customer.fullName}',
      label: 'Введите +/- значение (пример: 50 или -20)',
    );
    if (!mounted || value == null) return;
    final delta = double.tryParse(value.trim().replaceAll(',', '.'));
    if (delta == null || delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректное значение')),
      );
      return;
    }
    try {
      await context.read<LocalLoyaltyRepository>().adjustPoints(
            customerId: customer.id,
            pointsDelta: delta,
            comment: 'Из админки',
          );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteCustomer(LoyaltyCustomer customer) async {
    final repo = context.read<LocalLoyaltyRepository>();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Удалить клиента?'),
            content: Text('Клиент: ${customer.fullName} (${customer.phone})'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await repo.deleteCustomer(customerId: customer.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editTier(LoyaltyTier tier) async {
    final repo = context.read<LocalLoyaltyRepository>();
    final percentCtrl = TextEditingController(text: tier.accrualPercent.toStringAsFixed(2));
    final thresholdCtrl = TextEditingController(text: tier.monthlySpendThreshold.toStringAsFixed(2));
    final titleCtrl = TextEditingController(text: tier.title);
    bool active = tier.isActive;
    final save = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Уровень: ${tier.code}'),
            content: SizedBox(
              width: _dialogWidth(context, 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: percentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Процент начисления',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: thresholdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Порог суммы за месяц',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Активен'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    );
    if (save != true) return;
    final percent = double.tryParse(percentCtrl.text.trim().replaceAll(',', '.'));
    final threshold = double.tryParse(thresholdCtrl.text.trim().replaceAll(',', '.'));
    if (percent == null || threshold == null) return;
    try {
      await repo.updateTier(
            tierId: tier.id,
            title: titleCtrl.text.trim(),
            accrualPercent: percent,
            monthlySpendThreshold: threshold,
            isActive: active,
          );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Клиенты и лояльность',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Поиск по телефону/карте/QR, создание клиента, ЧС, ручное изменение баллов и настройка процентов уровней.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Поиск клиента (сканер)',
                      hintText: 'Телефон / карта / QR / имя',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _reload(),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Найти'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Авто-скан'),
                    Switch(
                      value: _autoScan,
                      onChanged: (v) => setState(() => _autoScan = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Создать клиента',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _newNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _newPhoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Телефон *',
                      hintText: '$kDefaultPhoneDialPrefix…',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _newCardCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Карта',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _savingCreate ? null : _createCustomer,
                  icon: _savingCreate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Создать'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Уровни',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (_loading) const LinearProgressIndicator(),
            ..._tiers.map(
              (tier) => ListTile(
                dense: true,
                title: Text('${tier.title} (${tier.code})'),
                subtitle: Text(
                  'Начисление: ${tier.accrualPercent.toStringAsFixed(2)}% • '
                  'Порог/месяц: ${tier.monthlySpendThreshold.toStringAsFixed(2)} • '
                  '${tier.isActive ? 'активен' : 'выключен'}',
                ),
                trailing: IconButton(
                  onPressed: () => _editTier(tier),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
            ),
            const Divider(),
            Text(
              'Клиенты',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ..._customers.map(
              (c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${c.fullName} • ${c.phone}'),
                  subtitle: Text(
                    'Баллы: ${c.pointsBalance.toStringAsFixed(2)} • '
                    'QR: ${c.qrCode}'
                    '${c.cardCode != null && c.cardCode!.isNotEmpty ? ' • Карта: ${c.cardCode}' : ''}'
                    '${c.tier != null ? ' • ${c.tier!.title} (${c.tier!.accrualPercent.toStringAsFixed(2)}%)' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'История',
                        onPressed: () => _showHistory(c),
                        icon: const Icon(Icons.history_rounded),
                      ),
                      IconButton(
                        tooltip: 'Баллы +/-',
                        onPressed: () => _adjustPoints(c),
                        icon: const Icon(Icons.exposure_plus_1_rounded),
                      ),
                      IconButton(
                        tooltip: c.isBlacklisted ? 'Снять из ЧС' : 'В ЧС',
                        onPressed: () => _toggleBlacklist(c),
                        icon: Icon(
                          c.isBlacklisted ? Icons.lock_open_rounded : Icons.block_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        onPressed: () => _deleteCustomer(c),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistory(LoyaltyCustomer customer) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CustomerHistoryDialog(customer: customer),
    );
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _CustomerHistoryDialog extends StatefulWidget {
  const _CustomerHistoryDialog({required this.customer});

  final LoyaltyCustomer customer;

  @override
  State<_CustomerHistoryDialog> createState() => _CustomerHistoryDialogState();
}

class _CustomerHistoryDialogState extends State<_CustomerHistoryDialog> {
  bool _loading = true;
  String? _error;
  List<LoyaltyHistoryEntry> _rows = const [];

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
      final rows = await context.read<LocalLoyaltyRepository>().fetchCustomerHistory(
            customerId: widget.customer.id,
            limit: 200,
          );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('История: ${widget.customer.fullName}'),
      content: SizedBox(
        width: _dialogWidth(context, 760),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(_error!)
                : _rows.isEmpty
                    ? const Text('История пуста')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final row = _rows[i];
                          final sign = row.pointsDelta >= 0 ? '+' : '';
                          final dt = row.createdAt?.toString() ?? '-';
                          final details = <String>[
                            if (row.orderNumber != null && row.orderNumber!.isNotEmpty)
                              'Заказ: ${row.orderNumber}',
                            if (row.paymentAmount != null)
                              'Оплата: ${row.paymentAmount!.toStringAsFixed(2)}',
                            if (row.paymentMethod != null && row.paymentMethod!.isNotEmpty)
                              'Метод: ${row.paymentMethod}',
                            if (row.comment != null && row.comment!.isNotEmpty)
                              row.comment!,
                          ];
                          return ListTile(
                            dense: true,
                            title: Text('${row.txType} • $sign${row.pointsDelta.toStringAsFixed(2)}'),
                            subtitle: Text(details.join(' • ')),
                            trailing: Text(dt),
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

double _dialogWidth(BuildContext context, double preferred) {
  return math.min(preferred, MediaQuery.sizeOf(context).width * 0.94);
}
