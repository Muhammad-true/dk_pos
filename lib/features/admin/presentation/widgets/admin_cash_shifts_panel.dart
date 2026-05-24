import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
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
  State<AdminCashShiftsPanel> createState() => _AdminCashShiftsPanelState();
}

class _AdminCashShiftsPanelState extends State<AdminCashShiftsPanel> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  List<CashShiftListItem> _items = [];
  bool _loading = false;
  String? _error;

  String get _branchId => AppConfig.storeBranchId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = DateTime(now.year, now.month, now.day);
    _dateFrom = _dateTo.subtract(const Duration(days: 30));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      final items = await repo.fetchClosedShifts(
        branchId: _branchId,
        from: _isoDate(_dateFrom),
        to: _isoDate(_dateTo),
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateFrom.isAfter(_dateTo)) _dateTo = _dateFrom;
      } else {
        _dateTo = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateFrom = _dateTo;
      }
    });
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
        builder: (ctx) => CashShiftReportDialog(report: report),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
              'Закрытые смены и все движения по кассе. Доступно только администратору.',
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
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('С ${_isoDate(_dateFrom)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('По ${_isoDate(_dateTo)}'),
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
              ],
            ),
            const SizedBox(height: 16),
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
                        'За выбранный период закрытых смен нет',
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
                            DataColumn(label: Text('Открыл')),
                            DataColumn(label: Text('Закрыл')),
                            DataColumn(label: Text('По расчёту'), numeric: true),
                            DataColumn(label: Text('Факт'), numeric: true),
                            DataColumn(label: Text('Разница'), numeric: true),
                            DataColumn(label: Text('')),
                          ],
                          rows: _items.map((s) {
                            final variance = s.variance;
                            return DataRow(
                              cells: [
                                DataCell(Text(_fmtDateTime(s.closedAt))),
                                DataCell(Text(s.terminalId ?? '—')),
                                DataCell(Text(s.openedByUsername ?? '—')),
                                DataCell(Text(s.closedByUsername ?? '—')),
                                DataCell(Text(
                                  s.closingExpected != null
                                      ? formatSomoni(s.closingExpected!)
                                      : '—',
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
                                DataCell(
                                  TextButton(
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
