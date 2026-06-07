import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dk_digitial_menu/models/local_queue_models.dart';
import 'package:dk_digitial_menu/models/tv_queue_board_theme.dart';
import 'package:dk_digitial_menu/ui/tv_fast_food_queue_board.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/theme_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_color_picker_field.dart';

/// Конструктор оформления **ТВ-очереди** (не клиентский экран меню): цвета, размеры, анимация.
class AdminTvQueueBoardDesignerScreen extends StatefulWidget {
  const AdminTvQueueBoardDesignerScreen({super.key});

  static final LocalQueueSnapshot _previewQueue = LocalQueueSnapshot(
    preparing: [
      LocalQueueOrderItem(
        id: 'demo-delivery-101',
        number: '101',
        status: 'cooking',
        orderType: 'delivery',
      ),
      LocalQueueOrderItem(
        id: 'p-pickup',
        number: '27',
        status: 'cooking',
        orderType: 'pickup',
      ),
      LocalQueueOrderItem(
        id: 'p-hall',
        number: '31',
        status: 'cooking',
        orderType: 'dine_in',
        tableLabel: 'Зал • стол 5',
      ),
      LocalQueueOrderItem(id: 'p-plain', number: '14', status: 'cooking'),
    ],
    ready: [
      LocalQueueOrderItem(
        id: 'r-delivery',
        number: '88',
        status: 'ready',
        orderType: 'delivery',
      ),
      LocalQueueOrderItem(
        id: 'r-pickup',
        number: '9',
        status: 'ready',
        orderType: 'takeaway',
      ),
      LocalQueueOrderItem(
        id: 'r-hall',
        number: '22',
        status: 'ready',
        orderType: 'на месте',
        tableLabel: 'Веранда • стол 2',
      ),
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

  Widget _textField(String label, String key) {
    final v =
        (_overrides[key] ?? TvQueueBoardTheme.defaults.toJson()[key] ?? '')
            .toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey<String>('txt|$key|${_overrides[key] ?? '_'}'),
        initialValue: v,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onFieldSubmitted: (s) {
          final t = s.trim();
          if (t.isEmpty) {
            _set(key, null);
          } else {
            _set(key, t);
          }
        },
      ),
    );
  }

