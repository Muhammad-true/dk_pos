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
  int? _expandedId;
  InventoryTransferDocument? _detail;
  bool _detailLoading = false;
  bool _receiving = false;

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

  Future<void> _loadDetail(int id) async {
    setState(() {
      _expandedId = id;
      _detailLoading = true;
      _detail = null;
    });
    try {
      final doc = await context.read<LocalInventoryRepository>().fetchTransfer(id);
      if (!mounted) return;
      setState(() {
        _detail = doc;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static String _fmtSom(double v) => '${v.round()} сом.';

  Future<void> _receive(int id) async {
    if (_receiving) return;
    setState(() => _receiving = true);
    try {
      await context.read<LocalInventoryRepository>().receiveTransfer(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Накладная принята — остатки на точке обновлены')),
      );
      setState(() {
        _expandedId = null;
        _detail = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Приём со склада'),
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
                        'Центр отправляет накладную из админки → здесь подтверждаете приём. '
                        'После приёма сырьё появится на складе точки и касса сможет списывать при продаже.',
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
                        'Нет накладных в пути. Отправку делаете в admin.donerkebab.tj → Склад → Отправка.',
                        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ..._items.map((item) {
                    final expanded = _expandedId == item.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: Text(item.docNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${item.lineCount} поз. · ${item.docDate ?? "—"}'
                              '${item.totalAmount != null ? " · ${_fmtSom(item.totalAmount!)}" : ""}'
                              '${item.toLocationName != null ? " · ${item.toLocationName}" : ""}',
                            ),
                            trailing: Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                            onTap: () {
                              if (expanded) {
                                setState(() {
                                  _expandedId = null;
                                  _detail = null;
                                });
                              } else {
                                _loadDetail(item.id);
                              }
                            },
                          ),
                          if (expanded) ...[
                            const Divider(height: 1),
                            if (_detailLoading)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (_detail != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Text(
                                  'Итого: ${_fmtSom(_detail!.totalAmount)}',
                                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _detail!.lines
                                      .map(
                                        (ln) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            ln.sku != null && ln.sku!.isNotEmpty
                                                ? '• [${ln.sku}] ${ln.ingredientName}: ${ln.qty} ${ln.unit}'
                                                    '${ln.unitCost != null ? " · ${_fmtSom(ln.lineSum)}" : ""}'
                                                : '• ${ln.ingredientName}: ${ln.qty} ${ln.unit}'
                                                    '${ln.unitCost != null ? " · ${_fmtSom(ln.lineSum)}" : ""}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: FilledButton.icon(
                                  onPressed: _receiving ? null : () => _receive(item.id),
                                  icon: _receiving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.inventory_2_outlined),
                                  label: const Text('Принять накладную'),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
