import 'package:flutter/material.dart';

import 'package:dk_pos/features/pos/data/pos_ui_preferences.dart';

/// Переключатель «анимация товара в корзину» в настройках POS.
class PosFlyToCartSettingSwitch extends StatefulWidget {
  const PosFlyToCartSettingSwitch({super.key});

  @override
  State<PosFlyToCartSettingSwitch> createState() =>
      _PosFlyToCartSettingSwitchState();
}

class _PosFlyToCartSettingSwitchState extends State<PosFlyToCartSettingSwitch> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    PosUiPreferences.loadFlyToCartEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Касса',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Визуальные подсказки при наборе заказа на этом терминале.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Анимация в корзину'),
          subtitle: const Text(
            'При добавлении товара миниатюра летит в панель корзины',
          ),
          value: enabled ?? true,
          onChanged: enabled == null
              ? null
              : (value) async {
                  setState(() => _enabled = value);
                  await PosUiPreferences.setFlyToCartEnabled(value);
                },
        ),
      ],
    );
  }
}
