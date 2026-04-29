import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screen_page_item_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_video_bg_media_editor.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

const _kTv4PageTypes = ['tv4_welcome_pay', 'tv4_queue', 'tv4_video_bg'];

String _tv4PageTypeLabel(AppLocalizations l10n, String t) {
  switch (t) {
    case 'tv4_welcome_pay':
      return l10n.adminTv4PageTypeWelcomePay;
    case 'tv4_queue':
      return l10n.adminTv4PageTypeQueue;
    case 'tv4_video_bg':
      return 'Видео фон';
    default:
      return t;
  }
}

/// Редактор слайдов ТВ4: приветствие/оплата и очередь как страницы `screen_pages`.
class Tv4SlidesEditorScreen extends StatefulWidget {
  const Tv4SlidesEditorScreen({
    super.key,
    required this.screenId,
    required this.screensRepo,
    required this.menuRepo,
    required this.uploadRepo,
  });

  final int screenId;
  final ScreensAdminRepository screensRepo;
  final MenuItemsAdminRepository menuRepo;
  final UploadRepository uploadRepo;

  @override
  State<Tv4SlidesEditorScreen> createState() => _Tv4SlidesEditorScreenState();
}

class _Tv4SlidesEditorScreenState extends State<Tv4SlidesEditorScreen> {
  List<AdminScreenPageRow> _pages = [];
  List<AdminMenuItemRow> _menuItems = [];
  final Map<int, _Tv4PageDetail> _detailByPageId = {};
  Map<String, dynamic>? _screenConfig;
  bool _loading = true;
  bool _uploadingMedia = false;
  bool _savingOrder = false;
  String? _error;
  String _newPageType = 'tv4_welcome_pay';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait<dynamic>([
        widget.screensRepo.fetchScreenPages(widget.screenId),
        widget.menuRepo.fetchItems(),
        widget.screensRepo.fetchScreens(activeOnly: false),
      ]);
      final pages = (futures[0] as List<AdminScreenPageRow>);
      final menuItems = (futures[1] as List<AdminMenuItemRow>);
      final screens = (futures[2] as List<AdminScreenRow>);
      Map<String, dynamic>? nextScreenConfig;
      for (final s in screens) {
        if (s.id == widget.screenId) {
          final rawCfg = s.config;
          if (rawCfg is Map<String, dynamic>) {
            nextScreenConfig = Map<String, dynamic>.from(rawCfg);
          }
          break;
        }
      }
      if (!mounted) return;
      pages.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
      setState(() {
        _pages = pages;
        _menuItems = menuItems;
        _screenConfig = nextScreenConfig;
        _detailByPageId.clear();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _persistOrder(List<AdminScreenPageRow> ordered) async {
    setState(() => _savingOrder = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      for (var i = 0; i < ordered.length; i++) {
        await widget.screensRepo.patchScreenPage(
          widget.screenId,
          ordered[i].id,
          sortOrder: i * 10,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4SlidesOrderSaved)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _addPage(AppLocalizations l10n) async {
    try {
      final nextOrder = _pages.isEmpty
          ? 0
          : (_pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 10);
      await widget.screensRepo.addScreenPage(
        widget.screenId,
        pageType: _newPageType,
        sortOrder: nextOrder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4PageAdded)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deletePage(AdminScreenPageRow p, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenPageDeleteTitle),
        content: Text(
          l10n.adminScreenPageDeleteConfirm(_tv4PageTypeLabel(l10n, p.pageType)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.screensRepo.deleteScreenPage(widget.screenId, p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4PageDeleted)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  bool _tv4CfgBool(Map<String, dynamic>? config, String camel, String snake) {
    final raw = config?['tv4VideoBg'] ?? config?['tv4_video_bg'];
    if (raw is! Map) return true;
    final v = raw[camel] ?? raw[snake];
    if (v == null) return true;
    if (v == false || v == 0 || v == '0') return false;
    if (v is String && v.toLowerCase() == 'false') return false;
    return true;
  }

  String _tv4ScreenVideoPath() {
    final c = _screenConfig;
    final p = c?['tv4VideoBgPath'] ?? c?['tv4_video_bg_path'];
    return p?.toString().trim() ?? '';
  }

  String _tv4ScreenImagePath() {
    final c = _screenConfig;
    final p = c?['tv4VideoBgImagePath'] ?? c?['tv4_video_bg_image_path'];
    return p?.toString().trim() ?? '';
  }

  Future<void> _pickTv4VideoMedia(int pageId) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploadingMedia = true);
    try {
      final path = await widget.uploadRepo.uploadTvVideoBytes(
        bytes,
        f.name.isEmpty ? 'tv4-bg.mp4' : f.name,
      );
      await _patchTv4VideoBg(pageId, {'path': path});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _pickTv4ImageMedia(int pageId) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploadingMedia = true);
    try {
      final path = await widget.uploadRepo.uploadMenuImageBytes(
        bytes,
        f.name.isEmpty ? 'tv4-bg.jpg' : f.name,
      );
      await _patchTv4VideoBg(pageId, {'imagePath': path});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _patchTv4VideoBg(int pageId, Map<String, dynamic> patch) async {
    try {
      final detail = await _loadDetail(pageId);
      final base = Map<String, dynamic>.from(detail?.page.config ?? {});
      final cur = Map<String, dynamic>.from(
        base['tv4VideoBg'] is Map
            ? Map<String, dynamic>.from(base['tv4VideoBg'] as Map)
            : (base['tv4_video_bg'] is Map
                ? Map<String, dynamic>.from(base['tv4_video_bg'] as Map)
                : const <String, dynamic>{}),
      );
      cur.addAll(patch);
      base
        ..remove('tv4_video_bg')
        ..['tv4VideoBg'] = cur;
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<_Tv4PageDetail?> _loadDetail(int pageId) async {
    try {
      final raw = await widget.screensRepo.fetchScreenPageDetail(widget.screenId, pageId);
      if (!mounted) return _detailByPageId[pageId];
      final p = raw['page'];
      final rawItems = raw['items'];
      final items = <ScreenPageItemRow>[];
      if (rawItems is List) {
        for (final e in rawItems) {
          if (e is Map<String, dynamic>) {
            items.add(ScreenPageItemRow.fromJson(e));
          }
        }
      }
      if (p is! Map<String, dynamic>) return _detailByPageId[pageId];
      final page = AdminScreenPageRow.fromJson({
        ...p,
        'itemsCount': items.length,
      });
      final detail = _Tv4PageDetail(page: page, items: items);
      setState(() => _detailByPageId[pageId] = detail);
      return detail;
    } on ApiException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    }
  }

  Future<void> _replaceTv4VideoBgHero(int pageId, String menuItemId) async {
    try {
      final detail = await _loadDetail(pageId);
      final oldItems = List<ScreenPageItemRow>.from(detail?.items ?? const []);
      for (final row in oldItems.where((e) => e.role == 'hero')) {
        await widget.screensRepo.deleteScreenPageItem(widget.screenId, pageId, row.id);
      }
      await widget.screensRepo.addScreenPageItem(
        widget.screenId,
        pageId,
        menuItemId: menuItemId,
        role: 'hero',
      );
      await _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _pickMenuItemSingle(AppLocalizations l10n, {String? selectedId}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var q = '';
        String? heroId = selectedId;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final filtered = _menuItems
                .where(
                  (e) =>
                      q.isEmpty ||
                      e.name.ru.toLowerCase().contains(q.toLowerCase()) ||
                      e.id.toLowerCase().contains(q.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: const Text('Выберите товар для video_bg'),
              content: SizedBox(
                width: math.min(460, MediaQuery.sizeOf(ctx).width * 0.94),
                height: math.min(420, MediaQuery.sizeOf(ctx).height * 0.78),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: l10n.adminTv2EditorSearch,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setSt(() => q = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final it = filtered[i];
                          final sel = heroId == it.id;
                          return ListTile(
                            leading: Icon(
                              sel ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: sel ? Theme.of(ctx).colorScheme.primary : null,
                            ),
                            title: Text(it.name.ru, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(it.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                            selected: sel,
                            dense: true,
                            onTap: () => setSt(() => heroId = it.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: heroId == null ? null : () => Navigator.pop(ctx, heroId),
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  ScreenPageItemRow? _heroForPage(int pageId) {
    final d = _detailByPageId[pageId];
    if (d == null) return null;
    for (final item in d.items) {
      if (item.role == 'hero') return item;
    }
    return null;
  }

  Map<String, dynamic> _tv4PageBgMap(AdminScreenPageRow page) {
    final cfg = _detailByPageId[page.id]?.page.config ?? page.config;
    final raw = cfg?['tv4VideoBg'] ?? cfg?['tv4_video_bg'] ?? cfg?['tvVideoBg'] ?? cfg?['tv_video_bg'];
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _tv4PageVideoPath(AdminScreenPageRow page) {
    final bg = _tv4PageBgMap(page);
    final p = bg['path'] ?? bg['url'] ?? bg['file'] ?? bg['src'];
    final s = p?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
    return _tv4ScreenVideoPath();
  }

  String _tv4PageImagePath(AdminScreenPageRow page) {
    final bg = _tv4PageBgMap(page);
    final p = bg['imagePath'] ?? bg['image_path'];
    final s = p?.toString().trim() ?? '';
    if (s.isNotEmpty) return s;
    return _tv4ScreenImagePath();
  }

  AdminMenuItemRow? _menuItemById(String? id) {
    final sid = (id ?? '').trim();
    if (sid.isEmpty) return null;
    for (final item in _menuItems) {
      if (item.id == sid) return item;
    }
    return null;
  }

  Widget _buildTv4VideoBgEditor({
    required AdminScreenPageRow page,
    required AppLocalizations l10n,
  }) {
    final cfg = _detailByPageId[page.id]?.page.config ?? page.config;
    final showImage = _tv4CfgBool(cfg, 'showImage', 'show_image');
    final showDescription = _tv4CfgBool(cfg, 'showDescription', 'show_description');
    final showPrice = _tv4CfgBool(cfg, 'showPrice', 'show_price');
    final hero = _heroForPage(page.id);
    final heroName =
        (hero?.name.ru.trim().isNotEmpty ?? false) ? hero!.name.ru : 'не выбран';
    final oldHero = hero?.menuItemId;
    final heroMenu = _menuItemById(oldHero);
    final heroDescription = heroMenu?.description?.ru.trim() ?? '';
    final heroPrice = heroMenu?.priceText.ru.trim() ?? '';
    final hasRealImage = (heroMenu?.imagePath ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvVideoBgMediaEditor(
            title: l10n.adminTv2VideoBgTitle,
            videoPath: _tv4PageVideoPath(page),
            videoEmptyText: l10n.adminTv2VideoBgNoVideo,
            pickVideoText: l10n.adminTv2VideoBgPickVideo,
            clearVideoText: l10n.adminTv2OptionalVideoClear,
            imageTitle: l10n.adminTv2OptionalPhotoTitle,
            imageHint: l10n.adminTv2OptionalPhotoHint,
            imagePath: _tv4PageImagePath(page),
            imageEmptyText: l10n.adminTv2BackgroundFileEmpty,
            pickImageText: l10n.adminTv2VideoBgPickPhoto,
            clearImageText: l10n.adminTv2VideoBgClearPhoto,
            uploading: _uploadingMedia,
            onPickVideo: () => _pickTv4VideoMedia(page.id),
            onClearVideo: () => _patchTv4VideoBg(page.id, {'path': ''}),
            onPickImage: () => _pickTv4ImageMedia(page.id),
            onClearImage: () => _patchTv4VideoBg(page.id, {'imagePath': ''}),
          ),
          const Divider(height: 26),
          Text(
            'Текущий товар: $heroName',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              final picked = await _pickMenuItemSingle(l10n, selectedId: oldHero);
              if (picked == null || !mounted) return;
              await _replaceTv4VideoBgHero(page.id, picked);
            },
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: const Text('Выбрать товар'),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Показывать фото'),
                selected: showImage,
                onSelected: (v) => _patchTv4VideoBg(page.id, {'showImage': v}),
              ),
              FilterChip(
                label: const Text('Показывать описание'),
                selected: showDescription,
                onSelected: (v) => _patchTv4VideoBg(page.id, {'showDescription': v}),
              ),
              FilterChip(
                label: const Text('Показывать цену'),
                selected: showPrice,
                onSelected: (v) => _patchTv4VideoBg(page.id, {'showPrice': v}),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Предпросмотр раскладки',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'На ТВ: видео/фото на весь экран и снизу карточка товара.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _Tv4VideoBgMiniPreview(
            heroName: heroName,
            heroPrice: heroPrice,
            heroDescription: heroDescription,
            showImage: showImage,
            showPrice: showPrice,
            showDescription: showDescription,
            hasImage: hasRealImage,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTv4SlidesEditorTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _reload, child: Text(l10n.adminTvPreviewRetry)),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.adminTv4SlidesEditorSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.adminTv4SlidesReorderHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _pages.length,
                        onReorder: (oldIndex, newIndex) {
                          if (_savingOrder) return;
                          if (newIndex > oldIndex) newIndex -= 1;
                          final next = List<AdminScreenPageRow>.from(_pages);
                          final item = next.removeAt(oldIndex);
                          next.insert(newIndex, item);
                          setState(() => _pages = next);
                          _persistOrder(next);
                        },
                        itemBuilder: (context, index) {
                          final p = _pages[index];
                          final isVideoBg = p.pageType.toLowerCase().trim() == 'tv4_video_bg';
                          return Card(
                            key: ValueKey<int>(p.id),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ExpansionTile(
                              onExpansionChanged: (open) {
                                if (open) _loadDetail(p.id);
                              },
                              title: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(Icons.drag_handle_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_tv4PageTypeLabel(l10n, p.pageType)} · id=${p.id} · sort=${p.sortOrder}',
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                tooltip: l10n.actionDelete,
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: _savingOrder ? null : () => _deletePage(p, l10n),
                              ),
                              children: [
                                if (isVideoBg)
                                  _buildTv4VideoBgEditor(page: p, l10n: l10n)
                                else
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Text(
                                      'Для этой страницы дополнительных настроек нет.',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _savingOrder ? null : () => _addPage(l10n),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.adminTv4AddPage),
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>(_newPageType),
                        initialValue: _newPageType,
                        decoration: InputDecoration(
                          labelText: l10n.adminTv4SlidesEditorTitle,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in _kTv4PageTypes)
                            DropdownMenuItem(
                              value: t,
                              child: Text(_tv4PageTypeLabel(l10n, t)),
                            ),
                        ],
                        onChanged: _savingOrder
                            ? null
                            : (v) {
                                if (v != null) setState(() => _newPageType = v);
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Tv4PageDetail {
  _Tv4PageDetail({required this.page, required this.items});

  final AdminScreenPageRow page;
  final List<ScreenPageItemRow> items;
}

class _Tv4VideoBgMiniPreview extends StatelessWidget {
  const _Tv4VideoBgMiniPreview({
    required this.heroName,
    required this.heroPrice,
    required this.heroDescription,
    required this.showImage,
    required this.showPrice,
    required this.showDescription,
    required this.hasImage,
  });

  final String heroName;
  final String heroPrice;
  final String heroDescription;
  final bool showImage;
  final bool showPrice;
  final bool showDescription;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = heroName.trim().isEmpty || heroName == 'не выбран'
        ? 'Товар не выбран'
        : heroName;
    final price = heroPrice.trim().isNotEmpty ? heroPrice.trim() : '—';
    final desc = heroDescription.trim();
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blueGrey.shade800,
                  Colors.blueGrey.shade900,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.videocam_rounded,
                size: 44,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showImage) ...[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasImage ? Icons.image_rounded : Icons.restaurant_rounded,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (showPrice) ...[
                          const SizedBox(height: 4),
                          Text(
                            price,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFFFD447),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (showDescription && desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
