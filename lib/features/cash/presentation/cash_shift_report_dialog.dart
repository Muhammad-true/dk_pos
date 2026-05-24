import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/cash/data/local_cash_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
}

class CashShiftReportDialog extends StatelessWidget {
  const CashShiftReportDialog({super.key, required this.report});

  final CashShiftReport report;

  @override
  Widget build(BuildContext context) {
    final s = report.shift;
    final sum = report.summary;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Отчёт кассовой смены'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Открыта: ${_fmtDate(s.openedAt)}'),
              if (s.openedByUsername != null)
                Text('Открыл: ${s.openedByUsername}'),
              Text('Закрыта: ${_fmtDate(s.closedAt)}'),
              if (s.closedByUsername != null)
                Text('Закрыл: ${s.closedByUsername}'),
              if (s.terminalId != null) Text('Касса: ${s.terminalId}'),
              const Divider(height: 24),
              _row('Размен на начало', formatSomoni(sum.openingBalance)),
              _row('Наличные продажи', formatSomoni(sum.cashSalesIn)),
              _row('Возвраты наличными', formatSomoni(sum.cashRefundsOut)),
              _row('Внесения', formatSomoni(sum.operationsIn)),
              _row('Выемки', formatSomoni(sum.operationsOut)),
              if (sum.closingExpected != null)
                _row('По расчёту', formatSomoni(sum.closingExpected!), bold: true),
              if (sum.closingActual != null)
                _row('Фактически', formatSomoni(sum.closingActual!), bold: true),
              if (sum.variance != null)
                _row(
                  'Разница',
                  formatSomoni(sum.variance!),
                  bold: true,
                  color: sum.variance!.abs() >= 0.01
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              if (s.closeNotes != null && s.closeNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Комментарий: ${s.closeNotes}'),
              ],
              if (report.operations.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Движения (${report.operations.length})',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...report.operations.map((op) {
                  final label = cashOpTypeLabels[op.opType] ?? op.opType;
                  final sign = op.direction == 'in' ? '+' : '−';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.textTheme.bodyMedium),
                              Text(
                                _fmtDate(op.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (op.comment != null && op.comment!.isNotEmpty)
                                Text(
                                  op.comment!,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text('$sign${formatSomoni(op.amount)}'),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: style),
        ],
      ),
    );
  }
}
