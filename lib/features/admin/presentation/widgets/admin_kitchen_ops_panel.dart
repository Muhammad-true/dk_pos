import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';

enum _KitchenAuditSort { best, slow }

class AdminKitchenOpsPanel extends StatefulWidget {
  const AdminKitchenOpsPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<AdminKitchenOpsPanel> createState() => _AdminKitchenOpsPanelState();
}

class _AdminKitchenOpsPanelState extends State<AdminKitchenOpsPanel> {
  late DateTime _from;
  late DateTime _to;
  late Future<AdminKitchenOpsReport> _future;
  late Future<AdminSyncStatus> _syncFuture;
  bool _onlyKitchenRole = true;
  _KitchenAuditSort _kitchenSort = _KitchenAuditSort.best;
  bool _syncBusy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = DateTime(now.year, now.month, now.day);
    _future = _load();
    _syncFuture = _loadSyncStatus();
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtHm(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$hч $mм';
  }

  String _fmtMs(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$mм $sс';
  }

  String _fmtAvgSecPerItem({required int spentSeconds, required int itemsReady}) {
    if (itemsReady <= 0) return '—';
    final avg = (spentSeconds / itemsReady).round();
    return _fmtMs(avg);
  }

  Color _kitchenButtonColor(String? rawHex) {
    final v = (rawHex ?? '').trim();
    if (v.isEmpty) return Colors.grey.shade500;
    final normalized = v.startsWith('#') ? v.substring(1) : v;
    if (normalized.length != 6) return Colors.grey.shade500;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return Colors.grey.shade500;
    return Color(0xFF000000 | parsed);
  }

  bool _isKitchenRole(String role) => role.trim().toLowerCase() == 'warehouse';

  bool _isProblemUser(AdminKitchenUserOpsRow row) {
    final accepted = row.itemsAccepted;
    final ready = row.itemsReady;
    final hasButton = row.kitchenButtonId > 0;
    if (!hasButton) return true;
    if (accepted >= 5 && ready == 0) return true;
    if (accepted >= 8 && ready / accepted < 0.55) return true;
    return false;
  }

  List<AdminKitchenUserOpsRow> _sortedKitchenUsers(List<AdminKitchenUserOpsRow> source) {
    final mutable = source.toList(growable: true);
    mutable.sort((a, b) {
      switch (_kitchenSort) {
        case _KitchenAuditSort.best:
          if (b.itemsReady != a.itemsReady) return b.itemsReady - a.itemsReady;
          if (b.ordersReadyCount != a.ordersReadyCount) return b.ordersReadyCount - a.ordersReadyCount;
          return a.spentSeconds - b.spentSeconds;
        case _KitchenAuditSort.slow:
          final aAvg = a.itemsReady > 0 ? a.spentSeconds / a.itemsReady : double.infinity;
          final bAvg = b.itemsReady > 0 ? b.spentSeconds / b.itemsReady : double.infinity;
          final cmpAvg = bAvg.compareTo(aAvg);
          if (cmpAvg != 0) return cmpAvg;
          return b.itemsAccepted - a.itemsAccepted;
      }
    });
    return mutable;
  }

  Future<AdminKitchenOpsReport> _load() {
    final branchId = AppConfig.storeBranchId;
    return context.read<AdminReportsRepository>().fetchKitchenOpsReport(
          dateFrom: _fmtDate(_from),
          dateTo: _fmtDate(_to),
          branchId: branchId,
        );
  }

  Future<AdminSyncStatus> _loadSyncStatus() {
    return context.read<AdminReportsRepository>().fetchSyncStatus(
          branchId: AppConfig.storeBranchId,
        );
  }

  Future<void> _reload() async {
    final f = _load();
    final sf = _loadSyncStatus();
    setState(() {
      _future = f;
      _syncFuture = sf;
    });
    await Future.wait([f, sf]);
  }

  Future<void> _reloadSyncOnly() async {
    final sf = _loadSyncStatus();
    setState(() {
      _syncFuture = sf;
    });
    await sf;
  }

