import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/admin/data/local_order_handout_settings_repository.dart';

/// Автовыдача: вкл/выкл и интервал (минуты в статусе «Готов к выдаче»).
class AdminAutoHandoutSection extends StatefulWidget {
  const AdminAutoHandoutSection({super.key});

  @override
  State<AdminAutoHandoutSection> createState() => _AdminAutoHandoutSectionState();
}

class _AdminAutoHandoutSectionState extends State<AdminAutoHandoutSection> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  late final TextEditingController _minutesCtrl;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _minutesCtrl = TextEditingController(text: '20');
    _reload();
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await context
          .read<LocalOrderHandoutSettingsRepository>()
          .fetch(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _enabled = s.autoHandoutEnabled;
        _minutesCtrl.text = '${s.autoHandoutMinutes}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    if (_enabled && (minutes == null || minutes < 1 || minutes > 24 * 60)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите время от 1 до 1440 минут'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<LocalOrderHandoutSettingsRepository>().update(
            autoHandoutEnabled: _enabled,
            autoHandoutMinutes: _enabled ? minutes! : (minutes ?? 20),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _enabled
                ? 'Автовыдача включена ($minutes мин)'
                : 'Автовыдача выключена',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Не удалось загрузить настройки автовыдачи',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text('$_error', style: textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Автовыдача'),
              subtitle: Text(
                _enabled
                    ? 'Заказы в «Готов к выдаче» автоматически переходят в «Выдан»'
                    : 'Выдача только вручную с кассы или экспедитора',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _enabled = v),
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _minutesCtrl,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Время до автовыдачи (минуты)',
                  helperText:
                      'Отсчёт с момента «Готов к выдаче» (поле ready_at). От 1 до 1440.',
                  border: OutlineInputBorder(),
                  suffixText: 'мин',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