  Widget _colorField(String label, String key) {
    final defaults = TvQueueBoardTheme.defaults.toJson();
    final raw = (_overrides[key] ?? defaults[key] ?? '').toString();
    final value = normalizeAdminHexColor(raw, fallback: '#FFFFFF');
    final isOverride = _overrides.containsKey(key);
    return AdminColorPickerField(
      key: ValueKey<String>('color|$key|${_overrides[key] ?? '_'}'),
      label: label,
      value: value,
      allowClear: isOverride,
      onClear: isOverride ? () => _set(key, null) : null,
      onChanged: (hex) => _set(key, hex),
      compact: true,
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
                      'Заголовки колонок',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _textField('«Готовятся» (RU)', 'labelPreparingRu'),
                    _textField('«Готовятся» (EN)', 'labelPreparingEn'),
                    _textField('«Готовы» (RU)', 'labelReadyRu'),
                    _textField('«Готовы» (EN)', 'labelReadyEn'),
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
                      'Цвета — нажмите на образец или «Выбрать цвет»',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _colorField('Фон «Готовятся»', 'preparingBg'),
                    _colorField('Фон «Готовы»', 'readyBg'),
                    _colorField('Плитка номера (слева)', 'preparingChip'),
                    _colorField('Плитка номера (справа)', 'readyTile'),
                    _colorField('Акцентный красный', 'brandRed'),
                    _colorField('Заголовок слева (основной)', 'headerPrimaryPreparing'),
                    _colorField('Заголовок справа (основной)', 'headerPrimaryReady'),
                    _colorField('Подзаголовок слева', 'headerSecondaryPreparing'),
                    _colorField('Подзаголовок справа', 'headerSecondaryReady'),
                    _colorField('Полоски слева', 'stripePreparing'),
                    _colorField('Полоски справа', 'stripeReady'),
                    _colorField('Номер слева', 'numberPreparing'),
                    _colorField('Номер справа', 'numberReady'),
                    _colorField('Рамка плитки слева', 'tileBorderPreparing'),
                    _colorField('Рамка плитки справа', 'tileBorderReady'),
                    _colorField('Свечение слева', 'accentPreparing'),
                    _colorField('Свечение справа', 'accentReady'),
                    const SizedBox(height: 16),
                    Text(
                      'Размеры плиток с номерами',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Множитель шрифта номера: ${_live.tileFontSizeMult.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: _live.tileFontSizeMult.clamp(0.2, 0.65),
                      min: 0.2,
                      max: 0.65,
                      onChanged: (x) => _set('tileFontSizeMult', x),
                    ),
                    Text(
                      'Ширина плитки (% экрана): ${(_live.tileWidthFraction * 100).round()}%',
                    ),
                    Slider(
                      value: _live.tileWidthFraction.clamp(0.5, 1),
                      min: 0.5,
                      max: 1,
                      onChanged: (x) => _set('tileWidthFraction', x),
                    ),
                    Text('Высота плитки, мин: ${_live.tileHeightMin.round()}'),
                    Slider(
                      value: _live.tileHeightMin.clamp(24, 120),
                      min: 24,
                      max: 120,
                      divisions: 48,
                      onChanged: (x) => _set('tileHeightMin', x),
                    ),
                    Text('Высота плитки, макс: ${_live.tileHeightMax.round()}'),
                    Slider(
                      value: _live.tileHeightMax.clamp(40, 200),
                      min: 40,
                      max: 200,
                      divisions: 80,
                      onChanged: (x) => _set('tileHeightMax', x),
                    ),
                    Text('Отступ между плитками: ${_live.tileGap.round()}'),
                    Slider(
                      value: _live.tileGap.clamp(0, 24),
                      min: 0,
                      max: 24,
                      divisions: 24,
                      onChanged: (x) => _set('tileGap', x),
                    ),
                    Text(
                      'Толщина рамки плитки: ${_live.tileBorderWidth.toStringAsFixed(1)}',
                    ),
                    Slider(
                      value: _live.tileBorderWidth.clamp(0, 4),
                      min: 0,
                      max: 4,
                      onChanged: (x) => _set('tileBorderWidth', x),
                    ),
                    Text('Скругление плитки: ${_live.tileCornerRadius.round()}'),
                    Slider(
                      value: _live.tileCornerRadius.clamp(0, 28),
                      min: 0,
                      max: 28,
                      onChanged: (x) => _set('tileCornerRadius', x),
                    ),
                    Text(
                      'Размер значка канала: ×${_live.kindBadgeSizeMult.toStringAsFixed(2)}',
                    ),
                    Slider(
                      value: _live.kindBadgeSizeMult.clamp(0.8, 2.5),
                      min: 0.8,
                      max: 2.5,
                      onChanged: (x) => _set('kindBadgeSizeMult', x),
                    ),
                    Text('Слотов на колонку: ${_live.maxVisibleSlots}'),
                    Slider(
                      value: _live.maxVisibleSlots.toDouble().clamp(1, 12),
                      min: 1,
                      max: 12,
                      divisions: 11,
                      label: '${_live.maxVisibleSlots}',
                      onChanged: (x) => _set('maxVisibleSlots', x.round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Доставка',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _colorField('Фон плитки', 'deliveryBg'),
                    _colorField('Рамка', 'deliveryBorder'),
                    _colorField('Свечение', 'deliveryGlow'),
                    _colorField('Цвет номера', 'deliveryNumber'),
                    const SizedBox(height: 16),
                    Text(
                      'Самовывоз',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _textField('Подпись под номером', 'pickupSubtitleRu'),
                    _colorField('Фон плитки', 'pickupBg'),
                    _colorField('Рамка', 'pickupBorder'),
                    _colorField('Свечение', 'pickupGlow'),
                    _colorField('Цвет номера', 'pickupNumber'),
                    const SizedBox(height: 16),
                    Text(
                      'На столе / в зале',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    _textField('Заголовок над номером', 'hallTitleRu'),
                    _textField('Подпись, если стол не указан', 'hallSubtitleDefaultRu'),
                    _colorField('Фон плитки', 'hallBg'),
                    _colorField('Рамка', 'hallBorder'),
                    _colorField('Свечение', 'hallGlow'),
                    _colorField('Цвет номера', 'hallNumber'),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
