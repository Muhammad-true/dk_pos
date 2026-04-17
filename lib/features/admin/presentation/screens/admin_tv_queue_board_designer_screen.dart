import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:dk_digitial_menu/models/local_queue_models.dart';
import 'package:dk_digitial_menu/models/tv_queue_board_theme.dart';
import 'package:dk_digitial_menu/ui/tv_fast_food_queue_board.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/theme_admin_repository.dart';

/// Конструктор оформления **ТВ-очереди** (не клиентский экран меню): цвета, размеры, анимация.
class AdminTvQueueBoardDesignerScreen extends StatefulWidget {
  const AdminTvQueueBoardDesignerScreen({super.key});

  static final LocalQueueSnapshot _previewQueue = LocalQueueSnapshot(
    preparing: [
      LocalQueueOrderItem(id: 'p1', number: '14', status: 'cooking'),
      LocalQueueOrderItem(id: 'p2', number: '27', status: 'cooking'),
      LocalQueueOrderItem(id: 'p3', number: '31', status: 'cooking'),
    ],
    ready: [
      LocalQueueOrderItem(id: 'r1', number: '9', status: 'ready'),
      LocalQueueOrderItem(id: 'r2', number: '22', status: 'ready'),
    ],
  );

  @override
  State<AdminTvQueueBoardDesignerScreen> createState() =>
      _AdminTvQueueBoardDesignerScreenState();
}

class _AdminTvQueueBoardDesignerScreenState
    extends State<AdminTvQueueBoardDesignerScreen> {
  int? _themeId;
  final Map<String, dynamic> _overrides = {};
  bool _loading = true;
  String? _error;
  bool _saving = false;

  ThemeAdminRepository get _repo => context.read<ThemeAdminRepository>();

  TvQueueBoardTheme get _live => TvQueueBoardTheme.fromJson(_overrides);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchActiveTheme();
      if (!mounted) return;
      final id = data['id'];
      _themeId = id is int ? id : int.tryParse(id?.toString() ?? '');
      final raw = data['tvQueueBoard'];
      _overrides.clear();
      if (raw is Map) {
        _overrides.addAll(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      if (!mounted) return;
      _error = e is ApiException ? e.message : '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final id = _themeId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет id темы — сохранение невозможно')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.patchTheme(id, {'tvQueueBoard': _live.toJson()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено. ТВ подхватит при следующем опросе очереди.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _set(String key, Object? value) {
    setState(() {
      if (value == null) {
        _overrides.remove(key);
      } else {
        _overrides[key] = value;
      }
    });
  }

  Widget _hexField(String label, String key) {
    final v =
        (_overrides[key] ?? TvQueueBoardTheme.defaults.toJson()[key] ?? '')
            .toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey<String>('$key|${_overrides[key] ?? '_'}'),
        initialValue: v.toString().startsWith('#') ? v : '#$v',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
        ],
        onFieldSubmitted: (s) {
          final t = s.trim();
          if (t.isEmpty) {
            _set(key, null);
          } else {
            _set(key, t.startsWith('#') ? t : '#$t');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ТВ-очередь: оформление'),
        actions: [
          IconButton(
            tooltip: 'Обновить с сервера',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
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
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Это настройки экрана очереди на ТВ (режим TV_QUEUE_ONLY), '
                      'а не слайды меню для гостя.',
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Превью',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: TvFastFoodQueueBoard(
                            queue: AdminTvQueueBoardDesignerScreen._previewQueue,
                            theme: _live,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Анимация списка номеров',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text('Интервал смены, с: ${_live.rotorRotateSeconds}'),
                    Slider(
                      value: _live.rotorRotateSeconds.toDouble().clamp(1, 30),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${_live.rotorRotateSeconds} с',
                      onChanged: (x) => _set('rotorRotateSeconds', x.round()),
                    ),
                    Text('Длительность сдвига, мс: ${_live.rotorShiftMs}'),
                    Slider(
                      value: _live.rotorShiftMs.toDouble().clamp(120, 3000),
                      min: 120,
                      max: 3000,
                      divisions: 48,
                      label: '${_live.rotorShiftMs} мс',
                      onChanged: (x) => _set('rotorShiftMs', x.round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Шапка и полоски',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text('Доля высоты шапки: ${_live.headerHeightFraction.toStringAsFixed(2)}'),
                    Slider(
                      value: _live.headerHeightFraction.clamp(0.08, 0.4),
                      min: 0.08,
                      max: 0.4,
                      onChanged: (x) => _set('headerHeightFraction', x),
                    ),
                    Text('Множитель ширины полоски: ${_live.stripeWidthMult.toStringAsFixed(2)}'),
                    Slider(
                      value: _live.stripeWidthMult.clamp(0.5, 6),
                      min: 0.5,
                      max: 6,
                      onChanged: (x) => _set('stripeWidthMult', x),
                    ),
                    Text('Множитель высоты полоски: ${_live.stripeHeightMult.toStringAsFixed(2)}'),
                    Slider(
                      value: _live.stripeHeightMult.clamp(0.05, 1.2),
                      min: 0.05,
                      max: 1.2,
                      onChanged: (x) => _set('stripeHeightMult', x),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Цвета (#RRGGBB), Enter в поле — применить',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _hexField('Фон «Готовятся»', 'preparingBg'),
                    _hexField('Фон «Готовы»', 'readyBg'),
                    _hexField('Плитка номера (слева)', 'preparingChip'),
                    _hexField('Плитка номера (справа)', 'readyTile'),
                    _hexField('Акцентный красный', 'brandRed'),
                    _hexField('Заголовок слева (основной)', 'headerPrimaryPreparing'),
                    _hexField('Заголовок справа (основной)', 'headerPrimaryReady'),
                    _hexField('Подзаголовок слева', 'headerSecondaryPreparing'),
                    _hexField('Подзаголовок справа', 'headerSecondaryReady'),
                    _hexField('Полоски слева', 'stripePreparing'),
                    _hexField('Полоски справа', 'stripeReady'),
                    _hexField('Номер слева', 'numberPreparing'),
                    _hexField('Номер справа', 'numberReady'),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