  Future<void> _runSyncAction(Future<AdminSyncActionResult> Function() action) async {
    if (_syncBusy) return;
    setState(() => _syncBusy = true);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка синхронизации: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncBusy = false);
      }
      await _reloadSyncOnly();
    }
  }

  String _yesNo(bool value) => value ? 'Да' : 'Нет';

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => _from = picked);
    await _reload();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() => _to = picked);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Смены и кухня',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Кто когда открыл/закрыл смену и сколько кухня приготовила за период.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    runSpacing: 10,
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFrom,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text('С: ${_fmtDate(_from)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickTo,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text('По: ${_fmtDate(_to)}'),
                      ),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Обновить'),
                      ),
                      FilterChip(
                        selected: _onlyKitchenRole,
                        onSelected: (v) => setState(() => _onlyKitchenRole = v),
                        label: const Text('Только кухня'),
                        avatar: const Icon(Icons.soup_kitchen_outlined, size: 18),
                      ),
                      ChoiceChip(
                        selected: _kitchenSort == _KitchenAuditSort.best,
                        onSelected: (_) => setState(() => _kitchenSort = _KitchenAuditSort.best),
                        label: const Text('Сорт: лучшие'),
                      ),
                      ChoiceChip(
                        selected: _kitchenSort == _KitchenAuditSort.slow,
                        onSelected: (_) => setState(() => _kitchenSort = _KitchenAuditSort.slow),
                        label: const Text('Сорт: медленные'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<AdminSyncStatus>(
                future: _syncFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Загрузка статуса синхронизации...'),
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('sync/status: ${snapshot.error}'),
                      ),
                    );
                  }
                  final sync = snapshot.data!;
                  final hasProblems = sync.outbox.failed > 0 ||
                      (sync.pushState?.lastError?.isNotEmpty ?? false) ||
                      (sync.pullState?.lastError?.isNotEmpty ?? false);
                  final statusTone = hasProblems ? Colors.red : Colors.green;
                  return _OpsCard(
                    title: 'Синхронизация Global <-> Local',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _OpsKpiChip(
                              label: 'Очередь pending',
                              value: '${sync.outbox.pending}',
                              tone: const Color(0xFF1565C0),
                            ),
                            _OpsKpiChip(
                              label: 'Retry',
                              value: '${sync.outbox.retrying}',
                              tone: const Color(0xFFEF6C00),
                            ),
                            _OpsKpiChip(
                              label: 'Failed',
                              value: '${sync.outbox.failed}',
                              tone: const Color(0xFFC62828),
                            ),
                            _OpsKpiChip(
                              label: 'Последний batch push',
                              value: '${sync.pushState?.lastBatchSent ?? 0}',
                              tone: const Color(0xFF2E7D32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusTone.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusTone.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasProblems ? 'Статус: есть проблемы' : 'Статус: норма',
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: statusTone,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Push worker: ${_yesNo(sync.pushWorker.enabled)} | interval: ${sync.pushWorker.intervalMs} ms | endpoint: ${_yesNo(sync.pushWorker.endpointConfigured)}',
                              ),
                              Text(
                                'Pull worker: ${_yesNo(sync.pullWorker.enabled)} | interval: ${sync.pullWorker.intervalMs} ms | endpoint: ${_yesNo(sync.pullWorker.endpointConfigured)}',
                              ),
                              const SizedBox(height: 4),
                              Text('Push last success: ${sync.pushState?.lastSuccessAt ?? '—'}'),
                              Text('Pull last success: ${sync.pullState?.lastSuccessAt ?? '—'}'),
                              if ((sync.pushState?.lastError ?? '').isNotEmpty)
                                Text('Push error: ${sync.pushState!.lastError}'),
                              if ((sync.pullState?.lastError ?? '').isNotEmpty)
                                Text('Pull error: ${sync.pullState!.lastError}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _syncBusy
                                  ? null
                                  : () => _runSyncAction(
                                        () => context
                                            .read<AdminReportsRepository>()
                                            .triggerPushNow(
                                              branchId: AppConfig.storeBranchId,
                                            ),
                                      ),
                              icon: _syncBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_rounded),
                              label: const Text('Push now'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _syncBusy
                                  ? null
                                  : () => _runSyncAction(
                                        () => context
                                            .read<AdminReportsRepository>()
                                            .triggerPullNow(
                                              branchId: AppConfig.storeBranchId,
                                            ),
                                      ),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Pull now'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _syncBusy ? null : _reloadSyncOnly,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Обновить статус'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<AdminKitchenOpsReport>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Card(
                      color: scheme.errorContainer.withValues(alpha: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(snapshot.error.toString()),
                      ),
                    );
                  }
                  final report = snapshot.data!;
                  final kitchenUsersRaw = _onlyKitchenRole
                      ? report.kitchenByUser.where((r) => _isKitchenRole(r.role)).toList(growable: false)
                      : report.kitchenByUser;
                  final kitchenUsers = _sortedKitchenUsers(kitchenUsersRaw);
                  final shiftRows = _onlyKitchenRole
                      ? report.shifts.where((s) => _isKitchenRole(s.role)).toList(growable: false)
                      : report.shifts;
                  final totalAcceptedItems = kitchenUsers.fold<int>(
                    0,
                    (sum, r) => sum + r.itemsAccepted,
                  );
                  final totalReadyItems = kitchenUsers.fold<int>(
                    0,
                    (sum, r) => sum + r.itemsReady,
                  );
                  final totalReadyOrders = kitchenUsers.fold<int>(
                    0,
                    (sum, r) => sum + r.ordersReadyCount,
                  );
                  final totalCookSeconds = kitchenUsers.fold<int>(
                    0,
                    (sum, r) => sum + r.spentSeconds,
                  );
                  final activeKitchenUsers = kitchenUsers.where((r) {
                    return r.itemsAccepted > 0 || r.itemsReady > 0;
                  }).length;
                  final problemUsers = kitchenUsers.where(_isProblemUser).length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OpsCard(
                        title: 'Итог за период',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _OpsKpiChip(
                              label: 'Активных поваров',
                              value: '$activeKitchenUsers',
                              tone: const Color(0xFF1565C0),
                            ),
                            _OpsKpiChip(
                              label: 'Принято позиций',
                              value: '$totalAcceptedItems',
                              tone: const Color(0xFFEF6C00),
                            ),
                            _OpsKpiChip(
                              label: 'Готово позиций',
                              value: '$totalReadyItems',
                              tone: const Color(0xFF2E7D32),
                            ),
                            _OpsKpiChip(
                              label: 'Готово заказов',
                              value: '$totalReadyOrders',
                              tone: const Color(0xFF7B1FA2),
                            ),
                            _OpsKpiChip(
                              label: 'Среднее на 1 позицию',
                              value: _fmtAvgSecPerItem(
                                spentSeconds: totalCookSeconds,
                                itemsReady: totalReadyItems,
                              ),
                              tone: const Color(0xFF37474F),
                            ),
                            _OpsKpiChip(
                              label: 'Проблемных поваров',
                              value: '$problemUsers',
                              tone: const Color(0xFFC62828),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _OpsCard(
                        title: 'Аудит кухни по поварам и кнопкам',
                        child: Column(
                          children: [
                            for (final row in kitchenUsers)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isProblemUser(row)
                                      ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isProblemUser(row)
                                        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.40)
                                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.40),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: _kitchenButtonColor(
                                      row.kitchenButtonColorHex,
                                    ),
                                    child: const Icon(
                                      Icons.pan_tool_alt_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    row.username,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    'Кнопка: ${row.kitchenButtonName.isEmpty ? 'не назначена' : row.kitchenButtonName}\n'
                                    'Принял: ${row.ordersAcceptedCount} зак / ${row.itemsAccepted} поз\n'
                                    'Готово: ${row.ordersReadyCount} зак / ${row.itemsReady} поз'
                                    '${_isProblemUser(row) ? '\nВнимание: проверьте разрыв «принял/готово»' : ''}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _fmtHm(row.spentSeconds),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ср: ${_fmtAvgSecPerItem(spentSeconds: row.spentSeconds, itemsReady: row.itemsReady)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (kitchenUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Нет данных за выбранный период'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _OpsCard(
                        title: 'Кухня по станциям',
                        child: Column(
                          children: [
                            for (final row in report.kitchenByStation)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.restaurant_rounded),
                                title: Text(row.stationName),
                                subtitle: Text(
                                  'Заказы: ${row.ordersCount}, Позиции: ${row.itemsReady}, '
                                  'Среднее: ${_fmtAvgSecPerItem(spentSeconds: row.spentSeconds, itemsReady: row.itemsReady)}',
                                ),
                                trailing: Text(_fmtHm(row.spentSeconds)),
                              ),
                            if (report.kitchenByStation.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Нет данных за выбранный период'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _OpsCard(
                        title: 'Смены пользователей',
                        child: Column(
                          children: [
                            for (final row in shiftRows)
                              ListTile(
                                dense: true,
                                leading: Icon(
                                  row.closedAtIso == null
                                      ? Icons.play_circle_rounded
                                      : Icons.check_circle_rounded,
                                ),
                                title: Text('${row.username} (${row.role})'),
                                subtitle: Text(
                                  'Открыта: ${row.openedAtIso}${row.closedAtIso != null ? '\nЗакрыта: ${row.closedAtIso}' : '\nСмена активна'}',
                                ),
                                trailing: Text(_fmtHm(row.durationSeconds)),
                              ),
                            if (shiftRows.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Смен за выбранный период нет'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsCard extends StatelessWidget {
  const _OpsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _OpsKpiChip extends StatelessWidget {
  const _OpsKpiChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
          ),
        ],
      ),
    );
  }
}
