import 'package:dk_pos/app/pos_board_layout/pos_board_layout_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Переключатели вида «Заказы» / «Счета» — доступны кассиру в настройках POS.
class PosBoardLayoutSettingsEditor extends StatelessWidget {
  const PosBoardLayoutSettingsEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PosBoardLayoutCubit, PosBoardLayoutState>(
      builder: (context, state) {
        final busy = state.loading || state.saving;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Вид списков',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Карточки или список — для экрана «Заказы» и «Счета на оплату». '
              'Можно менять прямо на кассе.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Заказы',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PosBoardLayout>(
              segments: const [
                ButtonSegment(
                  value: PosBoardLayout.cards,
                  label: Text('Карточки'),
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                ),
                ButtonSegment(
                  value: PosBoardLayout.list,
                  label: Text('Список'),
                  icon: Icon(Icons.view_list_rounded, size: 18),
                ),
              ],
              selected: {state.ordersLayout},
              onSelectionChanged: busy
                  ? null
                  : (s) => context.read<PosBoardLayoutCubit>().setOrdersLayout(
                      s.first,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              'Счета на оплату',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PosBoardLayout>(
              segments: const [
                ButtonSegment(
                  value: PosBoardLayout.cards,
                  label: Text('Карточки'),
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                ),
                ButtonSegment(
                  value: PosBoardLayout.list,
                  label: Text('Список'),
                  icon: Icon(Icons.view_list_rounded, size: 18),
                ),
              ],
              selected: {state.billsLayout},
              onSelectionChanged: busy
                  ? null
                  : (s) => context.read<PosBoardLayoutCubit>().setBillsLayout(
                      s.first,
                    ),
            ),
          ],
        );
      },
    );
  }
}
