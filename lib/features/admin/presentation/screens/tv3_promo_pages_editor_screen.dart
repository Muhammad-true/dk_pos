import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screen_page_item_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

import 'package:dk_pos/features/admin/data/admin_combo_row.dart';

/// Страницы акций ТВ3: товар, комбо, полноэкранное видео или фото с подписями.
class Tv3PromoPagesEditorScreen extends StatefulWidget {
  const Tv3PromoPagesEditorScreen({
    super.key,
    required this.screenId,
    required this.screensRepo,
    required this.menuRepo,
    required this.combosRepo,
    required this.uploadRepo,
  });

  final int screenId;
  final ScreensAdminRepository screensRepo;
  final MenuItemsAdminRepository menuRepo;
  final CombosAdminRepository combosRepo;
  final UploadRepository uploadRepo;

  @override
  State<Tv3PromoPagesEditorScreen> createState() =>
      _Tv3PromoPagesEditorScreenState();
}

class _Tv3PromoPagesEditorScreenState extends State<Tv3PromoPagesEditorScreen> {
  List<AdminScreenPageRow> _pages = [];
  List<AdminMenuItemRow> _menuItems = [];
  List<AdminComboRow> _combos = [];
  final Map<int, _Tv3PageDetail> _detailByPageId = {};
  bool _loading = true;
  bool _savingPageOrder = false;
  String? _error;
  String _newPageType = 'promo_product';
  int? _newPageComboId;
  late final TextEditingController _cScreenPromoSlogan;
  bool _savingSlogan = false;

