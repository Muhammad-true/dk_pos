import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_combo_row.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screen_page_item_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_video_bg_media_editor.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

const _kTv2PageTypes = ['split', 'drinks', 'carousel', 'list', 'video_bg'];
const _kRoles = ['hero', 'list', 'hotdog'];

bool _tv2EditorIsList(String t) => t.toLowerCase().trim() == 'list';

bool _tv2EditorVideoBgCombo(Map<String, dynamic>? config) {
  final tc = config?['tv2Content'] ?? config?['tv2_content'];
  if (tc is! Map) return false;
  return (tc['mode'] ?? '').toString().toLowerCase().trim() == 'combo';
}

List<String> _tv2EditorRoles(String pageType, Map<String, dynamic>? config) {
  final t = pageType.toLowerCase().trim();
  if (t == 'list') return ['hero', 'list'];
  if (t == 'video_bg') return [];
  return _kRoles;
}

/// Красный акцент ТВ2 (как в `dk_digitial_menu`).
const Color _kTv2PreviewRed = Color(0xFFE4002B);

/// Редактор страниц ТВ2: заголовки секций и товары (герой / список / вторая колонка).
class Tv2ScreenPagesEditorScreen extends StatefulWidget {
  const Tv2ScreenPagesEditorScreen({
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
  State<Tv2ScreenPagesEditorScreen> createState() =>
      _Tv2ScreenPagesEditorScreenState();
}

class _Tv2ScreenPagesEditorScreenState extends State<Tv2ScreenPagesEditorScreen> {
  List<AdminScreenPageRow> _pages = [];
  List<AdminMenuItemRow> _menuItems = [];
  final Map<int, _PageDetail> _detailByPageId = {};
  bool _loading = true;
  bool _savingPageOrder = false;
  String? _error;
  String _newPageType = 'split';
  /// На узком экране Android включаем портрет, при выходе возвращаем все ориентации.
  bool _androidPhonePortraitLock = false;

  @override
  void initState() {
    super.initState();
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phone = MediaQuery.sizeOf(context).shortestSide < 600;
      final android = defaultTargetPlatform == TargetPlatform.android;
      if (!phone || !android) return;
      _androidPhonePortraitLock = true;
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });
  }

