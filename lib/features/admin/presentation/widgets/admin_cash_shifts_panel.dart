import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';
import 'package:dk_pos/features/cash/presentation/cash_shift_report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Закрытые кассовые смены и отчёты с движениями (только admin POS).
class AdminCashShiftsPanel extends StatefulWidget {
  const AdminCashShiftsPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  AdminCashShiftsPanelState createState() => AdminCashShiftsPanelState();
}

/// Публичный state — [AdminOrdersHub] вызывает [reload] при переходе на вкладку.
class AdminCashShiftsPanelState extends State<AdminCashShiftsPanel> {
  List<CashShiftListItem> _items = [];
  CashEncashmentAlert? _encashmentAlert;
  bool _loading = false;
  String? _error;
  bool _newestFirst = true;

  String get _branchId => AppConfig.storeBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Обновить список (после закрытия смены на кассе или смены вкладки).
  Future<void> reload() => _load();

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalCashRepository>();
      final result = await repo.fetchClosedShifts(
        branchId: _branchId,
        sort: _newestFirst ? 'desc' : 'asc',
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _encashmentAlert = result.encashmentAlert;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _items = [];
      });
    }
  }

  Future<void> _toggleSort(bool newestFirst) async {
    if (_newestFirst == newestFirst) return;
    setState(() => _newestFirst = newestFirst);
    await _load();
  }

  Future<void> _openReport(CashShiftListItem item) async {
    try {
      final repo = context.read<LocalCashRepository>();
      final report = await repo.fetchShiftReport(
        shiftId: item.id,
        branchId: _branchId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => CashShiftReportDialog(
          report: report,
          globalSync: item.globalSync,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _retryGlobalSync() async {
    try {
      final result = await context.read<AdminReportsRepository>().triggerPushNow(
        branchId: _branchId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _syncCell(CashShiftGlobalSync? sync, ThemeData theme) {
    if (sync == null) {
      return const Text('—');
    }
    final ok = sync.ok || sync.status == 'sent';
    final color = ok
        ? theme.colorScheme.primary
        : sync.status == 'pending'
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sync.shortLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        if (sync.message != null && sync.message!.isNotEmpty)
          Text(
            sync.message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Кассовые смены',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Все закрытые смены. Видно: была ли инкассация, сколько нал осталось в ящике после закрытия. '
              'Полный отчёт — «Отчёт». На global admin — через 1–2 мин после синка.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Сначала новые'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Сначала старые'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                  ],
                  selected: {_newestFirst},
                  onSelectionChanged: (s) => _toggleSort(s.first),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Обновить'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _retryGlobalSync,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Отправить в global'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_encashmentAlert != null && _encashmentAlert!.message.isNotEmpty)
              Card(
                color: _encashmentAlert!.shiftsWithoutEncashment >= 2
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.tertiaryContainer,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _encashmentAlert!.shiftsWithoutEncashment >= 2
                            ? 'Инкассация давно не делалась'
                            : 'Инкассации не было',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_encashmentAlert!.message),
                      if (_encashmentAlert!.daysSinceEncashment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Дней с последней инкассации: ${_encashmentAlert!.daysSinceEncashment}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? Center(
                      child: Text(
                        'Закрытых смен пока нет',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Card(
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Закрыта')),
                            DataColumn(label: Text('Касса')),
                            DataColumn(label: Text('Выручка'), numeric: true),
                            DataColumn(label: Text('Безнал'), numeric: true),
                            DataColumn(label: Text('Инкассация'), numeric: true),
                            DataColumn(label: Text('В кассе после закр.'), numeric: true),
                            DataColumn(label: Text('Разница'), numeric: true),
                            DataColumn(label: Text('Global')),
                            DataColumn(label: Text('')),
                          ],
                          rows: _items.map((s) {
                            final variance = s.variance;
                            final p = s.preview;
                            final noEnc = p != null && !p.encashmentDone;
                            return DataRow(
                              color: noEnc
                                  ? WidgetStatePropertyAll(
                                      theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                                    )
                                  : null,
                              cells: [
                                DataCell(Text(_fmtDateTime(s.closedAt))),
                                DataCell(Text(s.terminalId ?? '—')),
                                DataCell(Text(
                                  p != null && p.totalSalesNet > 0
                                      ? formatSomoni(p.totalSalesNet)
                                      : '—',
                                )),
                                DataCell(Tooltip(
                                  message: p?.nonCashBrief ?? '',
                                  child: Text(
                                    p != null && p.nonCashNet > 0.009
                                        ? formatSomoni(p.nonCashNet)
                                        : '—',
                                  ),
                                )),
                                DataCell(Text(
                                  p != null && p.encashmentDone
                                      ? formatSomoni(p.encashmentTotal)
                                      : 'не было',
                                  style: noEnc
                                      ? TextStyle(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                )),
                                DataCell(Text(
                                  s.closingActual != null
                                      ? formatSomoni(s.closingActual!)
                                      : '—',
                                )),
                                DataCell(Text(
                                  variance != null
                                      ? formatSomoni(variance)
                                      : '—',
                                  style: variance != null &&
                                          variance.abs() >= 0.01
                                      ? TextStyle(color: theme.colorScheme.error)
                                      : null,
                                )),
                                DataCell(_syncCell(s.globalSync, theme)),
                                DataCell(
                                  FilledButton.tonal(
                                    onPressed: () => _openReport(s),
                                    child: const Text('Отчёт'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
