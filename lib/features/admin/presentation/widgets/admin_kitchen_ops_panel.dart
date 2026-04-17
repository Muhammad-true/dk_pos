import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = DateTime(now.year, now.month, now.day);
    _future = _load();
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

  Future<AdminKitchenOpsReport> _load() {
    return context.read<AdminReportsRepository>().fetchKitchenOpsReport(
          dateFrom: _fmtDate(_from),
          dateTo: _fmtDate(_to),
        );
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

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
                    ],
                  ),
                ),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OpsCard(
                        title: 'Кухня по сотрудникам',
                        child: Column(
                          children: [
                            for (final row in report.kitchenByUser)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.person_rounded),
                                title: Text('${row.username} (${row.role})'),
                                subtitle: Text(
                                  'Заказы: ${row.ordersCount}, Товары: ${row.itemsReady}',
                                ),
                                trailing: Text(_fmtHm(row.spentSeconds)),
                              ),
                            if (report.kitchenByUser.isEmpty)
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
                                  'Заказы: ${row.ordersCount}, Товары: ${row.itemsReady}',
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
                            for (final row in report.shifts)
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
                            if (report.shifts.isEmpty)
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
