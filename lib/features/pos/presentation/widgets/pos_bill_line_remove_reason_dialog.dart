import 'package:flutter/material.dart';

/// Коды причин убирания позиции из счёта (кухня уже приняла в работу).
const billLineRemoveReasonCodes = <String>[
  'ошибка_клиента',
  'ошибка_кассира',
  'клиент_отказал',
  'клиент_не_оплатил_товар',
  'порченый_товар',
];

String billLineRemoveReasonLabel(String code) {
  return switch (code) {
    'ошибка_клиента' => 'Ошибка клиента',
    'ошибка_кассира' => 'Ошибка кассира',
    'клиент_отказал' => 'Клиент отказал',
    'клиент_не_оплатил_товар' => 'Клиент не оплатил этот товар',
    'порченый_товар' => 'Порченый товар',
    _ => code.replaceAll('_', ' '),
  };
}

/// `null` — отмена диалога.
Future<String?> pickBillLineRemoveReason(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      var selected = billLineRemoveReasonCodes.first;
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text(
              'Причина убирания позиции',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Позиция уже принята на кухне. Укажите причину.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final code in billLineRemoveReasonCodes)
                        ChoiceChip(
                          label: Text(
                            billLineRemoveReasonLabel(code),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          selected: selected == code,
                          onSelected: (_) => setState(() => selected = code),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Убрать'),
              ),
            ],
          );
        },
      );
    },
  );
}
