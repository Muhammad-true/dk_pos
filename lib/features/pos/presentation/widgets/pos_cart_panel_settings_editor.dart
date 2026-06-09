import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_cart_panel/pos_cart_panel_cubit.dart';
import 'package:dk_pos/app/pos_cart_panel/pos_cart_panel_settings.dart';

/// Настройки панели корзины: размер строк позиций и нижнего блока.
class PosCartPanelSettingsEditor extends StatelessWidget {
  const PosCartPanelSettingsEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCartPanelCubit, PosCartPanelSettings>(
      builder: (context, settings) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Корзина справа',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Сверху — прокручиваемый список позиций. '
              'Снизу: тип заказа → итог → скидка и оформление.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Строки позиций',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PosCartLineSize.values.map((size) {
                return ChoiceChip(
                  label: Text(size.label),
                  selected: settings.lineSize == size,
                  onSelected: (_) =>
                      context.read<PosCartPanelCubit>().setLineSize(size),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Нижний блок (тип / итог / кнопки)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PosCartFooterSize.values.map((size) {
                return ChoiceChip(
                  label: Text(size.label),
                  selected: settings.footerSize == size,
                  onSelected: (_) =>
                      context.read<PosCartPanelCubit>().setFooterSize(size),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Высоты элементов',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Тип заказа: ${settings.orderTypeRowHeight.round()} px • '
                      'Кнопки: ${settings.actionRowHeight.round()} px',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
