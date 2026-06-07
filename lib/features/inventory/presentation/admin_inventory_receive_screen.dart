import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/inventory/data/local_inventory_repository.dart';

/// Приём перемещений с центрального склада на эту точку (через global API).
class AdminInventoryReceiveScreen extends StatefulWidget {
  const AdminInventoryReceiveScreen({super.key});

  @override
  State<AdminInventoryReceiveScreen> createState() => _AdminInventoryReceiveScreenState();
}

class _AdminInventoryReceiveScreenState extends State<AdminInventoryReceiveScreen> {
  bool _loading = true;
  bool _enabled = true;
  String? _error;
  List<InventoryTransferSummary> _items = const [];
  int? _receivingId;

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
      final repo = context.read<LocalInventoryRepository>();
      final result = await repo.fetchInTransit();
      if (!mounted) return;
      setState(() {
        _enabled = result.enabled;
        _items = result.items;
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

  static String _fmtSom(double v) => '${v.round()} сомони';

  Future<void> _receive(int id, String docNumber) async {
    if (_receivingId != null) return;
    setState(() => _receivingId = id);
    try {
      await context.read<LocalInventoryRepository>().receiveTransfer(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Накладная $docNumber принята')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _receivingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Приём накладных'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Material(
                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Центр отправил накладную из админки. Нажмите «Принять» — '
                        'состав уже в документе, ничего вводить не нужно.',
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ),
                  if (!_enabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Склад global выключен на сервере точки.',
                      style: textTheme.bodyMedium?.copyWith(color: scheme.error),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Ожидают приёма (${_items.length})',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Нет накладных в пути. Отправку делаете в admin → Склад → Отправка (из прихода).',
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ..._items.map((item) {
                    final busy = _receivingId == item.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        title: Text(
                          item.docNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${item.lineCount} поз. · ${item.docDate ?? "—"}'
                          '${item.totalAmount != null ? " · ${_fmtSom(item.totalAmount!)}" : ""}'
                          '${item.toLocationName != null ? "\n${item.toLocationName}" : ""}',
                        ),
                        isThreeLine: item.toLocationName != null,
                        trailing: FilledButton(
                          onPressed: busy || !_enabled ? null : () => _receive(item.id, item.docNumber),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Принять'),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
