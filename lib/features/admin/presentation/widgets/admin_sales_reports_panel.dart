import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

/// Отчёт «Продажи»: фильтр дат «с — по» и таблицы по данным оплат.
class AdminSalesReportsPanel extends StatefulWidget {
  const AdminSalesReportsPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<AdminSalesReportsPanel> createState() => _AdminSalesReportsPanelState();
}

class _AdminSalesReportsPanelState extends State<AdminSalesReportsPanel> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  AdminSalesReport? _report;
  bool _loading = false;
  String? _error;
  bool _compactView = true;

  String get _branchId => AppConfig.storeBranchId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = DateTime(now.year, now.month, now.day);
    _dateFrom = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<AdminReportsRepository>();
      final r = await repo.fetchSalesReport(
        dateFrom: _isoDate(_dateFrom),
        dateTo: _isoDate(_dateTo),
        branchId: _branchId,
      );
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _report = null;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = DateTime(picked.year, picked.month, picked.day);
        if (_dateFrom.isAfter(_dateTo)) {
          _dateTo = _dateFrom;
        }
      } else {
        _dateTo = DateTime(picked.year, picked.month, picked.day);
        if (_dateTo.isBefore(_dateFrom)) {
          _dateFrom = _dateTo;
        }
      }
    });
  }

  String _methodLabel(AppLocalizations l10n, String method) {
    switch (method) {
      case 'cash':
        return l10n.adminReportsMethodCash;
      case 'card':
        return l10n.adminReportsMethodCard;
      case 'online':
        return l10n.adminReportsMethodOnline;
      case 'ds':
        return l10n.adminReportsMethodDs;
      default:
        return method.isEmpty ? l10n.adminReportsMethodOther : method;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'cashier':
        return 'Касса';
      case 'waiter':
        return 'Официант';
      case 'warehouse':
        return 'Кухня';
      case 'expeditor':
        return 'Сборщик';
      default:
        return role.isEmpty ? '—' : role;
    }
  }

  double _avgCheck(AdminSalesReportSummary summary) {
    if (summary.paymentCount <= 0) return 0;
    return summary.totalAmount / summary.paymentCount;
  }

  (String label, int count, double total)? _topMethod(
    AppLocalizations l10n,
    AdminSalesReport report,
  ) {
    if (report.byMethod.isEmpty) return null;
    final sorted = [...report.byMethod]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final top = sorted.first;
    return (_methodLabel(l10n, top.method), top.paymentCount, top.totalAmount);
  }

  (String day, int count, double total)? _topDay(AdminSalesReport report) {
    if (report.byDay.isEmpty) return null;
    final sorted = [...report.byDay]
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final top = sorted.first;
    return (top.day, top.paymentCount, top.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMMMd(locale);
    final dateTimeFmt = DateFormat.yMMMd(locale).add_Hm();

    Widget dateTile(String label, DateTime d, VoidCallback onTap) {
      return Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFmt.format(d),
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.calendar_month_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Text(
              l10n.adminReportsSalesTitle,
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminReportsSalesSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: dateTile(l10n.adminReportsDateFrom, _dateFrom, () => _pickDate(isFrom: true))),
                const SizedBox(width: 12),
                Expanded(child: dateTile(l10n.adminReportsDateTo, _dateTo, () => _pickDate(isFrom: false))),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(l10n.adminReportsShow),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: _compactView,
                  onSelected: (v) => setState(() => _compactView = v),
                  label: const Text('Краткий режим'),
                  avatar: Icon(
                    _compactView ? Icons.view_agenda_rounded : Icons.view_list_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '${l10n.adminReportsLoadError}: $_error',
                    style: textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            if (_report != null && _error == null) ...[
              const SizedBox(height: 22),
              _SummaryCard(
                l10n: l10n,
                summary: _report!.summary,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final report = _report!;
                  final topMethod = _topMethod(l10n, report);
                  final topDay = _topDay(report);
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 230,
                        child: _SimpleMetricCard(
                          title: 'Средний чек',
                          value: formatSomoni(_avgCheck(report.summary)),
                          tone: const Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: _SimpleMetricCard(
                          title: 'Кассиров в отчёте',
                          value: '${report.cashierRevenue.byUser.length}',
                          tone: const Color(0xFF00695C),
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: _SimpleMetricCard(
                          title: 'Топ-способ оплаты',
                          value: topMethod == null
                              ? '—'
                              : '${topMethod.$1} · ${formatSomoni(topMethod.$3)}',
                          tone: const Color(0xFF7B1FA2),
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: _SimpleMetricCard(
                          title: 'Пиковый день',
                          value: topDay == null
                              ? '—'
                              : '${topDay.$1} · ${formatSomoni(topDay.$3)}',
                          tone: const Color(0xFFEF6C00),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Сверху — быстрые итоги, ниже — детализация по способам оплаты, дням, сотрудникам и списку чеков.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (_report!.summary.paymentCount == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l10n.adminReportsEmpty,
                    style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else ...[
                const SizedBox(height: 20),
                Text(
                  l10n.adminReportsByMethod,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _BreakdownTable(
                  l10n: l10n,
                  firstColumnLabel: l10n.adminReportsColumnMethod,
                  rows: _report!.byMethod
                      .map(
                        (r) => (
                          _methodLabel(l10n, r.method),
                          r.paymentCount,
                          r.totalAmount,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.adminReportsByDay,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (!_compactView)
                  _BreakdownTable(
                    l10n: l10n,
                    firstColumnLabel: l10n.adminReportsColumnDay,
                    rows: _report!.byDay
                        .map((r) => (r.day, r.paymentCount, r.totalAmount))
                        .toList(growable: false),
                  )
                else
                  Text(
                    'В кратком режиме детализация по дням скрыта.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Кто принял оплату (касса/официант)',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _AcceptedByTable(
                  rows: _report!.acceptedBy,
                  roleLabel: _roleLabel,
                ),
                const SizedBox(height: 20),
                Text(
                  'Кухня по станциям (готовые позиции)',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (!_compactView)
                  _KitchenTable(rows: _report!.kitchenByStation)
                else
                  Text(
                    'В кратком режиме блок кухни скрыт.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 20),
                if (!_compactView) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SimpleMetricCard(
                          title: 'Заказов через официанта',
                          value: '${_report!.waiterSummary.ordersAcceptedCount}',
                          tone: const Color(0xFF7C4DFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SimpleMetricCard(
                          title: 'Выручка на кассе',
                          value: formatSomoni(_report!.cashierRevenue.totalAmount),
                          tone: const Color(0xFF1B9E5A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Выручка по кассирам',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _AcceptedByTable(
                  rows: _report!.cashierRevenue.byUser,
                  roleLabel: _roleLabel,
                ),
                const SizedBox(height: 20),
                Text(
                  'Список чеков (оплаченные заказы)',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (!_compactView)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(
                        scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                      ),
                      columns: [
                        DataColumn(label: Text(l10n.adminReportsColumnTime)),
                        DataColumn(label: Text(l10n.adminReportsColumnOrder)),
                        DataColumn(label: Text(l10n.adminReportsColumnMethod)),
                        DataColumn(
                          label: Align(
                            alignment: Alignment.centerRight,
                            child: Text(l10n.adminReportsColumnAmount),
                          ),
                          numeric: true,
                        ),
                      ],
                      rows: [
                        for (final p in _report!.payments)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  p.createdAtIso.isNotEmpty
                                      ? _formatPaymentTime(p.createdAtIso, dateTimeFmt)
                                      : '—',
                                ),
                              ),
                              DataCell(Text(p.orderNumber.isNotEmpty ? p.orderNumber : '—')),
                              DataCell(Text(_methodLabel(l10n, p.method))),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(formatSomoni(p.amount)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                else
                  Text(
                    'В кратком режиме список чеков скрыт.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatPaymentTime(String iso, DateFormat fmt) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return fmt.format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _SimpleMetricCard extends StatelessWidget {
  const _SimpleMetricCard({
    required this.title,
    required this.value,
    required this.tone,
  });

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedByTable extends StatelessWidget {
  const _AcceptedByTable({
    required this.rows,
    required this.roleLabel,
  });

  final List<AdminAcceptedByRow> rows;
  final String Function(String role) roleLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodyLarge);
    }
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ),
        columns: const [
          DataColumn(label: Text('Сотрудник')),
          DataColumn(label: Text('Роль')),
          DataColumn(label: Text('Оплат'), numeric: true),
          DataColumn(label: Text('Сумма'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(r.username.isEmpty ? '—' : r.username)),
                DataCell(Text(roleLabel(r.role))),
                DataCell(Text('${r.paymentCount}')),
                DataCell(Text(formatSomoni(r.totalAmount))),
              ],
            ),
        ],
      ),
    );
  }
}

class _KitchenTable extends StatelessWidget {
  const _KitchenTable({required this.rows});

  final List<AdminKitchenStationRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodyLarge);
    }
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ),
        columns: const [
          DataColumn(label: Text('Кухня')),
          DataColumn(label: Text('Заказов'), numeric: true),
          DataColumn(label: Text('Позиций'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(r.stationName.isEmpty ? 'Без кухни' : r.stationName)),
                DataCell(Text('${r.ordersCount}')),
                DataCell(Text('${r.itemsQuantity}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.l10n,
    required this.summary,
  });

  final AppLocalizations l10n;
  final AdminSalesReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminReportsPaymentsCount(summary.paymentCount),
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminReportsTotal(formatSomoni(summary.totalAmount)),
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({
    required this.l10n,
    required this.firstColumnLabel,
    required this.rows,
  });

  final AppLocalizations l10n;
  final String firstColumnLabel;
  final List<(String label, int count, double total)> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return Text('—', style: Theme.of(context).textTheme.bodyLarge);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ),
        columns: [
          DataColumn(label: Text(firstColumnLabel)),
          DataColumn(label: Text(l10n.adminReportsColumnCountShort), numeric: true),
          DataColumn(label: Text(l10n.adminReportsColumnAmount), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text(r.$1)),
                DataCell(Text('${r.$2}')),
                DataCell(Text(formatSomoni(r.$3))),
              ],
            ),
        ],
      ),
    );
  }
}