  @override
  void dispose() {
    if (_androidPhonePortraitLock) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
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
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _menuItems = items;
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
        _detailByPageId[pageId] = _PageDetail(page: row, items: items);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDeletePage(AdminScreenPageRow p, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenPageDeleteTitle),
        content: Text(
          l10n.adminScreenPageDeleteConfirm(_tv2PageTypeLabel(l10n, p.pageType)),
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

  Future<void> _persistTv2PageOrderAfterReorder(AppLocalizations l10n) async {
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
        SnackBar(content: Text(l10n.adminTv2EditorOrderSaved)),
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

  void _onReorderTv2Pages(int oldIndex, int newIndex, AppLocalizations l10n) {
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
    _persistTv2PageOrderAfterReorder(l10n);
  }

  Future<void> _addPage(AppLocalizations l10n) async {
    final nextOrder = _pages.isEmpty
        ? 0
        : _pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    try {
      await widget.screensRepo.addScreenPage(
        widget.screenId,
        pageType: _newPageType,
        sortOrder: nextOrder,
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

  Future<void> _saveTitles(
    int pageId,
    String listRu,
    String secondRu,
    AppLocalizations l10n,
  ) async {
    try {
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        listTitle: {'ru': listRu.trim()},
        secondListTitle: {'ru': secondRu.trim()},
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorTitlesSaved)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _addItemsBatch(
    int pageId,
    List<String> menuItemIds,
    String role,
    AppLocalizations l10n,
  ) async {
    if (menuItemIds.isEmpty) return;
    var ok = 0;
    for (final id in menuItemIds) {
      try {
        await widget.screensRepo.addScreenPageItem(
          widget.screenId,
          pageId,
          menuItemId: id,
          role: role,
        );
        ok++;
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
    if (ok == 0) return;
    _detailByPageId.remove(pageId);
    await _loadDetail(pageId);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == 1
                ? l10n.adminTv2EditorItemAdded
                : l10n.adminTv2EditorItemsAddedBatch(ok),
          ),
        ),
      );
    }
  }

  Future<void> _removeItem(
    int pageId,
    int itemRowId,
    AppLocalizations l10n,
  ) async {
    try {
      await widget.screensRepo.deleteScreenPageItem(
        widget.screenId,
        pageId,
        itemRowId,
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

  Future<void> _clearAllPageItems(int pageId) async {
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

  Future<void> _videoBgSwitchToMenuMode(int pageId) async {
    try {
      await _clearAllPageItems(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv2Content'] = {'mode': 'menu'};
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

  Future<void> _videoBgSwitchToComboMode(int pageId) async {
    try {
      await _clearAllPageItems(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv2Content'] = {'mode': 'combo'};
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

  Future<void> _patchTvVideoBg(int pageId, Map<String, dynamic> vgPatch) async {
    final d = _detailByPageId[pageId];
    final base = Map<String, dynamic>.from(d?.page.config ?? {});
    final cur = Map<String, dynamic>.from(
      base['tvVideoBg'] is Map
          ? Map<String, dynamic>.from(base['tvVideoBg']! as Map)
          : {},
    );
    cur.addAll(vgPatch);
    base['tvVideoBg'] = cur;
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

  Future<void> _videoBgPickHero(int pageId, AppLocalizations l10n) async {
    try {
      await _clearAllPageItems(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv2Content'] = {'mode': 'menu'};
      await widget.screensRepo.patchScreenPage(
        widget.screenId,
        pageId,
        config: base,
      );
      _detailByPageId.remove(pageId);
      await _loadDetail(pageId);
      await _reload();
      if (!mounted) return;
      await _pickItemDialog(pageId, 'hero', l10n);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _videoBgApplyCombo(
    int pageId,
    int comboId,
    AppLocalizations l10n,
  ) async {
    try {
      await _clearAllPageItems(pageId);
      final d = _detailByPageId[pageId];
      final base = Map<String, dynamic>.from(d?.page.config ?? {});
      base['tv2Content'] = {'mode': 'combo', 'comboId': comboId};
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

  String _tv2PageTypeLabel(AppLocalizations l10n, String t) {
    switch (t) {
      case 'split':
        return l10n.adminTv2PageTypeSplit;
      case 'drinks':
        return l10n.adminTv2PageTypeDrinks;
      case 'carousel':
        return l10n.adminTv2PageTypeCarousel;
      case 'list':
        return l10n.adminTv2PageTypeList;
      case 'video_bg':
        return l10n.adminTv2PageTypeVideoBg;
      default:
        return t;
    }
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    switch (role) {
      case 'hero':
        return l10n.adminTv2EditorRoleHero;
      case 'hotdog':
        return l10n.adminTv2EditorRoleHotdog;
      case 'list':
      default:
        return l10n.adminTv2EditorRoleList;
    }
  }

  String _roleLabelForPageType(
    AppLocalizations l10n,
    String pageType,
    String role,
  ) {
    if (_tv2EditorIsList(pageType)) {
      if (role == 'hero') return l10n.adminTv2EditorRoleHeroCardList;
      if (role == 'list') return l10n.adminTv2EditorRoleListGrid;
    }
    return _roleLabel(l10n, role);
  }

  Future<void> _pickItemDialog(
    int pageId,
    String role,
    AppLocalizations l10n,
  ) async {
    final isHero = role == 'hero';
    final ids = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        var q = '';
        final selected = <String>{};
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
            final nSel = isHero ? (heroId != null ? 1 : 0) : selected.length;
            return AlertDialog(
              title: Text(l10n.adminTv2EditorPickItem),
              content: SizedBox(
                width: math.min(460, MediaQuery.sizeOf(ctx).width * 0.94),
                height: math.min(400, MediaQuery.sizeOf(ctx).height * 0.76),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.adminTv2EditorPickHintMulti,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
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
                          if (isHero) {
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
                          }
                          return CheckboxListTile(
                            value: selected.contains(it.id),
                            onChanged: (v) => setSt(() {
                              if (v == true) {
                                selected.add(it.id);
                              } else {
                                selected.remove(it.id);
                              }
                            }),
                            title: Text(it.name.ru, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(it.id, maxLines: 1, overflow: TextOverflow.ellipsis),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
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
                  onPressed: nSel < 1
                      ? null
                      : () {
                          if (isHero && heroId != null) {
                            Navigator.pop(ctx, [heroId!]);
                          } else if (!isHero) {
                            Navigator.pop(ctx, selected.toList());
                          }
                        },
                  child: Text(l10n.adminTv2EditorAddSelectedButton(nSel)),
                ),
              ],
            );
          },
        );
      },
    );
    if (ids != null && ids.isNotEmpty) {
      await _addItemsBatch(pageId, ids, role, l10n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTv2EditorTitle),
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
                      l10n.adminTv2EditorSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 22,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.adminTv2UserGuideTitle,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(l10n.adminTv2UserGuide1, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Text(l10n.adminTv2UserGuide2, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Text(l10n.adminTv2UserGuide3, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Text(l10n.adminTv2UserGuide4, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey<String>(_newPageType),
                            isExpanded: true,
                            initialValue: _newPageType,
                            decoration: InputDecoration(
                              labelText: l10n.adminScreenPageTypeLabel,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              for (final t in _kTv2PageTypes)
                                DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    _tv2PageTypeLabel(l10n, t),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _newPageType = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: FilledButton.icon(
                            onPressed: () => _addPage(l10n),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              l10n.adminScreenPageAdd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_pages.isEmpty)
                      Text(l10n.adminTv2EditorNoPages)
                    else ...[
                      Text(
                        l10n.adminTv2EditorReorderHint,
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
                                _onReorderTv2Pages(oldIndex, newIndex, l10n),
                            children: [
                              for (var i = 0; i < _pages.length; i++)
                                _PageCard(
                                  key: ValueKey<int>(_pages[i].id),
                                  reorderListIndex: i,
                                  pageListRow: _pages[i],
                                  detail: _detailByPageId[_pages[i].id],
                                  l10n: l10n,
                                  combosRepo: widget.combosRepo,
                                  uploadRepo: widget.uploadRepo,
                                  onExpand: () => _loadDetail(_pages[i].id),
                                  onSaveTitles: (a, b) =>
                                      _saveTitles(_pages[i].id, a, b, l10n),
                                  onPickItem: (role) =>
                                      _pickItemDialog(_pages[i].id, role, l10n),
                                  onRemoveItem: (rowId) =>
                                      _removeItem(_pages[i].id, rowId, l10n),
                                  onPatchTvVideoBg: (m) =>
                                      _patchTvVideoBg(_pages[i].id, m),
                                  onVideoBgPickHero: () =>
                                      _videoBgPickHero(_pages[i].id, l10n),
                                  onVideoBgApplyCombo: (cid) =>
                                      _videoBgApplyCombo(_pages[i].id, cid, l10n),
                                  onVideoBgSwitchToMenuMode: () =>
                                      _videoBgSwitchToMenuMode(_pages[i].id),
                                  onVideoBgSwitchToComboMode: () =>
                                      _videoBgSwitchToComboMode(_pages[i].id),
                                  onDeletePage: () =>
                                      _confirmDeletePage(_pages[i], l10n),
                                  roleLabel: (ln, role) =>
                                      _roleLabelForPageType(
                                        ln,
                                        _pages[i].pageType,
                                        role,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

/// Как на ТВ: слева герой; справа две полосы — заголовок и ряд «карточек» товаров.
class _Tv2LayoutMiniPreview extends StatelessWidget {
  const _Tv2LayoutMiniPreview({
    required this.pageType,
    required this.listTitle,
    required this.secondTitle,
    required this.items,
    required this.l10n,
    this.pageConfig,
  });

  final String pageType;
  final String listTitle;
  final String secondTitle;
  final List<ScreenPageItemRow> items;
  final AppLocalizations l10n;
  /// Для `video_bg`: `tvVideoBg`, `tv2Content` и т.д.
  final Map<String, dynamic>? pageConfig;

  static List<ScreenPageItemRow> _sorted(List<ScreenPageItemRow> raw) {
    final copy = List<ScreenPageItemRow>.from(raw);
    copy.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return copy;
  }

  static List<Widget> _productTiles(
    BuildContext context,
    List<ScreenPageItemRow> rows,
    AppLocalizations l10n, {
    int maxVisible = 12,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (rows.isEmpty) {
      return [
        Text(
          '—',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    final show = rows.length > maxVisible ? rows.sublist(0, maxVisible) : rows;
    final more = rows.length - show.length;
    return [
      ...show.map(
        (e) => Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 88),
                child: Text(
                  e.name.ru,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(height: 1.1),
                ),
              ),
            ),
          ),
        ),
      ),
      if (more > 0)
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 4),
          child: Text(
            l10n.adminTv2EditorLayoutMore(more),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = _sorted(items);
    final t = pageType.toLowerCase().trim();

    if (t == 'list') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminTv2EditorLayoutPreview,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.adminTv2EditorLayoutListHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Wrap(
              children: _productTiles(context, sorted, l10n, maxVisible: 24),
            ),
          ),
        ],
      );
    }

    if (t == 'video_bg') {
      final cfg = pageConfig;
      final vg = cfg?['tvVideoBg'] ?? cfg?['tv_video_bg'];
      var showPh = true;
      if (vg is Map) {
        final sim = vg['showItemImages'] ?? vg['show_item_images'];
        if (sim == false ||
            sim == 0 ||
            sim == '0' ||
            (sim is String && sim.toLowerCase() == 'false')) {
          showPh = false;
        }
      }
      final tc = cfg?['tv2Content'] ?? cfg?['tv2_content'];
      final isCombo = tc is Map &&
          (tc['mode'] ?? '').toString().toLowerCase().trim() == 'combo';
      final heroes = sorted.where((e) => e.role == 'hero').toList();
      final heroLabel = heroes.isEmpty
          ? null
          : heroes.first.name.ru;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminTv2EditorLayoutPreview,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.adminTv2EditorVideoBgLayoutHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 240,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
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
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showPh) ...[
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCombo
                                    ? l10n.adminTv2VideoBgModeCombo
                                    : (heroLabel ??
                                        l10n.adminTv2EditorLayoutHeroEmpty),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Color(0xB3000000),
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '— · —',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _kTv2PreviewRed,
                                  fontWeight: FontWeight.w800,
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Color(0xB3000000),
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final heroes = sorted.where((e) => e.role == 'hero').toList();
    final listR = sorted.where((e) => e.role == 'list').toList();
    final hotR = sorted.where((e) => e.role == 'hotdog').toList();
    final heroLabel = heroes.isEmpty ? null : heroes.first.name.ru;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminTv2EditorLayoutPreview,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          height: 260,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kTv2PreviewRed, width: 2),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    heroLabel ?? l10n.adminTv2EditorLayoutHeroEmpty,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _PreviewRightStrip(
                        title: listTitle,
                        placeholder: l10n.adminTv2EditorLayoutTitlePlaceholder,
                        items: listR,
                        l10n: l10n,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _PreviewRightStrip(
                        title: secondTitle,
                        placeholder: l10n.adminTv2EditorLayoutTitlePlaceholder,
                        items: hotR,
                        l10n: l10n,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRightStrip extends StatelessWidget {
  const _PreviewRightStrip({
    required this.title,
    required this.placeholder,
    required this.items,
    required this.l10n,
  });

  final String title;
  final String placeholder;
  final List<ScreenPageItemRow> items;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = title.trim().isEmpty;
    final band = empty ? placeholder : title.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 4, height: 14, color: _kTv2PreviewRed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                band.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: empty ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 4, height: 14, color: _kTv2PreviewRed),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 4,
                runSpacing: 4,
                children: _Tv2LayoutMiniPreview._productTiles(
                  context,
                  items,
                  l10n,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageDetail {
  _PageDetail({required this.page, required this.items});

  final AdminScreenPageRow page;
  final List<ScreenPageItemRow> items;
}

class _PageCard extends StatefulWidget {
  const _PageCard({
    super.key,
    required this.reorderListIndex,
    required this.pageListRow,
    required this.detail,
    required this.l10n,
    required this.combosRepo,
    required this.uploadRepo,
    required this.onExpand,
    required this.onSaveTitles,
    required this.onPickItem,
    required this.onRemoveItem,
    required this.onPatchTvVideoBg,
    required this.onVideoBgPickHero,
    required this.onVideoBgApplyCombo,
    required this.onVideoBgSwitchToMenuMode,
    required this.onVideoBgSwitchToComboMode,
    required this.onDeletePage,
    required this.roleLabel,
  });

  /// Индекс в [ReorderableListView] для [ReorderableDragStartListener].
  final int reorderListIndex;
  final AdminScreenPageRow pageListRow;
  final _PageDetail? detail;
  final AppLocalizations l10n;
  final CombosAdminRepository combosRepo;
  final UploadRepository uploadRepo;
  final VoidCallback onExpand;
  final Future<void> Function(String listRu, String secondRu) onSaveTitles;
  final Future<void> Function(String role) onPickItem;
  final Future<void> Function(int itemRowId) onRemoveItem;
  final Future<void> Function(Map<String, dynamic> patch) onPatchTvVideoBg;
  final Future<void> Function() onVideoBgPickHero;
  final Future<void> Function(int comboId) onVideoBgApplyCombo;
  final Future<void> Function() onVideoBgSwitchToMenuMode;
  final Future<void> Function() onVideoBgSwitchToComboMode;
  final Future<void> Function() onDeletePage;
  final String Function(AppLocalizations l10n, String role) roleLabel;

  @override
  State<_PageCard> createState() => _PageCardState();
}

class _PageCardState extends State<_PageCard> {
  late final TextEditingController _listCtrl;
  late final TextEditingController _secondCtrl;
  String _addRole = 'list';

  void _onPreviewTitles() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final lt = widget.pageListRow.listTitle?.ru ?? '';
    final st = widget.pageListRow.secondListTitle?.ru ?? '';
    _listCtrl = TextEditingController(text: lt);
    _secondCtrl = TextEditingController(text: st);
    _listCtrl.addListener(_onPreviewTitles);
    _secondCtrl.addListener(_onPreviewTitles);
  }

  @override
  void didUpdateWidget(covariant _PageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final d = widget.detail;
    if (d != null) {
      final lt = d.page.listTitle?.ru ?? '';
      final st = d.page.secondListTitle?.ru ?? '';
      if (_listCtrl.text != lt) _listCtrl.text = lt;
      if (_secondCtrl.text != st) _secondCtrl.text = st;
    }
    final roles = _tv2EditorRoles(
      widget.pageListRow.pageType,
      widget.detail?.page.config,
    );
    if (roles.isNotEmpty && !roles.contains(_addRole)) {
      _addRole = roles.first;
    }
  }

  @override
  void dispose() {
    _listCtrl.removeListener(_onPreviewTitles);
    _secondCtrl.removeListener(_onPreviewTitles);
    _listCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final p = widget.pageListRow;
    final items = widget.detail?.items ?? const <ScreenPageItemRow>[];
    final pt = p.pageType.toLowerCase().trim();
    final listOnly = _tv2EditorIsList(p.pageType);
    final videoBg = pt == 'video_bg';
    final pageCfg = widget.detail?.page.config;
    final roles = _tv2EditorRoles(p.pageType, pageCfg);

    final subtitleHint = videoBg
        ? l10n.adminTv2EditorPageHintVideoBg
        : listOnly
            ? l10n.adminTv2EditorPageHintList
            : l10n.adminTv2EditorPageHintSplit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        onExpansionChanged: (open) {
          if (open) widget.onExpand();
        },
        title: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.reorderListIndex,
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
              onPressed: () => widget.onDeletePage(),
            ),
          ],
        ),
        subtitle: Text(
          subtitleHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!videoBg) ...[
                  TextField(
                    controller: _listCtrl,
                    decoration: InputDecoration(
                      labelText: listOnly
                          ? l10n.adminTv2EditorListGridTitleRu
                          : l10n.adminTv2EditorListTitleRu,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (!listOnly) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _secondCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.adminTv2EditorSecondTitleRu,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => widget.onSaveTitles(_listCtrl.text, _secondCtrl.text),
                    child: Text(l10n.adminTv2EditorSaveTitles),
                  ),
                  const Divider(height: 24),
                  _Tv2OptionalBackgroundVideoEditor(
                    l10n: l10n,
                    config: pageCfg,
                    uploadRepo: widget.uploadRepo,
                    onPatchTvVideoBg: widget.onPatchTvVideoBg,
                  ),
                ],
                if (videoBg) ...[
                  _VideoBgPageEditor(
                    l10n: l10n,
                    config: widget.detail?.page.config,
                    combosRepo: widget.combosRepo,
                    uploadRepo: widget.uploadRepo,
                    onPatchTvVideoBg: widget.onPatchTvVideoBg,
                    onVideoBgPickHero: widget.onVideoBgPickHero,
                    onVideoBgApplyCombo: widget.onVideoBgApplyCombo,
                    onVideoBgSwitchToMenuMode: widget.onVideoBgSwitchToMenuMode,
                    onVideoBgSwitchToComboMode: widget.onVideoBgSwitchToComboMode,
                  ),
                  const SizedBox(height: 16),
                  _Tv2LayoutMiniPreview(
                    pageType: p.pageType,
                    listTitle: _listCtrl.text.trim(),
                    secondTitle: listOnly ? '' : _secondCtrl.text.trim(),
                    items: items,
                    l10n: l10n,
                    pageConfig: widget.detail?.page.config,
                  ),
                ],
                if (roles.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    l10n.adminTv2EditorItemsSection,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _Tv2LayoutMiniPreview(
                    pageType: p.pageType,
                    listTitle: _listCtrl.text.trim(),
                    secondTitle: listOnly ? '' : _secondCtrl.text.trim(),
                    items: items,
                    l10n: l10n,
                    pageConfig: widget.detail?.page.config,
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('${_addRole}_${roles.join()}'),
                        isExpanded: true,
                        initialValue: roles.contains(_addRole) ? _addRole : roles.first,
                        decoration: InputDecoration(
                          labelText: l10n.adminTv2EditorAddAsRole,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final r in roles)
                            DropdownMenuItem(
                              value: r,
                              child: Text(
                                widget.roleLabel(l10n, r),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _addRole = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => widget.onPickItem(_addRole),
                        child: Text(l10n.adminTv2EditorAddFromMenu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Text(
                      l10n.adminTv2EditorNoItemsOnPage,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    ...items.map(
                      (it) => ListTile(
                        title: Text(it.name.ru),
                        subtitle: Text(
                          '${it.menuItemId} · ${widget.roleLabel(l10n, it.role)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => widget.onRemoveItem(it.id),
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

/// Видео за split/list/drinks/carousel — то же поле `config.tvVideoBg`, что и у `video_bg`.
class _Tv2OptionalBackgroundVideoEditor extends StatefulWidget {
  const _Tv2OptionalBackgroundVideoEditor({
    required this.l10n,
    required this.config,
    required this.uploadRepo,
    required this.onPatchTvVideoBg,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? config;
  final UploadRepository uploadRepo;
  final Future<void> Function(Map<String, dynamic> patch) onPatchTvVideoBg;

  @override
  State<_Tv2OptionalBackgroundVideoEditor> createState() =>
      _Tv2OptionalBackgroundVideoEditorState();
}

class _Tv2OptionalBackgroundVideoEditorState
    extends State<_Tv2OptionalBackgroundVideoEditor> {
  bool _uploading = false;

  Map<String, dynamic>? _vgMap() {
    final v = widget.config?['tvVideoBg'] ?? widget.config?['tv_video_bg'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  String _videoPath() {
    final vg = _vgMap();
    final p = vg?['path'] ?? vg?['url'] ?? vg?['file'];
    return p?.toString().trim() ?? '';
  }

  String _imagePath() {
    final vg = _vgMap();
    final p = vg?['imagePath'] ?? vg?['image_path'];
    return p?.toString().trim() ?? '';
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = await widget.uploadRepo.uploadTvVideoBytes(
        bytes,
        f.name.isEmpty ? 'video.mp4' : f.name,
      );
      await widget.onPatchTvVideoBg({'path': path});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = await widget.uploadRepo.uploadMenuImageBytes(
        bytes,
        f.name.isEmpty ? 'bg.jpg' : f.name,
      );
      await widget.onPatchTvVideoBg({'imagePath': path});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final path = _videoPath();
    final img = _imagePath();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvVideoBgMediaEditor(
          title: l10n.adminTv2OptionalVideoTitle,
          videoHint: l10n.adminTv2OptionalVideoHint,
          videoPath: path,
          videoEmptyText: l10n.adminTv2VideoBgNoVideo,
          pickVideoText: l10n.adminTv2VideoBgPickVideo,
          clearVideoText: l10n.adminTv2OptionalVideoClear,
          imageTitle: l10n.adminTv2OptionalPhotoTitle,
          imageHint: l10n.adminTv2OptionalPhotoHint,
          imagePath: img,
          imageEmptyText: l10n.adminTv2BackgroundFileEmpty,
          pickImageText: l10n.adminTv2VideoBgPickPhoto,
          clearImageText: l10n.adminTv2OptionalPhotoClear,
          uploading: _uploading,
          onPickVideo: _pickVideo,
          onClearVideo: () => widget.onPatchTvVideoBg({'path': ''}),
          onPickImage: _pickImage,
          onClearImage: () => widget.onPatchTvVideoBg({'imagePath': ''}),
        ),
      ],
    );
  }
}

class _VideoBgPageEditor extends StatefulWidget {
  const _VideoBgPageEditor({
    required this.l10n,
    required this.config,
    required this.combosRepo,
    required this.uploadRepo,
    required this.onPatchTvVideoBg,
    required this.onVideoBgPickHero,
    required this.onVideoBgApplyCombo,
    required this.onVideoBgSwitchToMenuMode,
    required this.onVideoBgSwitchToComboMode,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? config;
  final CombosAdminRepository combosRepo;
  final UploadRepository uploadRepo;
  final Future<void> Function(Map<String, dynamic>) onPatchTvVideoBg;
  final Future<void> Function() onVideoBgPickHero;
  final Future<void> Function(int comboId) onVideoBgApplyCombo;
  final Future<void> Function() onVideoBgSwitchToMenuMode;
  final Future<void> Function() onVideoBgSwitchToComboMode;

  @override
  State<_VideoBgPageEditor> createState() => _VideoBgPageEditorState();
}

class _VideoBgPageEditorState extends State<_VideoBgPageEditor> {
  List<AdminComboRow> _combos = [];
  bool _loadingCombos = true;
  bool _uploading = false;
  int? _comboPick;

  @override
  void initState() {
    super.initState();
    _comboPick = _comboIdFromConfig(widget.config);
    _loadCombos();
  }

  @override
  void didUpdateWidget(covariant _VideoBgPageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      setState(() => _comboPick = _comboIdFromConfig(widget.config));
    }
  }

  int? _comboIdFromConfig(Map<String, dynamic>? cfg) {
    final tc = cfg?['tv2Content'] ?? cfg?['tv2_content'];
    if (tc is! Map) return null;
    if ((tc['mode'] ?? '').toString().toLowerCase().trim() != 'combo') {
      return null;
    }
    final id = tc['comboId'] ?? tc['combo_id'];
    if (id is num) return id.toInt();
    return int.tryParse(id?.toString() ?? '');
  }

  Future<void> _loadCombos() async {
    try {
      final list = await widget.combosRepo.fetchCombos();
      if (mounted) {
        setState(() {
          _combos = list.where((c) => c.isActive == 1).toList();
          _loadingCombos = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCombos = false);
    }
  }

  Map<String, dynamic>? _vgMap() {
    final v = widget.config?['tvVideoBg'] ?? widget.config?['tv_video_bg'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  bool _showPhotos() {
    final vg = _vgMap();
    if (vg == null) return true;
    final sim = vg['showItemImages'] ?? vg['show_item_images'];
    if (sim == false || sim == 0 || sim == '0') return false;
    if (sim is String && sim.toLowerCase() == 'false') return false;
    return true;
  }

  bool _vgBool(String camel, String snake, [bool def = true]) {
    final vg = _vgMap();
    if (vg == null) return def;
    final v = vg[camel] ?? vg[snake];
    if (v == null) return def;
    if (v == false || v == 0 || v == '0') return false;
    if (v is String && v.toLowerCase() == 'false') return false;
    return true;
  }

  String _videoPath() {
    final vg = _vgMap();
    final p = vg?['path'] ?? vg?['url'] ?? vg?['file'];
    return p?.toString().trim() ?? '';
  }

  String _photoBgPath() {
    final vg = _vgMap();
    final p = vg?['imagePath'] ?? vg?['image_path'];
    return p?.toString().trim() ?? '';
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = await widget.uploadRepo.uploadTvVideoBytes(
        bytes,
        f.name.isEmpty ? 'video.mp4' : f.name,
      );
      await widget.onPatchTvVideoBg({'path': path});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPhotoBg() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = await widget.uploadRepo.uploadMenuImageBytes(
        bytes,
        f.name.isEmpty ? 'bg.jpg' : f.name,
      );
      await widget.onPatchTvVideoBg({'imagePath': path});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final path = _videoPath();
    final photoBg = _photoBgPath();
    final isCombo = _tv2EditorVideoBgCombo(widget.config);
    final contentKind = isCombo ? 'combo' : 'menu';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvVideoBgMediaEditor(
          title: l10n.adminTv2VideoBgTitle,
          videoPath: path,
          videoEmptyText: l10n.adminTv2VideoBgNoVideo,
          pickVideoText: l10n.adminTv2VideoBgPickVideo,
          clearVideoText: l10n.adminTv2OptionalVideoClear,
          imageTitle: l10n.adminTv2OptionalPhotoTitle,
          imageHint: l10n.adminTv2OptionalPhotoHint,
          imagePath: photoBg,
          imageEmptyText: l10n.adminTv2BackgroundFileEmpty,
          pickImageText: l10n.adminTv2VideoBgPickPhoto,
          clearImageText: l10n.adminTv2VideoBgClearPhoto,
          uploading: _uploading,
          onPickVideo: _pickVideo,
          onClearVideo: () => widget.onPatchTvVideoBg({'path': ''}),
          onPickImage: _pickPhotoBg,
          onClearImage: () => widget.onPatchTvVideoBg({'imagePath': ''}),
        ),
        const SizedBox(height: 8),
        FilterChip(
          label: Text(l10n.adminTv2VideoBgShowPhotos),
          selected: _showPhotos(),
          onSelected: (v) => widget.onPatchTvVideoBg({'showItemImages': v}),
        ),
        const Divider(height: 24),
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
              await widget.onVideoBgSwitchToMenuMode();
            } else {
              await widget.onVideoBgSwitchToComboMode();
            }
          },
        ),
        const SizedBox(height: 16),
        if (!isCombo) ...[
          FilledButton.tonal(
            onPressed: widget.onVideoBgPickHero,
            child: Text(l10n.adminTv2VideoBgChooseHero),
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
                selected: _vgBool('showDescription', 'show_description'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showDescription': v}),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowPrice),
                selected: _vgBool('showPrice', 'show_price'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showPrice': v}),
              ),
            ],
          ),
        ] else ...[
          if (_loadingCombos)
            const LinearProgressIndicator(minHeight: 3)
          else
            DropdownButtonFormField<int>(
              key: ValueKey<int?>(_comboPick),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.adminTv2VideoBgSelectCombo,
                border: const OutlineInputBorder(),
              ),
              initialValue: _comboPick != null && _combos.any((c) => c.id == _comboPick)
                  ? _comboPick
                  : null,
              items: [
                for (final c in _combos)
                  DropdownMenuItem<int>(value: c.id, child: Text(c.nameRu)),
              ],
              onChanged: (v) => setState(() => _comboPick = v),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _comboPick == null
                ? null
                : () => widget.onVideoBgApplyCombo(_comboPick!),
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
                selected: _vgBool('showDescription', 'show_description'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showDescription': v}),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowPrice),
                selected: _vgBool('showPrice', 'show_price'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showPrice': v}),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowComboComposition),
                selected: _vgBool('showComboParts', 'show_combo_parts'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showComboParts': v}),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
