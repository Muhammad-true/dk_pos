import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';

/// Переключение светлой / тёмной темы рабочих экранов (как на кассе).
class PosThemeToggleIconButton extends StatelessWidget {
  const PosThemeToggleIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<PosThemeCubit>().state;
    final dark = settings.mode == PosScreenTheme.dark;
    return IconButton(
      tooltip: dark ? 'Светлая тема' : 'Тёмная тема',
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      onPressed: () => context.read<PosThemeCubit>().setTheme(
            dark ? PosScreenTheme.light : PosScreenTheme.dark,
          ),
    );
  }
}