  @override
  void initState() {
    super.initState();
    _cScreenPromoSlogan = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _cScreenPromoSlogan.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await widget.screensRepo.fetchScreenPages(widget.screenId);
      final items = await widget.menuRepo.fetchItems();
      final combos = await widget.combosRepo.fetchCombos();
      final screens = await widget.screensRepo.fetchScreens();
      AdminScreenRow? thisScreen;
      for (final s in screens) {
        if (s.id == widget.screenId) {
          thisScreen = s;
          break;
        }
      }
      final cfg = thisScreen?.config;
      final rawSlogan = cfg?['tv3PromoSlogan'] ?? cfg?['tv3_promo_slogan'];
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _menuItems = items;
        _combos = combos;
        _detailByPageId.clear();
        _cScreenPromoSlogan.text = rawSlogan?.toString() ?? '';
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

  Future<void> _loadDetail(int pageId) async {
    try {
      final raw = await widget.screensRepo.fetchScreenPageDetail(
        widget.screenId,
        pageId,
      );
      if (!mounted) return;
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
      if (p is! Map<String, dynamic>) return;
      final row = AdminScreenPageRow.fromJson({
        ...p,
        'itemsCount': items.length,
      });
      setState(() {
        _detailByPageId[pageId] = _Tv3PageDetail(page: row, items: items);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveScreenPromoSlogan(AppLocalizations l10n) async {
    setState(() => _savingSlogan = true);
    try {
      await widget.screensRepo.mergeScreenConfig(
        widget.screenId,
        {'tv3PromoSlogan': _cScreenPromoSlogan.text.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv3PromoSloganSaved)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingSlogan = false);
    }
  }

  Future<void> _confirmDeletePage(
    AdminScreenPageRow p,
    String typeLabel,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenPageDeleteTitle),
        content: Text(l10n.adminScreenPageDeleteConfirm(typeLabel)),
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
      _detailByPageId.remove(p.id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminScreenPageDeleted)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _persistTv3PageOrderAfterReorder(AppLocalizations l10n) async {
    try {
      await Future.wait([
        for (var i = 0; i < _pages.length; i++)
          widget.screensRepo.patchScreenPage(
            widget.screenId,
            _pages[i].id,
            sortOrder: i,
          ),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv3PromoOrderSaved)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _savingPageOrder = false);
    }
  }

  void _onReorderTv3Pages(int oldIndex, int newIndex, AppLocalizations l10n) {
    if (_savingPageOrder) return;
    var ni = newIndex;
    if (ni > oldIndex) ni--;
    if (oldIndex < 0 ||
        oldIndex >= _pages.length ||
        ni < 0 ||
        ni >= _pages.length) {
      return;
    }
    final list = List<AdminScreenPageRow>.from(_pages);
    final moved = list.removeAt(oldIndex);
    list.insert(ni, moved);
    final reindexed = <AdminScreenPageRow>[
      for (var i = 0; i < list.length; i++)
        AdminScreenPageRow(
          id: list[i].id,
          pageType: list[i].pageType,
          sortOrder: i,
          itemsCount: list[i].itemsCount,
          comboId: list[i].comboId,
          config: list[i].config,
          listTitle: list[i].listTitle,
          secondListTitle: list[i].secondListTitle,
        ),
    ];
    setState(() {
      _pages = reindexed;
      _savingPageOrder = true;
    });
    _persistTv3PageOrderAfterReorder(l10n);
  }

  Future<void> _addPage(AppLocalizations l10n) async {
    final nextOrder = _pages.isEmpty
        ? 0
        : _pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    try {
      final comboId =
          _newPageType == 'promo_combo' ? _newPageComboId : null;
      if (_newPageType == 'promo_combo' && (comboId == null || comboId < 1)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv3PromoComboRequired)),
        );
        return;
      }
      await widget.screensRepo.addScreenPage(
        widget.screenId,
        pageType: _newPageType,
        sortOrder: nextOrder,
        comboId: comboId,
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorPageAdded)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  String _pagePromoLineFromConfig(Map<String, dynamic>? c) {
    if (c == null) return '';
    return (c['promoTopLine'] ?? c['promo_top_line'] ?? '').toString();
  }

  String _tv3PromoVariantForPage(AdminScreenPageRow p) {
    final src = _detailByPageId[p.id]?.page ?? p;
    final c = src.config;
    if (c == null) return 'standard';
    final v = (c['tv3PromoVariant'] ?? c['tv3_promo_variant'])
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';
    if (v == 'inverted' || v == 'white' || v == 'light') return 'inverted';
    return 'standard';
  }

  Future<void> _setPromoVariant(int pageId, String variant) async {
    try {
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: {'tv3PromoVariant': variant},
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _patchTv3PageConfig(int pageId, Map<String, dynamic> patch) async {
    final d = _detailByPageId[pageId];
    final base = Map<String, dynamic>.from(d?.page.config ?? {});
    for (final e in patch.entries) {
      if (e.key == 'tv3MediaBg' && e.value is Map) {
        final prev = base['tv3MediaBg'] is Map
            ? Map<String, dynamic>.from(base['tv3MediaBg']! as Map)
            : <String, dynamic>{};
        base['tv3MediaBg'] = {
          ...prev,
          ...Map<String, dynamic>.from(e.value! as Map),
        };
      } else {
        base[e.key] = e.value;
      }
    }
    try {
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _clearAllPageItemsTv3Media(int pageId) async {
    if (!_detailByPageId.containsKey(pageId)) {
      await _loadDetail(pageId);
    }
    final items = List<ScreenPageItemRow>.from(
      _detailByPageId[pageId]?.items ?? const [],
    );
    for (final it in items) {
      await widget.screensRepo.deleteScreenPageItem(
        widget.screenId,
        pageId,
        it.id,
      );
    }
    _detailByPageId.remove(pageId);
    await _loadDetail(pageId);
  }

  Future<void> _tv3MediaSwitchMenuMode(int pageId) async {
    try {
      await _clearAllPageItemsTv3Media(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv3Content'] = {'mode': 'menu'};
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _tv3MediaSwitchComboMode(int pageId) async {
    try {
      await _clearAllPageItemsTv3Media(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv3Content'] = {'mode': 'combo'};
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _tv3MediaPickHeroForMedia(int pageId, AppLocalizations l10n) async {
    try {
      await _clearAllPageItemsTv3Media(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv3Content'] = {'mode': 'menu'};
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (!mounted) return;
      await _addHero(pageId, l10n);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _tv3MediaApplyCombo(
    int pageId,
    int comboId,
    AppLocalizations l10n,
  ) async {
    try {
      await _clearAllPageItemsTv3Media(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv3Content'] = {'mode': 'combo', 'comboId': comboId};
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorItemAdded)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _setCombo(int pageId, int? comboId) async {
    try {
      if (comboId == null) {
        await widget.screensRepo.patchScreenPage(
          widget.screenId,
          pageId,
          clearComboId: true,
        );
      } else {
        await widget.screensRepo.patchScreenPage(
          widget.screenId,
          pageId,
          comboId: comboId,
        );
      }
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addHero(int pageId, AppLocalizations l10n) async {
    final id = await _pickSingleMenuItem(l10n);
    if (id == null) return;
    try {
      await widget.screensRepo.addScreenPageItem(
        widget.screenId,
        pageId,
        menuItemId: id,
        role: 'hero',
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorItemAdded)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _removeItem(int pageId, int rowId, AppLocalizations l10n) async {
    try {
      await widget.screensRepo.deleteScreenPageItem(
        widget.screenId,
        pageId,
        rowId,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorItemRemoved)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<String?> _pickSingleMenuItem(AppLocalizations l10n) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var q = '';
        String? heroId;
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
              title: Text(l10n.adminTv2EditorPickItem),
              content: SizedBox(
                width: math.min(460, MediaQuery.sizeOf(ctx).width * 0.94),
                height: math.min(400, MediaQuery.sizeOf(ctx).height * 0.76),
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
                  child: Text(l10n.adminTv2EditorAddSelectedButton(1)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTv3PromoEditorTitle),
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
                        FilledButton(
                          onPressed: _reload,
                          child: Text(l10n.actionRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      l10n.adminTv3PromoEditorSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cScreenPromoSlogan,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: l10n.adminTv3PromoSloganLabel,
                        helperText: l10n.adminTv3PromoSloganHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _savingSlogan ? null : () => _saveScreenPromoSlogan(l10n),
                        child: Text(l10n.adminTv3PromoSloganSave),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>(_newPageType),
                            initialValue: _newPageType,
                            decoration: InputDecoration(
                              labelText: l10n.adminScreenPageTypeLabel,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _newPageType = v;
                                  if (v != 'promo_combo') _newPageComboId = null;
                                });
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'promo_product',
                                child: Text(l10n.adminTv3PageTypePromoProduct),
                              ),
                              DropdownMenuItem(
                                value: 'promo_combo',
                                child: Text(l10n.adminTv3PageTypePromoCombo),
                              ),
                              DropdownMenuItem(
                                value: 'promo_video_bg',
                                child: Text(l10n.adminTv3PageTypePromoVideoBg),
                              ),
                              DropdownMenuItem(
                                value: 'promo_photo_bg',
                                child: Text(l10n.adminTv3PageTypePromoPhotoBg),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_newPageType == 'promo_combo')
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey<int?>(_newPageComboId),
                              initialValue: _newPageComboId,
                              decoration: InputDecoration(
                                labelText: l10n.adminTv3PromoSelectCombo,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                for (final c in _combos)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.nameRu.isEmpty ? '#${c.id}' : c.nameRu,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _newPageComboId = v),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FilledButton.icon(
                            onPressed: () => _addPage(l10n),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.adminScreenPageAdd),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.adminTv3PromoOpenCombosHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (_pages.isEmpty)
                      Text(l10n.adminTv2EditorNoPages)
                    else ...[
                      Text(
                        l10n.adminTv3PromoReorderHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        ignoring: _savingPageOrder,
                        child: Opacity(
                          opacity: _savingPageOrder ? 0.55 : 1,
                          child: ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) =>
                                _onReorderTv3Pages(oldIndex, newIndex, l10n),
                            children: [
                              for (var i = 0; i < _pages.length; i++)
                                _buildPageCard(context, i, _pages[i], l10n),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildPageCard(
    BuildContext context,
    int index,
    AdminScreenPageRow p,
    AppLocalizations l10n,
  ) {
    final detail = _detailByPageId[p.id];
    final items = detail?.items ?? const <ScreenPageItemRow>[];
    final hero = items.where((e) => e.role == 'hero').toList();
    final pt = p.pageType.toLowerCase();
    final isCombo = pt == 'promo_combo';
    final isMediaBg = pt == 'promo_video_bg' || pt == 'promo_photo_bg';
    final subtitle = isCombo
        ? l10n.adminTv3PageTypePromoCombo
        : isMediaBg
            ? (pt == 'promo_video_bg'
                ? l10n.adminTv3PageTypePromoVideoBg
                : l10n.adminTv3PageTypePromoPhotoBg)
            : l10n.adminTv3PageTypePromoProduct;

    return Card(
      key: ValueKey<int>(p.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        onExpansionChanged: (open) {
          if (open) _loadDetail(p.id);
        },
        title: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${l10n.adminTv2EditorPageLabel} #${p.id} · ${p.pageType} · ${l10n.adminScreenPageItems(p.itemsCount)}',
              ),
            ),
            IconButton(
              tooltip: l10n.actionDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmDeletePage(p, subtitle, l10n),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMediaBg)
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>('${p.id}-theme-${_tv3PromoVariantForPage(p)}'),
                    initialValue: _tv3PromoVariantForPage(p),
                    decoration: InputDecoration(
                      labelText: l10n.adminTv3PromoSlideThemeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text(l10n.adminTv3PromoSlideThemeRedBg),
                      ),
                      DropdownMenuItem(
                        value: 'inverted',
                        child: Text(l10n.adminTv3PromoSlideThemeWhiteBg),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _setPromoVariant(p.id, v);
                    },
                  ),
                if (!isMediaBg) const SizedBox(height: 12),
                _Tv3PagePromoLineEditor(
                  key: ValueKey<String>('promo-line-${p.id}'),
                  label: l10n.adminTv3PagePromoLineLabel,
                  hint: l10n.adminTv3PagePromoLineHint,
                  saveLabel: l10n.actionSave,
                  initial: _pagePromoLineFromConfig(detail?.page.config),
                  onSave: (v) => _patchTv3PageConfig(p.id, {'promoTopLine': v.trim()}),
                ),
                const SizedBox(height: 12),
                if (isMediaBg)
                  _Tv3MediaFullBleedEditor(
                    key: ValueKey<int>(p.id),
                    pageType: p.pageType,
                    config: detail?.page.config,
                    heroRows: items.where((e) => e.role == 'hero').toList(),
                    combos: _combos.where((c) => c.isActive == 1).toList(),
                    l10n: l10n,
                    uploadRepo: widget.uploadRepo,
                    onPatchConfig: (patch) => _patchTv3PageConfig(p.id, patch),
                    onSwitchMenu: () => _tv3MediaSwitchMenuMode(p.id),
                    onSwitchCombo: () => _tv3MediaSwitchComboMode(p.id),
                    onPickHero: () => _tv3MediaPickHeroForMedia(p.id, l10n),
                    onRemoveHero: (rowId) => _removeItem(p.id, rowId, l10n),
                    onApplyCombo: (cid) => _tv3MediaApplyCombo(p.id, cid, l10n),
                  )
                else if (isCombo) ...[
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>('${p.id}-${p.comboId}'),
                    initialValue: p.comboId,
                    decoration: InputDecoration(
                      labelText: l10n.adminTv3PromoSelectCombo,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in _combos)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.nameRu.isEmpty ? '#${c.id}' : c.nameRu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) _setCombo(p.id, v);
                    },
                  ),
                ] else ...[
                  FilledButton.tonal(
                    onPressed: () => _addHero(p.id, l10n),
                    child: Text(l10n.adminTv3PromoAddHero),
                  ),
                  const SizedBox(height: 8),
                  if (hero.isEmpty)
                    Text(
                      l10n.adminTv3PromoHeroEmpty,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    ...hero.map(
                      (e) => ListTile(
                        dense: true,
                        title: Text(e.name.ru),
                        subtitle: Text(e.menuItemId),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _removeItem(p.id, e.id, l10n),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tv3MediaFullBleedEditor extends StatefulWidget {
  const _Tv3MediaFullBleedEditor({
    super.key,
    required this.pageType,
    required this.config,
    required this.heroRows,
    required this.combos,
    required this.l10n,
    required this.uploadRepo,
    required this.onPatchConfig,
    required this.onSwitchMenu,
    required this.onSwitchCombo,
    required this.onPickHero,
    required this.onRemoveHero,
    required this.onApplyCombo,
  });

  final String pageType;
  final Map<String, dynamic>? config;
  final List<ScreenPageItemRow> heroRows;
  final List<AdminComboRow> combos;
  final AppLocalizations l10n;
  final UploadRepository uploadRepo;
  final Future<void> Function(Map<String, dynamic> patch) onPatchConfig;
  final Future<void> Function() onSwitchMenu;
  final Future<void> Function() onSwitchCombo;
  final Future<void> Function() onPickHero;
  final Future<void> Function(int rowId) onRemoveHero;
  final Future<void> Function(int comboId) onApplyCombo;

  @override
  State<_Tv3MediaFullBleedEditor> createState() => _Tv3MediaFullBleedEditorState();
}

class _Tv3MediaFullBleedEditorState extends State<_Tv3MediaFullBleedEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _priceCtrl;
  bool _uploading = false;
  int? _comboPick;

  bool get _isVideo => widget.pageType.toLowerCase().trim() == 'promo_video_bg';

  bool _tv3MediaBgIsCombo(Map<String, dynamic>? cfg) {
    final tc = cfg?['tv3Content'] ?? cfg?['tv3_content'];
    if (tc is! Map) return false;
    return (tc['mode'] ?? '').toString().toLowerCase().trim() == 'combo';
  }

  int? _tv3ComboIdFromConfig(Map<String, dynamic>? cfg) {
    final tc = cfg?['tv3Content'] ?? cfg?['tv3_content'];
    if (tc is! Map) return null;
    if ((tc['mode'] ?? '').toString().toLowerCase().trim() != 'combo') {
      return null;
    }
    final id = tc['comboId'] ?? tc['combo_id'];
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  Map<String, dynamic>? _mbMap() {
    final v = widget.config?['tv3MediaBg'] ?? widget.config?['tv3_media_bg'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  bool _showPhotos() {
    final mb = _mbMap();
    if (mb == null) return true;
    final sim = mb['showItemImages'] ?? mb['show_item_images'];
    if (sim == false || sim == 0 || sim == '0') return false;
    if (sim is String && sim.toLowerCase() == 'false') return false;
    return true;
  }

  bool _mbBool(String camel, String snake, [bool def = true]) {
    final mb = _mbMap();
    if (mb == null) return def;
    final v = mb[camel] ?? mb[snake];
    if (v == null) return def;
    if (v == false || v == 0 || v == '0') return false;
    if (v is String && v.toLowerCase() == 'false') return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _comboPick = _tv3ComboIdFromConfig(widget.config);
    final c = widget.config;
    _titleCtrl = TextEditingController(
      text: (c?['tv3OverlayTitle'] ?? c?['tv3_overlay_title'])?.toString() ?? '',
    );
    _subtitleCtrl = TextEditingController(
      text: (c?['tv3OverlaySubtitle'] ?? c?['tv3_overlay_subtitle'])?.toString() ?? '',
    );
    _priceCtrl = TextEditingController(
      text: (c?['tv3OverlayPrice'] ?? c?['tv3_overlay_price'])?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _Tv3MediaFullBleedEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      final c = widget.config;
      final t = (c?['tv3OverlayTitle'] ?? c?['tv3_overlay_title'])?.toString() ?? '';
      final s = (c?['tv3OverlaySubtitle'] ?? c?['tv3_overlay_subtitle'])?.toString() ?? '';
      final p = (c?['tv3OverlayPrice'] ?? c?['tv3_overlay_price'])?.toString() ?? '';
      if (_titleCtrl.text != t) _titleCtrl.text = t;
      if (_subtitleCtrl.text != s) _subtitleCtrl.text = s;
      if (_priceCtrl.text != p) _priceCtrl.text = p;
      setState(() => _comboPick = _tv3ComboIdFromConfig(widget.config));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _mediaPath() {
    final c = widget.config;
    final mb = c?['tv3MediaBg'] ?? c?['tv3_media_bg'];
    if (mb is! Map) return '';
    final p = mb['path'] ?? mb['url'] ?? mb['file'];
    return p?.toString().trim() ?? '';
  }

  Future<void> _pickMedia() async {
    final r = await FilePicker.platform.pickFiles(
      type: _isVideo ? FileType.video : FileType.image,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = _isVideo
          ? await widget.uploadRepo.uploadTvVideoBytes(
              bytes,
              f.name.isEmpty ? 'clip.mp4' : f.name,
            )
          : await widget.uploadRepo.uploadMenuImageBytes(
              bytes,
              f.name.isEmpty ? 'slide.jpg' : f.name,
            );
      await widget.onPatchConfig({
        'tv3MediaBg': {'path': path},
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveOverlays() async {
    await widget.onPatchConfig({
      'tv3OverlayTitle': _titleCtrl.text.trim(),
      'tv3OverlaySubtitle': _subtitleCtrl.text.trim(),
      'tv3OverlayPrice': _priceCtrl.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.adminTvSlideSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final path = _mediaPath();
    final isCombo = _tv3MediaBgIsCombo(widget.config);
    final contentKind = isCombo ? 'combo' : 'menu';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.adminTv3MediaBgTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.adminTv3MediaBgHint,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          path.isEmpty ? l10n.adminTv2BackgroundFileEmpty : path,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _uploading ? null : _pickMedia,
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isVideo ? Icons.video_file_rounded : Icons.image_rounded),
                label: Text(_isVideo ? l10n.adminTv3MediaPickVideo : l10n.adminTv3MediaPickPhoto),
              ),
            ),
            if (path.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _uploading
                    ? null
                    : () => widget.onPatchConfig({
                          'tv3MediaBg': {'path': ''},
                        }),
                child: Text(l10n.adminTv3MediaClear),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        FilterChip(
          label: Text(l10n.adminTv2VideoBgShowPhotos),
          selected: _showPhotos(),
          onSelected: (v) => widget.onPatchConfig({
            'tv3MediaBg': {'showItemImages': v},
          }),
        ),
        const Divider(height: 28),
        Text(l10n.adminTv2VideoBgContentSource, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment<String>(
              value: 'menu',
              label: Text(
                l10n.adminTv2VideoBgModeMenu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment<String>(
              value: 'combo',
              label: Text(
                l10n.adminTv2VideoBgModeCombo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {contentKind},
          onSelectionChanged: (next) async {
            final v = next.first;
            if (v == contentKind) return;
            if (v == 'menu') {
              await widget.onSwitchMenu();
            } else {
              await widget.onSwitchCombo();
            }
          },
        ),
        const SizedBox(height: 16),
        if (!isCombo) ...[
          FilledButton.tonal(
            onPressed: () => widget.onPickHero(),
            child: Text(l10n.adminTv2VideoBgChooseHero),
          ),
          const SizedBox(height: 8),
          if (widget.heroRows.isEmpty)
            Text(
              l10n.adminTv3PromoHeroEmpty,
              style: theme.textTheme.bodySmall,
            )
          else
            ...widget.heroRows.map(
              (e) => ListTile(
                dense: true,
                title: Text(e.name.ru),
                subtitle: Text(e.menuItemId),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => widget.onRemoveHero(e.id),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            l10n.adminTv2VideoBgWhatToShowProduct,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowDescription),
                selected: _mbBool('showDescription', 'show_description'),
                onSelected: (v) => widget.onPatchConfig({
                  'tv3MediaBg': {'showDescription': v},
                }),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowPrice),
                selected: _mbBool('showPrice', 'show_price'),
                onSelected: (v) => widget.onPatchConfig({
                  'tv3MediaBg': {'showPrice': v},
                }),
              ),
            ],
          ),
        ] else ...[
          DropdownButtonFormField<int>(
            key: ValueKey<int?>(_comboPick),
            isExpanded: true,
            initialValue: _comboPick != null &&
                    widget.combos.any((c) => c.id == _comboPick)
                ? _comboPick
                : null,
            decoration: InputDecoration(
              labelText: l10n.adminTv2VideoBgSelectCombo,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final c in widget.combos)
                DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(
                    c.nameRu.isEmpty ? '#${c.id}' : c.nameRu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _comboPick = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _comboPick == null
                ? null
                : () => widget.onApplyCombo(_comboPick!),
            child: Text(l10n.adminTv2VideoBgApplyCombo),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.adminTv2VideoBgWhatToShowCombo,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowDescription),
                selected: _mbBool('showDescription', 'show_description'),
                onSelected: (v) => widget.onPatchConfig({
                  'tv3MediaBg': {'showDescription': v},
                }),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowPrice),
                selected: _mbBool('showPrice', 'show_price'),
                onSelected: (v) => widget.onPatchConfig({
                  'tv3MediaBg': {'showPrice': v},
                }),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowComboComposition),
                selected: _mbBool('showComboParts', 'show_combo_parts'),
                onSelected: (v) => widget.onPatchConfig({
                  'tv3MediaBg': {'showComboParts': v},
                }),
              ),
            ],
          ),
        ],
        const Divider(height: 28),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: l10n.adminTv3OverlayTitleLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _subtitleCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.adminTv3OverlaySubtitleLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priceCtrl,
          decoration: InputDecoration(
            labelText: l10n.adminTv3OverlayPriceLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saveOverlays,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _Tv3PagePromoLineEditor extends StatefulWidget {
  const _Tv3PagePromoLineEditor({
    super.key,
    required this.label,
    required this.hint,
    required this.saveLabel,
    required this.initial,
    required this.onSave,
  });

  final String label;
  final String hint;
  final String saveLabel;
  final String initial;
  final Future<void> Function(String value) onSave;

  @override
  State<_Tv3PagePromoLineEditor> createState() => _Tv3PagePromoLineEditorState();
}

class _Tv3PagePromoLineEditorState extends State<_Tv3PagePromoLineEditor> {
  late final TextEditingController _c;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _Tv3PagePromoLineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(_c.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            maxLength: 120,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: widget.hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(widget.saveLabel),
          ),
        ),
      ],
    );
  }
}

class _Tv3PageDetail {
  _Tv3PageDetail({required this.page, required this.items});

  final AdminScreenPageRow page;
  final List<ScreenPageItemRow> items;
}
