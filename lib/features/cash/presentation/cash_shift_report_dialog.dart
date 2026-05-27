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
      title: const Text('Итоги кассовой смены'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Открыта: ${_fmtDate(s.openedAt)}'),
              if (s.openedByUsername != null) Text('Открыл: ${s.openedByUsername}'),
              Text('Закрыта: ${_fmtDate(s.closedAt)}'),
              if (s.closedByUsername != null) Text('Закрыл: ${s.closedByUsername}'),
              if (s.terminalId != null) Text('Касса: ${s.terminalId}'),
              const SizedBox(height: 12),
              _sectionTitle(theme, '1. Наличные в ящике'),
              _row('Размен на начало', formatSomoni(sum.openingBalance)),
              _row('Наличные продажи', formatSomoni(sum.cashSalesIn)),
              _row('Возвраты наличными', formatSomoni(sum.cashRefundsOut)),
              _row('Внесения', formatSomoni(sum.operationsIn)),
              _row('Выемки (все)', formatSomoni(sum.operationsOut)),
              if (sum.closingExpected != null)
                _row('По расчёту в ящике', formatSomoni(sum.closingExpected!), bold: true),
              if (sum.closingActual != null)
                _row('Факт нал (пересчёт)', formatSomoni(sum.closingActual!), bold: true),
              if (sum.variance != null)
                _row(
                  'Разница нал',
                  formatSomoni(sum.variance!),
                  bold: true,
                  color: sum.variance!.abs() >= 0.01
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              const Divider(height: 28),
              _sectionTitle(theme, '2. Безнал (банки и карты)'),
              if (sum.nonCashByMethod.isEmpty)
                Text(
                  'Оплат картой/банком за смену не было.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...sum.nonCashByMethod.map(
                  (m) => _row(
                    m.title,
                    '${formatSomoni(m.net)}${m.refundsOut > 0 ? ' (возвр. ${formatSomoni(m.refundsOut)})' : ''}',
                  ),
                ),
              _row('Итого безнал', formatSomoni(sum.nonCashNet), bold: true),
              const Divider(height: 28),
              _sectionTitle(theme, '3. Внесения и выемки'),
              _row('Внесения', formatSomoni(sum.operationsIn)),
              if (sum.withdrawalRows.isEmpty)
                const Text('Выемок не было.')
              else
                ...sum.withdrawalRows.map(
                  (w) => _row(w.label, '−${formatSomoni(w.amount)}'),
                ),
              if (sum.offRegisterOut > 0.009) ...[
                const SizedBox(height: 8),
                _row(
                  'Вне кассы',
                  '−${formatSomoni(sum.offRegisterOut)}',
                  color: theme.colorScheme.error,
                  bold: true,
                ),
                Text(
                  'Вне кассы — расход не из ящика (минус). Списание со склада точки — в разделе «Склад».',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Divider(height: 28),
              _sectionTitle(theme, '4. Итог'),
              _row('Выручка за смену (все способы)', formatSomoni(sum.totalSalesNet), bold: true),
              _row('Безнал (электронно)', formatSomoni(sum.nonCashNet)),
              if (sum.closingActual != null)
                _row('Нал в ящике (факт)', formatSomoni(sum.closingActual!), bold: true),
              if (s.closeNotes != null && s.closeNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Комментарий: ${s.closeNotes}'),
              ],
              if (report.operations.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Журнал движений (${report.operations.length})',
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
                                Text(op.comment!, style: theme.textTheme.bodySmall),
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
          child: const Text('Готово'),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(value, style: style, textAlign: TextAlign.end),
        ],
      ),
    );
  }
}
