import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/pos/data/pos_customer_display_typing_preferences.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';

/// Редактор ротации текстов с эффектом печати на экране клиента.
class PosCustomerDisplayTypingEditor extends StatefulWidget {
  const PosCustomerDisplayTypingEditor({super.key});

  @override
  State<PosCustomerDisplayTypingEditor> createState() =>
      _PosCustomerDisplayTypingEditorState();
}

class _PosCustomerDisplayTypingEditorState
    extends State<PosCustomerDisplayTypingEditor> {
  final List<TextEditingController> _controllers = [];
  late final TextEditingController _pauseCtrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pauseCtrl = TextEditingController(text: '12');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stored = await PosCustomerDisplayTypingPreferences.load();
    final seed = stored ?? CustomerDisplayTypingConfig.fallback();
    if (!mounted) return;
    setState(() {
      _resetControllers(seed);
      _loading = false;
    });
  }

  void _resetControllers(CustomerDisplayTypingConfig config) {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    final messages = config.effectiveMessages;
    if (messages.isEmpty) {
      _controllers.add(TextEditingController());
    } else {
      for (final message in messages) {
        _controllers.add(TextEditingController(text: message));
      }
    }
    _pauseCtrl.text = config.pauseSeconds.toString();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _pauseCtrl.dispose();
    super.dispose();
  }

  CustomerDisplayTypingConfig _buildConfig() {
    final messages = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final pause = int.tryParse(_pauseCtrl.text.trim()) ?? 12;
    return CustomerDisplayTypingConfig(
      messages: messages,
      pauseSeconds: pause.clamp(3, 180),
      charDelayMs: 42,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = _buildConfig();
      await PosCustomerDisplayTypingPreferences.save(config);
      final svc = CustomerDisplayWindowService.instance;
      if (svc.isOpen && mounted) {
        final current = svc.displayContentConfig;
        final merged = await PosCustomerDisplayTypingPreferences.mergeIntoConfig(
          current,
        );
        final cart = context.read<CartBloc>().state;
        await svc.setDisplayContentConfig(merged, cart);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тексты экрана клиента сохранены')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addLine() {
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeLine(int index) {
    if (_controllers.length <= 1) {
      _controllers.first.clear();
      setState(() {});
      return;
    }
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Экран клиента — тексты внизу',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Фразы печатаются по очереди, затем пауза и следующая. '
          'Настройка сохраняется на этой кассе.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pauseCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Пауза после текста (сек.)',
            hintText: '12',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_controllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[index],
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Текст ${index + 1}',
                      hintText: 'Соберите заказ на кассе…',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить строку',
                  onPressed: () => _removeLine(index),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addLine,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить текст'),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Сохранить тексты'),
        ),
      ],
    );
  }
}
