import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';

/// Те же ключи, что на backend `serverEnvEditableKeys.js` (секреты — не подставляем текст).
const _secretKeys = {'GLOBAL_SYNC_TOKEN', 'GLOBAL_UPDATE_CLIENT_TOKEN'};

/// Блок админки: параметры глобала / синка как у `.env`, хранение в БД + перезапуск backend.
class AdminServerEnvSection extends StatefulWidget {
  const AdminServerEnvSection({super.key});

  @override
  State<AdminServerEnvSection> createState() => _AdminServerEnvSectionState();
}

class _AdminServerEnvSectionState extends State<AdminServerEnvSection> {
  AdminServerEnvConfig? _cfg;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _pendingRemove = {};
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await context.read<AdminReportsRepository>().fetchServerEnv();
      if (!mounted) return;
      _disposeControllers();
      _controllers.clear();
      for (final g in cfg.groups) {
        for (final k in g.keys) {
          if (_secretKeys.contains(k)) {
            _controllers[k] = TextEditingController();
          } else {
            _controllers[k] = TextEditingController(text: cfg.effectivePlain[k] ?? '');
          }
        }
      }
      setState(() {
        _cfg = cfg;
        _loading = false;
        _pendingRemove.clear();
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
    final cfg = _cfg;
    if (cfg == null || _saving) return;
    setState(() => _saving = true);
    try {
      final upsert = <String, String>{};
      for (final g in cfg.groups) {
        for (final k in g.keys) {
          if (_pendingRemove.contains(k)) continue;
          final ctrl = _controllers[k];
          if (ctrl == null) continue;
          final t = ctrl.text.trim();
          if (_secretKeys.contains(k)) {
            if (t.isNotEmpty) upsert[k] = t;
          } else {
            upsert[k] = t;
          }
        }
      }
      final result = await context.read<AdminReportsRepository>().saveServerEnv(
            upsert: upsert,
            removeKeys: _pendingRemove.toList(growable: false),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
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
    final text = Theme.of(context).textTheme;

    if (_loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Загрузка параметров сервера…', style: text.bodyMedium),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Card(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('server-env: $_error'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final cfg = _cfg!;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Сервер: глобал и синк (как в .env)',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Хранится в БД; после «Сохранить» перезапустите Node (служба / PM2 / docker).',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            cfg.hint,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final g in cfg.groups) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                g.label,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 6),
            for (final k in g.keys) _fieldRow(context, cfg, k),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Сохранить в БД'),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(BuildContext context, AdminServerEnvConfig cfg, String k) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ctrl = _controllers[k];
    if (ctrl == null) return const SizedBox.shrink();
    final isSecret = _secretKeys.contains(k);
    final stored = cfg.storedOverrideKeys.contains(k);
    final pendingRm = _pendingRemove.contains(k);
    final secretSet = cfg.secretIsSet[k] == true;

    final help = cfg.keyHelp[k];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: text.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (stored)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.storage_rounded, size: 16, color: scheme.primary),
                ),
              if (stored || pendingRm)
                TextButton(
                  onPressed: pendingRm
                      ? () => setState(() => _pendingRemove.remove(k))
                      : () => setState(() => _pendingRemove.add(k)),
                  child: Text(pendingRm ? 'Отменить сброс' : 'Сброс из БД'),
                ),
            ],
          ),
          if (help != null &&
              (help.purpose.trim().isNotEmpty || help.values.trim().isNotEmpty)) ...[
            if (help.purpose.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    children: [
                      TextSpan(
                        text: 'Зачем: ',
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(text: help.purpose.trim()),
                    ],
                  ),
                ),
              ),
            if (help.values.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    children: [
                      TextSpan(
                        text: 'Какие значения: ',
                        style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(text: help.values.trim()),
                    ],
                  ),
                ),
              ),
          ],
          if (pendingRm)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'После сохранения и перезапуска значение возьмётся из файла .env (если задано).',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          TextField(
            controller: ctrl,
            enabled: !pendingRm,
            obscureText: isSecret,
            maxLines: isSecret ? 1 : 2,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: isSecret
                  ? (secretSet
                      ? 'Задано на сервере. Введите новое целиком, чтобы заменить.'
                      : 'Вставьте токен')
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
