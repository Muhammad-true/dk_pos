import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_cubit.dart';
import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_settings.dart';
import 'package:dk_pos/features/pos/presentation/utils/cashier_table_headline.dart';

/// Конструктор карточек заказов/счетов на кассе: размеры и номер стола сверху.
class PosCashierBoardSettingsEditor extends StatelessWidget {
  const PosCashierBoardSettingsEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCashierBoardCubit, PosCashierBoardSettings>(
      builder: (context, settings) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final cubit = context.read<PosCashierBoardCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Карточки заказов и счетов',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Размер карточки и текста для «Заказы» и «Счета на оплату». '
              'Номер стола — красный; без стола пишется «Без стола». '
              'Сохраняется на этом устройстве.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => cubit.applyPreset(
                    PosCashierBoardSettings.compactPreset,
                  ),
                  child: const Text('Компакт'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      cubit.applyPreset(PosCashierBoardSettings.defaults),
                  child: const Text('Обычный'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      cubit.applyPreset(PosCashierBoardSettings.large),
                  child: const Text('Крупный'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Плотность карточки',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PosCashierCardDensity.values.map((d) {
                return ChoiceChip(
                  label: Text(d.label),
                  selected: settings.density == d,
                  onSelected: (_) => cubit.setDensity(d),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Номер стола сверху'),
              subtitle: const Text(
                'Крупно в шапке карточки; строка «Сменить стол» остаётся ниже',
              ),
              value: settings.showTableOnTop,
              onChanged: cubit.setShowTableOnTop,
            ),
            _ScaleSlider(
              label: 'Размер номера стола',
              value: settings.tableHeadlineScale,
              onChanged: cubit.setTableHeadlineScale,
            ),
            _ScaleSlider(
              label: '№ заказа и сумма',
              value: settings.titleScale,
              onChanged: cubit.setTitleScale,
            ),
            _ScaleSlider(
              label: 'Названия блюд',
              value: settings.itemTextScale,
              onChanged: cubit.setItemTextScale,
            ),
            const SizedBox(height: 10),
            _CashierCardPreview(settings: settings),
          ],
        );
      },
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  const _ScaleSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          min: 0.8,
          max: 1.8,
          divisions: 20,
          value: value.clamp(0.8, 1.8),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CashierCardPreview extends StatelessWidget {
  const _CashierCardPreview({required this.settings});

  final PosCashierBoardSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleBase = theme.textTheme.titleMedium?.fontSize ?? 16;
    final bodyBase = theme.textTheme.bodyMedium?.fontSize ?? 14;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.all(settings.cardPadding * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Предпросмотр',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: settings.sectionGap),
            if (settings.showTableOnTop)
              Text(
                'Зал 7',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: (titleBase + 6) * settings.tableHeadlineScale,
                  color: kCashierTableNumberRed,
                  height: 1.05,
                ),
              ),
            if (settings.showTableOnTop) SizedBox(height: settings.sectionGap * 0.6),
            Text(
              '№ 42 · 85.00 с.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: titleBase * settings.titleScale,
              ),
            ),
            SizedBox(height: settings.sectionGap * 0.5),
            Text(
              '• 2× Донер · Наггетсы 10 шт',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: bodyBase * settings.itemTextScale,
              ),
            ),
            SizedBox(height: settings.sectionGap * 0.5),
            Text(
              'Без стола',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                fontSize: (bodyBase) * settings.tableHeadlineScale * 0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
