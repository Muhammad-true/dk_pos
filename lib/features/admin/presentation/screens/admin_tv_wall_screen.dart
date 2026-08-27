import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;
import 'package:dk_digitial_menu/data/local_tv_wall_api.dart' as dm_wall;
import 'package:dk_digitial_menu/ui/tv_wall_live_preview.dart';
import 'package:dk_pos/core/config/app_config.dart' as pos_app_config;
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/local_tv_wall_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';

/// Конструктор стены: экраны + тип контента (пицца / видео / …) + интервал.
class AdminTvWallScreen extends StatefulWidget {
  const AdminTvWallScreen({super.key, this.maxBodyWidth = 960});

  final double maxBodyWidth;

  @override
  State<AdminTvWallScreen> createState() => _AdminTvWallScreenState();
}

class _AdminTvWallScreenState extends State<AdminTvWallScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _playing = false;

  double _photoScale = 1.25;
  int _wordEvery = 2;
  final TextEditingController _railWordsCtrl = TextEditingController();

  bool _enabled = false;
  int _panelCount = 3;
  int _intervalMinutes = 15;
  int _showDurationSec = 45;
  int _itemHoldSec = 8;
  double _nameFontScale = 1.0;
  double _priceFontScale = 1.0;
  String _contentType = 'pizza_carousel';
  String _designId = 'kfc_red';
  String _videoPath = '';
  String _photoPath = '';
  final List<int?> _slotScreenIds = List<int?>.filled(5, null);
  final List<LocalTvWallItem> _items = [];

  List<AdminScreenRow> _screens = const [];
  List<AdminMenuItemRow> _menuItems = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    dm_app_config.AppConfig.setApiOriginOverride(pos_app_config.AppConfig.apiOrigin);
    try {
      final wallRepo = context.read<LocalTvWallRepository>();
      final screensRepo = context.read<ScreensAdminRepository>();
      final menuRepo = context.read<MenuItemsAdminRepository>();
      final results = await Future.wait([
        wallRepo.fetch(),
        screensRepo.fetchScreens(activeOnly: false),
        menuRepo.fetchItems(),
      ]);
      if (!mounted) return;
      final cfg = results[0] as LocalTvWallConfig;
      final screens = results[1] as List<AdminScreenRow>;
      final menu = results[2] as List<AdminMenuItemRow>;
      for (var i = 0; i < _slotScreenIds.length; i++) {
        _slotScreenIds[i] = null;
      }
      for (final s in cfg.screens) {
        if (s.panelIndex >= 0 && s.panelIndex < _slotScreenIds.length) {
          _slotScreenIds[s.panelIndex] = s.screenId;
        }
      }
      setState(() {
        _screens = screens;
        _menuItems = menu;
        _enabled = cfg.enabled;
        _panelCount = cfg.panelCount.clamp(2, 5);
        _intervalMinutes = cfg.intervalMinutes;
        _showDurationSec = (cfg.showDurationMs / 1000).round().clamp(20, 180);
        _itemHoldSec = (cfg.itemHoldMs / 1000).round().clamp(6, 15);
        _nameFontScale = _snapFontScale(cfg.nameFontScale);
        _priceFontScale = _snapFontScale(cfg.priceFontScale);
        _photoScale = _snapPhotoScale(cfg.photoScale);
        _wordEvery = cfg.wordEvery.clamp(1, 6);
        _railWordsCtrl.text = cfg.railWords.join('\n');
        _contentType = cfg.contentType;
        _designId = cfg.designId;
        _videoPath = cfg.videoPath;
        _photoPath = cfg.photoPath;
        _items
          ..clear()
          ..addAll(cfg.items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    }
  }

  LocalTvWallConfig _buildConfig() {
    final slots = <LocalTvWallScreenSlot>[];
    for (var i = 0; i < _panelCount; i++) {
      final id = _slotScreenIds[i];
      if (id != null && id > 0) {
        slots.add(LocalTvWallScreenSlot(screenId: id, panelIndex: i));
      }
    }
    return LocalTvWallConfig(
      enabled: _enabled,
      groupId: 'wall',
      panelCount: _panelCount,
      screens: slots,
      contentType: _contentType,
      designId: _designId,
      videoPath: _videoPath,
      photoPath: _photoPath,
      items: List<LocalTvWallItem>.from(_items),
      itemHoldMs: _itemHoldSec * 1000,
      nameFontScale: _nameFontScale,
      priceFontScale: _priceFontScale,
      photoScale: _photoScale,
      railWords: _railWordsCtrl.text
          .split(RegExp(r'[\r\n|;]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(12)
          .toList(),
      wordEvery: _wordEvery,
      intervalMinutes: _intervalMinutes,
      showDurationMs: _showDurationSec * 1000,
    );
  }

  dm_wall.TvWallConfig _previewDmConfig() {
    final cfg = _buildConfig();
    // Демо-товары, если ещё не выбрали — чтобы превью не было пустым.
    final items = cfg.items.isNotEmpty
        ? cfg.items
        : [
            const LocalTvWallItem(
              id: 'demo1',
              name: 'Пепперони',
              priceText: '59 с.',
              imagePath: '',
            ),
            const LocalTvWallItem(
              id: 'demo2',
              name: 'Маргарита',
              priceText: '49 с.',
              imagePath: '',
            ),
          ];
    return dm_wall.TvWallConfig.fromJson({
      ...cfg.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
      'enabled': true,
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final wallRepo = context.read<LocalTvWallRepository>();
      final saved = await wallRepo.save(_buildConfig());
      if (!mounted) return;
      setState(() {
        _enabled = saved.enabled;
        _contentType = saved.contentType;
        _designId = saved.designId;
        _videoPath = saved.videoPath;
        _photoPath = saved.photoPath;
        _photoScale = _snapPhotoScale(saved.photoScale);
        _wordEvery = saved.wordEvery.clamp(1, 6);
        _railWordsCtrl.text = saved.railWords.join('\n');
        _items
          ..clear()
          ..addAll(saved.items);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Стена сохранена')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    }
  }

  Future<void> _uploadVideo() async {
    final uploadRepo = context.read<UploadRepository>();
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'webm', 'mov', 'mkv'],
      withData: true,
    );
    if (!mounted) return;
    if (pick == null || pick.files.isEmpty) return;
    final file = pick.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось прочитать файл')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final path = await uploadRepo.uploadTvVideoBytes(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _videoPath = path;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _uploadPhoto() async {
    final uploadRepo = context.read<UploadRepository>();
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (!mounted) return;
    if (pick == null || pick.files.isEmpty) return;
    final file = pick.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() => _uploading = true);
    try {
      // Используем menu upload — фото для панорамы.
      final path = await uploadRepo.uploadMenuImageBytes(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _photoPath = path;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _playNow() async {
    final cfg = _buildConfig();
    if (!cfg.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите контент: пиццы, видео или другое шоу')),
      );
      return;
    }
    setState(() => _playing = true);
    try {
      final wallRepo = context.read<LocalTvWallRepository>();
      await wallRepo.save(cfg);
      final msg = await wallRepo.playNow(showDurationMs: _showDurationSec * 1000);
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _pickPizzas() async {
    final selected = _items.map((e) => e.id).toSet();
    final result = await showDialog<List<LocalTvWallItem>>(
      context: context,
      builder: (ctx) {
        final draft = Set<String>.from(selected);
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final pizzas = List<AdminMenuItemRow>.from(_menuItems);
            return AlertDialog(
              title: const Text('Товары для шоу (до 20)'),
              content: SizedBox(
                width: 520,
                height: 420,
                child: ListView.builder(
                  itemCount: pizzas.length,
                  itemBuilder: (_, i) {
                    final it = pizzas[i];
                    final on = draft.contains(it.id);
                    return CheckboxListTile(
                      value: on,
                      title: Text(it.name.ru),
                      subtitle: Text(it.displayPriceLineRu),
                      onChanged: (v) {
                        setSt(() {
                          if (v == true) {
                            if (draft.length >= 20) return;
                            draft.add(it.id);
                          } else {
                            draft.remove(it.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                FilledButton(
                  onPressed: () {
                    final out = <LocalTvWallItem>[];
                    for (final id in draft) {
                      AdminMenuItemRow? row;
                      for (final m in _menuItems) {
                        if (m.id == id) {
                          row = m;
                          break;
                        }
                      }
                      if (row == null) continue;
                      out.add(
                        LocalTvWallItem(
                          id: row.id,
                          name: row.name.ru,
                          priceText: row.displayPriceLineRu,
                          imagePath: (row.imagePath ?? '').replaceFirst(RegExp(r'^/+'), ''),
                        ),
                      );
                    }
                    Navigator.pop(ctx, out);
                  },
                  child: const Text('Готово'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(_groupWallItemsForSave(result));
    });
  }

  /// Склеивает «X 25/30/35 см» в одну позицию стены с volumeVariants.
  List<LocalTvWallItem> _groupWallItemsForSave(List<LocalTvWallItem> raw) {
    final sizeRe = RegExp(
      r'^(.*?)\s+(25|30|35)\s*(?:см|cm)?\s*$',
      caseSensitive: false,
    );
    final buckets = <String, List<({LocalTvWallItem item, String label, int cm})>>{};
    final order = <({String kind, LocalTvWallItem? item, String? key})>[];
    for (final it in raw) {
      final m = sizeRe.firstMatch(it.name.trim());
      if (m == null) {
        order.add((kind: 'keep', item: it, key: null));
        continue;
      }
      final base = (m.group(1) ?? '').trim();
      final cm = int.tryParse(m.group(2) ?? '') ?? 0;
      if (base.isEmpty || cm == 0) {
        order.add((kind: 'keep', item: it, key: null));
        continue;
      }
      final key = base.toLowerCase();
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add((kind: 'group', item: null, key: key));
      }
      buckets[key]!.add((item: it, label: '$cm см', cm: cm));
    }
    final out = <LocalTvWallItem>[];
    final emitted = <String>{};
    for (final slot in order) {
      if (slot.kind == 'keep') {
        out.add(slot.item!);
        continue;
      }
      final key = slot.key!;
      if (emitted.contains(key)) continue;
      emitted.add(key);
      final bucket = List.of(buckets[key]!)..sort((a, b) => a.cm.compareTo(b.cm));
      if (bucket.length < 2) {
        out.addAll(bucket.map((e) => e.item));
        continue;
      }
      final first = bucket.first;
      final baseName = sizeRe.firstMatch(first.item.name.trim())!.group(1)!.trim();
      out.add(
        LocalTvWallItem(
          id: first.item.id,
          name: baseName,
          priceText: bucket.map((e) => '${e.label} — ${e.item.priceText}').join('\n'),
          imagePath: first.item.imagePath,
          volumeVariants: [
            for (final e in bucket)
              {'label': e.label, 'priceText': e.item.priceText},
          ],
        ),
      );
    }
    return out;
  }

  String _err(Object e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }

  @override
  void dispose() {
    _railWordsCtrl.dispose();
    super.dispose();
  }

  static double _snapFontScale(double v) {
    const opts = <double>[0.7, 0.85, 1.0, 1.2, 1.4, 1.6];
    var best = opts.first;
    var bestDist = (best - v).abs();
    for (final o in opts.skip(1)) {
      final d = (o - v).abs();
      if (d < bestDist) {
        best = o;
        bestDist = d;
      }
    }
    return best;
  }

  static double _snapPhotoScale(double v) {
    const opts = <double>[0.9, 1.1, 1.25, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0];
    var best = opts.first;
    var bestDist = (best - v).abs();
    for (final o in opts.skip(1)) {
      final d = (o - v).abs();
      if (d < bestDist) {
        best = o;
        bestDist = d;
      }
    }
    return best;
  }

  String _screenLabel(AdminScreenRow s) => '${s.name} (#${s.id}, ${s.type})';

  bool get _needsItems =>
      _contentType == 'pizza_carousel' ||
      _contentType == 'pizza_bounce' ||
      _contentType == 'pizza_slam' ||
      _contentType == 'pizza_spin' ||
      _contentType == 'product_spotlight' ||
      _contentType == 'price_burst' ||
      _contentType == 'stripe_wipe';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            Text(
              'Стена ТВ — конструктор шоу',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Выберите контент и дизайн — сразу смотрите превью на «ТВ». '
              'Сохранение нужно только чтобы ушло на приставки.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TvWallLivePreview(
              key: ValueKey(
                '$_contentType-$_designId-$_panelCount-$_itemHoldSec-'
                '$_nameFontScale-$_priceFontScale-$_photoScale-$_wordEvery-'
                '${_railWordsCtrl.text.hashCode}-${_items.length}',
              ),
              config: _previewDmConfig(),
              height: 200,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Включить расписание шоу'),
              subtitle: const Text('Каждые N минут; «Сейчас» работает и без этого'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 12),
            Text('Тип контента (выберите одно)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kTvWallContentTypes)
                  ChoiceChip(
                    label: Text(tvWallContentTypeTitle(id)),
                    selected: _contentType == id,
                    onSelected: (_) => setState(() => _contentType = id),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tvWallContentTypeDesc(_contentType),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Дизайн (как KFC)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in kTvWallDesignIds)
                  ChoiceChip(
                    label: Text(tvWallDesignTitle(id)),
                    selected: _designId == id,
                    onSelected: (_) => setState(() => _designId = id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Число ТВ в ряду', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 5, label: Text('5')),
              ],
              selected: {_panelCount},
              onSelectionChanged: (s) => setState(() => _panelCount = s.first),
            ),
            const SizedBox(height: 20),
            Text('Порядок слева → направо', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final gap = 10.0;
                final minRowWidth = _panelCount * 120 + gap * (_panelCount - 1);
                final rowWidth = c.maxWidth > minRowWidth
                    ? c.maxWidth
                    : minRowWidth;
                final w = (rowWidth - gap * (_panelCount - 1)) / _panelCount;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: rowWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _panelCount; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          SizedBox(
                            width: w,
                            child: _TvSlotCard(
                              index: i,
                              panelCount: _panelCount,
                              screenId: _slotScreenIds[i],
                              screens: _screens,
                              labelOf: _screenLabel,
                              onChanged: (id) =>
                                  setState(() => _slotScreenIds[i] = id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (_needsItems) ...[
              Text('Пиццы / товары (одна за раз в карусели)', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final it in _items)
                    Chip(
                      label: Text(it.name),
                      onDeleted: () => setState(() => _items.remove(it)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(_items.isEmpty ? 'Выбрать товары' : 'Изменить (${_items.length})'),
                    onPressed: _pickPizzas,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Интервал между товарами в цепочке',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _itemHoldSec,
                    items: [
                      for (final n in [6, 7, 8, 10, 12, 15])
                        DropdownMenuItem(value: n, child: Text('$n сек')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _itemHoldSec = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Размер названия',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          value: _nameFontScale,
                          items: const [
                            DropdownMenuItem(value: 0.7, child: Text('Мелкий')),
                            DropdownMenuItem(value: 0.85, child: Text('Меньше')),
                            DropdownMenuItem(value: 1.0, child: Text('Обычный')),
                            DropdownMenuItem(value: 1.2, child: Text('Крупнее')),
                            DropdownMenuItem(value: 1.4, child: Text('Крупный')),
                            DropdownMenuItem(value: 1.6, child: Text('Очень крупный')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _nameFontScale = v);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Размер цены',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          value: _priceFontScale,
                          items: const [
                            DropdownMenuItem(value: 0.7, child: Text('Мелкий')),
                            DropdownMenuItem(value: 0.85, child: Text('Меньше')),
                            DropdownMenuItem(value: 1.0, child: Text('Обычный')),
                            DropdownMenuItem(value: 1.2, child: Text('Крупнее')),
                            DropdownMenuItem(value: 1.4, child: Text('Крупный')),
                            DropdownMenuItem(value: 1.6, child: Text('Очень крупный')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _priceFontScale = v);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Размер фото товара',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    isExpanded: true,
                    value: _photoScale,
                    items: const [
                      DropdownMenuItem(value: 0.9, child: Text('Меньше')),
                      DropdownMenuItem(value: 1.1, child: Text('Обычный')),
                      DropdownMenuItem(value: 1.25, child: Text('Крупнее')),
                      DropdownMenuItem(value: 1.5, child: Text('Крупный')),
                      DropdownMenuItem(value: 2.0, child: Text('x2')),
                      DropdownMenuItem(value: 2.5, child: Text('x2.5')),
                      DropdownMenuItem(value: 3.0, child: Text('x3')),
                      DropdownMenuItem(value: 3.5, child: Text('x3.5')),
                      DropdownMenuItem(value: 4.0, child: Text('x4 (макс.)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _photoScale = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _railWordsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Слова между товарами (по одному в строке)',
                  hintText: 'Новое у нас\nАкция у нас',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Вставлять слово через каждые N товаров',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _wordEvery,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('После каждого')),
                      DropdownMenuItem(value: 2, child: Text('Через 2 товара')),
                      DropdownMenuItem(value: 3, child: Text('Через 3 товара')),
                      DropdownMenuItem(value: 4, child: Text('Через 4 товара')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _wordEvery = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_contentType == 'video') ...[
              Text('Широкое видео', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Для $_panelCount ТВ ≈${_panelCount * 1920}×1080 MP4, до ~25 МБ.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _uploading ? null : _uploadVideo,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_uploading ? 'Загрузка…' : 'Загрузить видео'),
                  ),
                  const SizedBox(width: 12),
                  if (_videoPath.isNotEmpty)
                    Expanded(
                      child: Text(_videoPath, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_contentType == 'photo_pan') ...[
              Text('Широкое фото', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _uploading ? null : _uploadPhoto,
                    icon: const Icon(Icons.image_rounded),
                    label: Text(_uploading ? 'Загрузка…' : 'Загрузить фото'),
                  ),
                  const SizedBox(width: 12),
                  if (_photoPath.isNotEmpty)
                    Expanded(
                      child: Text(_photoPath, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text('Расписание', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Каждые N минут',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _intervalMinutes == 0 ? 0 : _intervalMinutes.clamp(1, 120),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('Выкл (только «Сейчас»)'),
                          ),
                          for (final n in [1, 2, 3, 5, 10, 15, 20, 30, 45, 60])
                            DropdownMenuItem(value: n, child: Text('Каждые $n мин')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _intervalMinutes = v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Длительность шоу (сек)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      helperText: 'Лучше ≥ 30 с',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _showDurationSec < 20 ? 45 : _showDurationSec,
                        items: [
                          for (final n in [20, 30, 45, 60, 90, 120])
                            DropdownMenuItem(value: n, child: Text('$n сек')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _showDurationSec = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Сохраните → на приставках выберите ТВ (для видео — скачайте файл) → «Сейчас».',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Сохранить'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _playing ? null : _playNow,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Сейчас'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TvSlotCard extends StatelessWidget {
  const _TvSlotCard({
    required this.index,
    required this.panelCount,
    required this.screenId,
    required this.screens,
    required this.labelOf,
    required this.onChanged,
  });

  final int index;
  final int panelCount;
  final int? screenId;
  final List<AdminScreenRow> screens;
  final String Function(AdminScreenRow) labelOf;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE4002B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'ТВ ${index + 1}\nдоля ${index + 1}/$panelCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              key: ValueKey<String>('tv-wall-slot-$index-$screenId'),
              initialValue: screenId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Экран',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— не выбран —')),
                for (final s in screens)
                  DropdownMenuItem<int?>(
                    value: s.id,
                    child: Text(labelOf(s), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
