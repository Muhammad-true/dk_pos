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
  const CashShiftReportDialog({
    super.key,
    required this.report,
    this.globalSync,
  });

  final CashShiftReport report;
  final CashShiftGlobalSync? globalSync;

  @override
  Widget build(BuildContext context) {
    final s = report.shift;
    final sum = report.summary;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final noEnc = !sum.encashmentWasDone;
    final cashAbove = sum.cashAboveReserve ??
        (sum.closingActual != null && sum.minReserve != null
            ? (sum.closingActual! - sum.minReserve!).clamp(0.0, double.infinity)
            : null);

    return AlertDialog(
      title: Text('Смена №${s.id}${s.terminalId != null ? ' · ${s.terminalId}' : ''}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Открыта: ${_fmtDate(s.openedAt)}${s.openedByUsername != null ? ' · ${s.openedByUsername}' : ''}'),
              Text('Закрыта: ${_fmtDate(s.closedAt)}${s.closedByUsername != null ? ' · ${s.closedByUsername}' : ''}'),
              if (noEnc && sum.closingActual != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Инкассация не была',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'После закрытия в ящике по учёту ${formatSomoni(sum.closingActual!)}'
                        '${cashAbove != null && cashAbove > 0.009 ? ' (${formatSomoni(cashAbove)} сверх размена)' : ''}. '
                        'При принятии смены в админке укажите этот факт — нал сядет на баланс.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _sectionTitle(theme, 'Сводка смены'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(
                    label: 'Выручка',
                    value: formatSomoni(sum.totalSalesNet),
                    scheme: scheme,
                    bold: true,
                  ),
                  _SummaryChip(
                    label: 'Нал продажи',
                    value: formatSomoni(sum.cashSalesIn),
                    scheme: scheme,
                  ),
                  _SummaryChip(
                    label: 'Безнал',
                    value: formatSomoni(sum.nonCashNet),
                    scheme: scheme,
                  ),
                  _SummaryChip(
                    label: 'Инкассация',
                    value: sum.encashmentWasDone
                        ? formatSomoni(sum.encashmentTotal)
                        : 'не было',
                    scheme: scheme,
                    highlight: sum.encashmentWasDone,
                    warn: noEnc,
                  ),
                  if (sum.closingExpected != null)
                    _SummaryChip(
                      label: 'В ящике по учёту',
                      value: formatSomoni(sum.closingExpected!),
                      scheme: scheme,
                      bold: true,
                    ),
                  if (sum.closingActual != null)
                    _SummaryChip(
                      label: 'Факт в ящике',
                      value: formatSomoni(sum.closingActual!),
                      scheme: scheme,
                      bold: true,
                      warn: noEnc,
                    ),
                  _SummaryChip(
                    label: 'Разница нал',
                    value: sum.variance != null ? formatSomoni(sum.variance!) : '—',
                    scheme: scheme,
                    warn: sum.variance != null && sum.variance!.abs() >= 0.01,
                  ),
                  if (sum.nonCashVarianceTotal != null)
                    _SummaryChip(
                      label: 'Разница безнал',
                      value: formatSomoni(sum.nonCashVarianceTotal!),
                      scheme: scheme,
                      warn: sum.nonCashVarianceTotal!.abs() >= 0.01,
                    ),
                ],
              ),
              if (sum.nonCashByMethod.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Банки / безнал:',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                ...sum.nonCashByMethod.map((m) {
                  final hasActual = m.actualNet != null;
                  final variance = m.variance;
                  return _row(
                    m.title,
                    hasActual
                        ? 'POS ${formatSomoni(m.displayExpected)} → '
                            'факт ${formatSomoni(m.actualNet!)}'
                            '${variance != null && variance.abs() >= 0.01 ? ' (Δ ${formatSomoni(variance)})' : ''}'
                        : '${formatSomoni(m.net)}${m.refundsOut > 0 ? ' (возвр. ${formatSomoni(m.refundsOut)})' : ''}',
                    color: variance != null && variance.abs() >= 0.01
                        ? theme.colorScheme.error
                        : null,
                  );
                }),
              ],
              const Divider(height: 28),
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
                ...sum.nonCashByMethod.map((m) {
                  if (m.actualNet != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _row('${m.title} — по POS', formatSomoni(m.displayExpected)),
                        _row(
                          '${m.title} — факт',
                          formatSomoni(m.actualNet!),
                          bold: true,
                        ),
                        if (m.variance != null && m.variance!.abs() >= 0.01)
                          _row(
                            '${m.title} — разница',
                            formatSomoni(m.variance!),
                            bold: true,
                            color: theme.colorScheme.error,
                          ),
                      ],
                    );
                  }
                  return _row(
                    m.title,
                    '${formatSomoni(m.net)}${m.refundsOut > 0 ? ' (возвр. ${formatSomoni(m.refundsOut)})' : ''}',
                  );
                }),
              _row('Итого безнал (POS)', formatSomoni(sum.nonCashNet), bold: true),
              if (sum.nonCashVarianceTotal != null)
                _row(
                  'Разница безнал (всего)',
                  formatSomoni(sum.nonCashVarianceTotal!),
                  bold: true,
                  color: sum.nonCashVarianceTotal!.abs() >= 0.01
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              const Divider(height: 28),
              _sectionTitle(theme, '3. Внесения и выемки'),
              _row('Внесения', formatSomoni(sum.operationsIn)),
              _row(
                'Инкассация в сейф',
                sum.encashmentTotal > 0.009
                    ? '−${formatSomoni(sum.encashmentTotal)}'
                    : 'не было',
                bold: sum.encashmentTotal > 0.009,
              ),
              if (sum.withdrawalRows
                      .where(
                        (w) =>
                            w.opType != 'encashment' &&
                            w.opType != 'encashment_off_register',
                      )
                      .isEmpty &&
                  sum.encashmentTotal <= 0.009)
                const Text('Других выемок не было.')
              else ...[
                ...sum.withdrawalRows
                    .where(
                      (w) =>
                          w.opType != 'encashment' &&
                          w.opType != 'encashment_off_register',
                    )
                    .map((w) => _row(w.label, '−${formatSomoni(w.amount)}')),
              ],
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
              _sectionTitle(theme, '4. После закрытия смены'),
              if (sum.closingActual != null) ...[
                _row('Нал в ящике (факт пересчёта)', formatSomoni(sum.closingActual!), bold: true),
                if (sum.minReserve != null)
                  _row('Размен (резерв)', formatSomoni(sum.minReserve!)),
                if (cashAbove != null && cashAbove > 0.009)
                  _row(
                    'Сверх размена (не инкассировано)',
                    formatSomoni(cashAbove),
                    bold: true,
                    color: scheme.error,
                  ),
              ] else
                Text(
                  'Смена ещё не закрыта или пересчёт не зафиксирован.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const Divider(height: 28),
              _sectionTitle(theme, '5. Итог'),
              _row('Выручка за смену (все способы)', formatSomoni(sum.totalSalesNet), bold: true),
              _row('Безнал (электронно)', formatSomoni(sum.nonCashNet)),
              _row(
                'Инкассация в сейф',
                sum.encashmentWasDone ? formatSomoni(sum.encashmentTotal) : 'не было',
                bold: true,
                color: noEnc ? scheme.error : null,
              ),
              if (sum.closingActual != null)
                _row('Нал в ящике после закрытия', formatSomoni(sum.closingActual!), bold: true),
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
              if (globalSync != null) ...[
                const Divider(height: 24),
                _syncBanner(theme, globalSync!),
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

  Widget _syncBanner(ThemeData theme, CashShiftGlobalSync sync) {
    final ok = sync.ok || sync.status == 'sent';
    final bg = ok
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
        : sync.status == 'pending'
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.errorContainer.withValues(alpha: 0.45);
    final title = ok ? 'Отчёт отправлен в global admin' : sync.shortLabel;
    final body = sync.message?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodySmall),
          ],
          if (!ok && sync.lastError != null && sync.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Причина: ${sync.lastError}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.scheme,
    this.bold = false,
    this.highlight = false,
    this.warn = false,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final bool bold;
  final bool highlight;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final bg = warn
        ? scheme.errorContainer.withValues(alpha: 0.55)
        : highlight
        ? scheme.primaryContainer.withValues(alpha: 0.65)
        : scheme.surfaceContainerHighest;
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: warn ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
