import 'dart:async';
import 'dart:math' as math;

import 'package:dk_digitial_menu/models/tv_layout_config.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/locale/api_locale.dart';
import 'package:dk_pos/features/admin/data/admin_combo_row.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_display_preview_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/screen_page_item_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/admin_tv_preview_page.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_tv_master_detail_layout.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_color_picker_field.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_layout_type_catalog.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_layout_type_picker.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_media_guide.dart';
import 'package:dk_pos/features/admin/presentation/widgets/tv_video_bg_media_editor.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _kRoles = ['hero', 'list', 'hotdog'];

bool _tv2EditorIsList(String t) => t.toLowerCase().trim() == 'list';

bool _tv2EditorIsProductGrid(String t) =>
    t.toLowerCase().trim() == 'product_grid';

bool _tv2EditorIsFourShowcase(String t) =>
    t.toLowerCase().trim() == 'four_showcase';

bool _tv2EditorIsEditorialShowcase(String t) =>
    t.toLowerCase().trim() == 'editorial_showcase';

bool _tv2EditorIsTwoProductShowcase(String t) {
  final x = t.toLowerCase().trim();
  return x == 'two_product_equal' || x == 'two_product_diagonal';
}

bool _tv2EditorIsPizzaPage(String t) {
  final x = t.toLowerCase().trim();
  return x == 'pizza_show' || x == 'pizza_grid';
}

bool _tv2EditorIsCatalogPage(String t) =>
    _tv2EditorIsList(t) ||
    _tv2EditorIsProductGrid(t) ||
    _tv2EditorIsFourShowcase(t) ||
    _tv2EditorIsEditorialShowcase(t) ||
    _tv2EditorIsTwoProductShowcase(t) ||
    _tv2EditorIsPizzaPage(t);

int _readProductGridColsFromCfg(Map<String, dynamic>? cfg) {
  final raw = cfg?['tv2ProductGridColumns'] ?? cfg?['tv2_product_grid_columns'];
  if (raw is num) {
    final n = raw.toInt();
    if (n >= 2 && n <= 5) return n;
  }
  if (raw is String) {
    final n = int.tryParse(raw.trim());
    if (n != null && n >= 2 && n <= 5) return n;
  }
  return 0;
}

int _previewProductGridCols(Map<String, dynamic>? cfg) {
  final c = _readProductGridColsFromCfg(cfg);
  return c > 0 ? c : 3;
}

String _readPageTransition(Map<String, dynamic>? cfg) {
  final raw = cfg?['pageTransition'] ?? cfg?['page_transition'];
  if (raw == null) return '';
  final s = raw.toString().trim();
  return s.isEmpty ? '' : s;
}

String _readProductGridCardSize(Map<String, dynamic>? cfg) {
  final raw =
      cfg?['tv2ProductGridCardSize'] ?? cfg?['tv2_product_grid_card_size'];
  if (raw == null) return 'normal';
  final t = raw.toString().trim().toLowerCase();
  if (t == 'compact' || t == 'large') return t;
  return 'normal';
}

double _previewProductGridAspect(Map<String, dynamic>? cfg) {
  return switch (_readProductGridCardSize(cfg)) {
    'compact' => 0.82,
    'large' => 1.02,
    _ => 0.92,
  };
}

TvProductGridTypography _readProductGridTypography(Map<String, dynamic>? cfg) {
  return TvProductGridTypography.fromConfig(cfg);
}

Widget _productGridPreviewCells(
  BuildContext context,
  List<ScreenPageItemRow> rows,
  int cols, {
  int maxCells = 12,
  Map<String, dynamic>? pageConfig,
}) {
  final theme = Theme.of(context);
  final count = rows.isEmpty
      ? math.min(maxCells, cols * 2)
      : math.min(rows.length, maxCells);
  const gap = 4.0;
  final aspect = _previewProductGridAspect(pageConfig);
  final cardSize = _readProductGridCardSize(pageConfig);
  final typoCfg = _readProductGridTypography(pageConfig);
  const previewCellW = 72.0;
  final previewCellH = previewCellW / aspect;
  final typo = resolveTvProductGridTypography(
    typography: typoCfg,
    cellWidth: previewCellW,
    cellHeight: previewCellH,
    screenShortSide: 400,
    cardSize: cardSize,
  );
  return GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: cols.clamp(2, 5),
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      childAspectRatio: aspect,
    ),
    itemCount: count,
    itemBuilder: (_, i) {
      final label = i < rows.length ? rows[i].name.ru : '';
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFFAFAFA)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Icon(
                        Icons.lunch_dining_rounded,
                        size: 16,
                        color: _kTv2PreviewRed.withValues(alpha: 0.35),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _kTv2PreviewRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '25',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (typo.priceSize * 0.22).clamp(6.0, 11.0),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 2, 3, 3),
                  child: Text(
                    label.isNotEmpty ? label : 'Товар',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: (typo.nameSize * 0.22).clamp(6.0, 12.0),
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

bool _tv2EditorVideoBgCombo(Map<String, dynamic>? config) {
  final tc = config?['tv2Content'] ?? config?['tv2_content'];
  if (tc is! Map) return false;
  return (tc['mode'] ?? '').toString().toLowerCase().trim() == 'combo';
}

List<String> _tv2EditorRoles(String pageType, Map<String, dynamic>? config) {
  final t = pageType.toLowerCase().trim();
  if (t == 'list') return ['hero', 'list'];
  if (t == 'product_grid') return ['list'];
  if (t == 'four_showcase') return ['list'];
  if (t == 'editorial_showcase') return ['list'];
  if (t == 'two_product_equal' || t == 'two_product_diagonal') {
    return ['left', 'right'];
  }
  if (t == 'pizza_show' || t == 'pizza_grid') return ['list'];
  if (t == 'video_bg') return [];
  return _kRoles;
}

/// Красный акцент ТВ2 (как в `dk_digitial_menu`).
const Color _kTv2PreviewRed = Color(0xFFE4002B);

class _TwoProductPreviewDiagonalClipper extends CustomClipper<Path> {
  const _TwoProductPreviewDiagonalClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width * .56, 0)
    ..lineTo(size.width * .44, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _TwoProductPreviewDiagonalClipper oldClipper) =>
      false;
}

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

class _Tv2ScreenPagesEditorScreenState
    extends State<Tv2ScreenPagesEditorScreen> {
  List<AdminScreenPageRow> _pages = [];
  List<AdminMenuItemRow> _menuItems = [];
  final Map<int, _PageDetail> _detailByPageId = {};
  final Set<int> _expandedPageIds = {};
  final Map<int, ExpansibleController> _expansionControllers = {};
  bool _loading = true;
  bool _savingPageOrder = false;
  String? _error;
  String _newPageType = 'split';
  int? _selectedPageId;

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

  ExpansibleController _expansionControllerFor(int pageId) {
    return _expansionControllers.putIfAbsent(pageId, ExpansibleController.new);
  }

  void _reopenExpandedTile(int pageId) {
    if (!_expandedPageIds.contains(pageId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_expandedPageIds.contains(pageId)) return;
      _expansionControllerFor(pageId).expand();
    });
  }

  void _syncPageListRowFromDetail(int pageId) {
    final d = _detailByPageId[pageId];
    if (d == null) return;
    final i = _pages.indexWhere((p) => p.id == pageId);
    if (i < 0) return;
    setState(() {
      _pages[i] = AdminScreenPageRow(
        id: d.page.id,
        pageType: d.page.pageType,
        sortOrder: d.page.sortOrder,
        itemsCount: d.items.length,
        comboId: d.page.comboId,
        config: d.page.config,
        listTitle: d.page.listTitle,
        secondListTitle: d.page.secondListTitle,
      );
    });
    _reopenExpandedTile(pageId);
  }

  Future<void> _afterPageMutation(int pageId) async {
    await _loadDetail(pageId);
    _syncPageListRowFromDetail(pageId);
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
        _expandedPageIds.removeWhere((id) => !pages.any((p) => p.id == id));
        final alive = _pages.map((p) => p.id).toSet();
        _expansionControllers.removeWhere((id, _) => !alive.contains(id));
        if (_selectedPageId != null &&
            !pages.any((p) => p.id == _selectedPageId)) {
          _selectedPageId = pages.isEmpty ? null : pages.first.id;
        } else if (_selectedPageId == null && pages.isNotEmpty) {
          _selectedPageId = pages.first.id;
        }
        _loading = false;
      });
      for (final id in _expandedPageIds) {
        _reopenExpandedTile(id);
      }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDeletePage(
    AdminScreenPageRow p,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenPageDeleteTitle),
        content: Text(
          l10n.adminScreenPageDeleteConfirm(
            _tv2PageTypeLabel(l10n, p.pageType),
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminScreenPageDeleted)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.adminTv2EditorOrderSaved)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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

  Future<void> _addPage(AppLocalizations l10n, {String? pageType}) async {
    final nextOrder = _pages.isEmpty
        ? 0
        : _pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    try {
      final created = await widget.screensRepo.addScreenPage(
        widget.screenId,
        pageType: pageType ?? _newPageType,
        sortOrder: nextOrder,
      );
      await _reload();
      if (mounted) {
        setState(() => _selectedPageId = created.id);
        unawaited(_loadDetail(created.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminTv2EditorPageAdded)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _showTv2Help(AppLocalizations l10n) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded),
            SizedBox(width: 10),
            Text('Справка по ТВ2'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminTv2EditorSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const TvMediaHintCard(showMixed: true),
                const SizedBox(height: 16),
                Text(
                  l10n.adminTv2UserGuideTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final text in [
                  l10n.adminTv2UserGuide1,
                  l10n.adminTv2UserGuide2,
                  l10n.adminTv2UserGuide3,
                  l10n.adminTv2UserGuide4,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
                  ),
                Text(
                  l10n.adminTv2UserGuidePhotoHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPageDialog(AppLocalizations l10n) async {
    var selectedType = _newPageType;
    final pageType = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminScreenPageTypeLabel),
          content: SizedBox(
            width: 1080,
            child: TvLayoutTypePicker(
              options: tv2PageTypeOptions(l10n),
              selectedId: selectedType,
              hint: l10n.adminTvPageTypePickerHint,
              crossAxisCount: 4,
              onSelected: (value) => setDialogState(() => selectedType = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, selectedType),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.adminScreenPageAdd),
            ),
          ],
        ),
      ),
    );
    if (pageType == null || !mounted) return;
    setState(() => _newPageType = pageType);
    await _addPage(l10n, pageType: pageType);
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
      await _afterPageMutation(pageId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminTv2EditorTitlesSaved)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    if (ok == 0) return;
    await _afterPageMutation(pageId);
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
      await _afterPageMutation(pageId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminTv2EditorItemRemoved)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _reorderPageItems(
    int pageId,
    String role,
    int oldIndex,
    int newIndex,
    AppLocalizations l10n,
  ) async {
    if (!_detailByPageId.containsKey(pageId)) {
      await _loadDetail(pageId);
    }
    final d = _detailByPageId[pageId];
    if (d == null) return;
    var roleItems = d.items.where((e) => e.role == role).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (roleItems.length < 2) return;
    var ni = newIndex;
    if (ni > oldIndex) ni -= 1;
    if (oldIndex < 0 ||
        oldIndex >= roleItems.length ||
        ni < 0 ||
        ni >= roleItems.length) {
      return;
    }
    final moved = roleItems.removeAt(oldIndex);
    roleItems.insert(ni, moved);
    final updates = [
      for (var i = 0; i < roleItems.length; i++)
        {'id': roleItems[i].id, 'sort_order': i},
    ];
    try {
      await widget.screensRepo.reorderScreenPageItems(
        widget.screenId,
        pageId,
        updates,
      );
      await _afterPageMutation(pageId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await _afterPageMutation(pageId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await _afterPageMutation(pageId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _patchPageLayout(
    int pageId,
    Map<String, dynamic> layoutPatch,
  ) async {
    final d = _detailByPageId[pageId];
    final base = Map<String, dynamic>.from(d?.page.config ?? {});
    for (final e in layoutPatch.entries) {
      if (e.value == null) {
        base.remove(e.key);
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
      await _afterPageMutation(pageId);
      if (mounted) {
        final ln = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ln.adminTv2PageLayoutSaved)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await _afterPageMutation(pageId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await _afterPageMutation(pageId);
      if (!mounted) return;
      await _pickItemDialog(pageId, 'hero', l10n);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      await _afterPageMutation(pageId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminTv2EditorItemAdded)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      case 'product_grid':
        return l10n.adminTv2PageTypeProductGrid;
      case 'four_showcase':
        return 'Витрина 4 товара';
      case 'editorial_showcase':
        return 'Красная витрина';
      case 'two_product_equal':
        return 'Два товара — поровну';
      case 'two_product_diagonal':
        return 'Два товара — акция';
      case 'pizza_show':
        return 'Пицца — шоу';
      case 'pizza_grid':
        return 'Пицца — витрина';
      case 'video_bg':
        return l10n.adminTv2PageTypeVideoBg;
      case 'media_only':
        return 'Только видео/фото';
      case 'menu_ribbon':
        return 'Лента меню';
      case 'queue':
        return 'Очередь заказов';
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
    if (_tv2EditorIsProductGrid(pageType) && role == 'list') {
      return l10n.adminTv2EditorRoleProductGridItem;
    }
    if (_tv2EditorIsFourShowcase(pageType) && role == 'list') {
      return 'Товары витрины';
    }
    if (_tv2EditorIsEditorialShowcase(pageType) && role == 'list') {
      return 'Товары красной витрины';
    }
    if (_tv2EditorIsTwoProductShowcase(pageType)) {
      return role == 'left' ? 'Левый товар' : 'Правый товар';
    }
    if (_tv2EditorIsPizzaPage(pageType) && role == 'list') {
      return 'Пицца (все размеры 25/30/35)';
    }
    return _roleLabel(l10n, role);
  }

  Future<void> _pickItemDialog(
    int pageId,
    String role,
    AppLocalizations l10n,
  ) async {
    final isSingleSlot = role == 'hero' || role == 'left' || role == 'right';
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
            final nSel = isSingleSlot ? (heroId != null ? 1 : 0) : selected.length;
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
                          if (isSingleSlot) {
                            final sel = heroId == it.id;
                            return ListTile(
                              leading: Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: sel
                                    ? Theme.of(ctx).colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                it.name.ru,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                it.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                            title: Text(
                              it.name.ru,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              it.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                          if (isSingleSlot && heroId != null) {
                            Navigator.pop(ctx, [heroId!]);
                          } else {
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

  Future<void> _openPreview(AppLocalizations l10n) async {
    try {
      final screens = await widget.screensRepo.fetchScreens();
      AdminScreenRow? screen;
      for (final s in screens) {
        if (s.id == widget.screenId) {
          screen = s;
          break;
        }
      }
      if (screen == null || !mounted) return;
      final previewRepo = context.read<MenuDisplayPreviewRepository>();
      final locale = context.read<LocaleBloc>().state.locale;
      final lang = menuApiLanguageCode(locale.languageCode);
      final body = <String, dynamic>{
        'type': screen.type,
        'name': screen.name,
        'config': screen.config ?? <String, dynamic>{},
        'lang': lang,
        'screen_id': screen.id,
      };
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminTvPreviewPage(
            previewRepo: previewRepo,
            screensRepo: widget.screensRepo,
            requestBody: body,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _buildTv2PageCard(
    int i,
    AppLocalizations l10n, {
    bool detailOnly = false,
  }) {
    final p = _pages[i];
    return _PageCard(
      key: ValueKey<int>(p.id),
      detailOnly: detailOnly,
      reorderListIndex: i,
      pageListRow: p,
      detail: _detailByPageId[p.id],
      expansionController: _expansionControllerFor(p.id),
      onExpansionChanged: (open) {
        setState(() {
          if (open) {
            _expandedPageIds.add(p.id);
          } else {
            _expandedPageIds.remove(p.id);
          }
        });
        if (open) {
          unawaited(_loadDetail(p.id));
        }
      },
      l10n: l10n,
      combosRepo: widget.combosRepo,
      uploadRepo: widget.uploadRepo,
      onExpand: () => _loadDetail(p.id),
      onSaveTitles: (a, b) => _saveTitles(p.id, a, b, l10n),
      onPickItem: (role) => _pickItemDialog(p.id, role, l10n),
      onRemoveItem: (rowId) => _removeItem(p.id, rowId, l10n),
      onReorderItems: (role, oldI, newI) =>
          _reorderPageItems(p.id, role, oldI, newI, l10n),
      onPatchTvVideoBg: (m) => _patchTvVideoBg(p.id, m),
      onPatchPageLayout: (m) => _patchPageLayout(p.id, m),
      onVideoBgPickHero: () => _videoBgPickHero(p.id, l10n),
      onVideoBgApplyCombo: (cid) => _videoBgApplyCombo(p.id, cid, l10n),
      onVideoBgSwitchToMenuMode: () => _videoBgSwitchToMenuMode(p.id),
      onVideoBgSwitchToComboMode: () => _videoBgSwitchToComboMode(p.id),
      onDeletePage: () => _confirmDeletePage(p, l10n),
      roleLabel: (ln, role) => _roleLabelForPageType(ln, p.pageType, role),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTv2EditorTitle),
        actions: [
          IconButton(
            tooltip: 'Справка',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _loading ? null : () => _showTv2Help(l10n),
          ),
          IconButton(
            tooltip: l10n.adminTv2EditorPreviewOnTv,
            icon: const Icon(Icons.live_tv_rounded),
            onPressed: _loading ? null : () => _openPreview(l10n),
          ),
        ],
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
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 840;
                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.adminTv2EditorSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _showAddPageDialog(l10n),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.adminScreenPageAdd),
                        ),
                      ],
                    ),
                  ],
                );

                if (_pages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      header,
                      const SizedBox(height: 24),
                      Text(l10n.adminTv2EditorNoPages),
                    ],
                  );
                }

                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      header,
                      const SizedBox(height: 24),
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
                                _buildTv2PageCard(i, l10n),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final selectedIndex = _pages.indexWhere(
                  (p) => p.id == _selectedPageId,
                );

                return AdminTvMasterDetailLayout(
                  header: header,
                  detailScrollIdentity: _selectedPageId,
                  master: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.adminTv2EditorReorderHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (final p in _pages)
                        AdminTvPageMasterTile(
                          title:
                              '${l10n.adminTv2EditorPageLabel} #${p.id} · ${p.pageType}',
                          subtitle: l10n.adminScreenPageItems(p.itemsCount),
                          selected: p.id == _selectedPageId,
                          onTap: () {
                            setState(() => _selectedPageId = p.id);
                            unawaited(_loadDetail(p.id));
                          },
                          onDelete: () => _confirmDeletePage(p, l10n),
                        ),
                    ],
                  ),
                  detail: selectedIndex < 0
                      ? null
                      : _buildTv2PageCard(
                          selectedIndex,
                          l10n,
                          detailOnly: true,
                        ),
                );
              },
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

  static Color _showcaseColor(Object? raw, Color fallback) {
    var value = raw?.toString().trim() ?? '';
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    return Color(int.tryParse(value, radix: 16) ?? fallback.value);
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

    if (t == 'product_grid') {
      final gridItems = sorted
          .where((e) => e.role.toLowerCase().trim() == 'list')
          .toList();
      final cols = _previewProductGridCols(pageConfig);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminTv2EditorLayoutPreview,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.adminTv2EditorLayoutProductGridHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: _productGridPreviewCells(
                context,
                gridItems,
                cols,
                pageConfig: pageConfig,
              ),
            ),
          ),
        ],
      );
    }

    if (t == 'two_product_equal' || t == 'two_product_diagonal') {
      final leftRows = sorted
          .where((e) => e.role.toLowerCase().trim() == 'left')
          .toList();
      final rightRows = sorted
          .where((e) => e.role.toLowerCase().trim() == 'right')
          .toList();
      final left = leftRows.isEmpty ? null : leftRows.first;
      final right = rightRows.isEmpty ? null : rightRows.first;
      final leftBg = _showcaseColor(
        pageConfig?['twoProductLeftBackground'],
        const Color(0xFF970B21),
      );
      final rightBg = _showcaseColor(
        pageConfig?['twoProductRightBackground'],
        const Color(0xFFE4002B),
      );
      final leftName = _showcaseColor(
        pageConfig?['twoProductLeftNameColor'],
        Colors.white,
      );
      final rightName = _showcaseColor(
        pageConfig?['twoProductRightNameColor'],
        Colors.white,
      );
      final leftPrice = _showcaseColor(
        pageConfig?['twoProductLeftPriceColor'],
        const Color(0xFFFFDD7A),
      );
      final rightPrice = _showcaseColor(
        pageConfig?['twoProductRightPriceColor'],
        const Color(0xFFFFDD7A),
      );
      Widget tile(ScreenPageItemRow? item, Color name, Color price) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood_rounded, size: 34, color: name.withValues(alpha: .78)),
          const SizedBox(height: 4),
          Text(
            item?.name.ru ?? 'Выберите товар',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(color: name, fontWeight: FontWeight.w800),
          ),
          Text(
            item == null ? '' : 'Цена из меню',
            style: theme.textTheme.labelSmall?.copyWith(color: price, fontWeight: FontWeight.w900),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t == 'two_product_equal'
                ? 'Предпросмотр «Два товара — поровну»'
                : 'Предпросмотр «Два товара — акция»',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Товар, фон, цвета и размеры текста настраиваются отдельно; на ТВ они плавно появляются.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: t == 'two_product_equal'
                  ? Row(
                      children: [
                        Expanded(child: ColoredBox(color: leftBg, child: tile(left, leftName, leftPrice))),
                        const VerticalDivider(width: 1, thickness: 1, color: Colors.white54),
                        Expanded(child: ColoredBox(color: rightBg, child: tile(right, rightName, rightPrice))),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: rightBg),
                        ClipPath(
                          clipper: const _TwoProductPreviewDiagonalClipper(),
                          child: ColoredBox(color: leftBg),
                        ),
                        Row(
                          children: [
                            Expanded(child: tile(left, leftName, leftPrice)),
                            Expanded(child: tile(right, rightName, rightPrice)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    if (t == 'four_showcase') {
      final showcaseItems = sorted
          .where((e) => e.role.toLowerCase().trim() == 'list')
          .take(4)
          .toList();
      final bgStart = _showcaseColor(
        pageConfig?['fourShowcaseBackgroundStart'],
        const Color(0xFF140305),
      );
      final bgEnd = _showcaseColor(
        pageConfig?['fourShowcaseBackgroundEnd'],
        const Color(0xFFE4002B),
      );
      final nameColor = _showcaseColor(
        pageConfig?['fourShowcaseNameColor'],
        Colors.white,
      );
      final priceColor = _showcaseColor(
        pageConfig?['fourShowcasePriceColor'],
        Colors.white,
      );
      final priceBg = _showcaseColor(
        pageConfig?['fourShowcasePriceBackground'],
        const Color(0xFFE4002B),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Предпросмотр витрины', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'На экране всегда ровно четыре товара. Смена лишних позиций — слева направо.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(colors: [bgStart, bgEnd]),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: List.generate(4, (index) {
                    final item = index < showcaseItems.length
                        ? showcaseItems[index]
                        : null;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 3 ? 0 : 6),
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  size: 28,
                                  color: nameColor.withValues(alpha: .78),
                                ),
                              ),
                            ),
                            Text(
                              item?.name.ru ?? 'Товар',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: nameColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priceBg,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '25 с.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: priceColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (t == 'editorial_showcase') {
      final showcaseItems = sorted
          .where((e) => e.role.toLowerCase().trim() == 'list')
          .take(6)
          .toList();
      final bgStart = _showcaseColor(
        pageConfig?['editorialBackgroundStart'],
        const Color(0xFFE4002B),
      );
      final bgEnd = _showcaseColor(
        pageConfig?['editorialBackgroundEnd'],
        const Color(0xFFB3001B),
      );
      final nameColor = _showcaseColor(
        pageConfig?['editorialNameColor'],
        const Color(0xFF8B111A),
      );
      final labelBg = _showcaseColor(
        pageConfig?['editorialLabelBackground'],
        const Color(0xFFFFF4E5),
      );
      Widget chip(int index, {bool large = false}) {
        final item = index < showcaseItems.length ? showcaseItems[index] : null;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(large ? 14 : 8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fastfood_rounded, size: large ? 32 : 18, color: nameColor),
                Text(
                  item?.name.ru ?? 'Товар',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: nameColor, fontWeight: FontWeight.w800),
                ),
                Text(
                  '25 с.',
                  style: theme.textTheme.labelSmall?.copyWith(color: nameColor, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Предпросмотр красной витрины', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Главный товар крупный в центре, вокруг — ещё пять позиций. При избытке товаров — плавная смена.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(colors: [bgStart, bgEnd]),
              ),
              child: Stack(
                children: [
                  Positioned(left: 14, top: 16, width: 56, child: chip(1)),
                  Positioned(left: 100, top: 12, width: 46, child: chip(2)),
                  Positioned(right: 12, top: 30, width: 62, child: chip(3)),
                  Positioned(left: 30, bottom: 12, width: 44, child: chip(4)),
                  Positioned(right: 28, bottom: 10, width: 56, child: chip(5)),
                  Positioned(left: 76, right: 76, top: 58, bottom: 4, child: chip(0, large: true)),
                ],
              ),
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
      final isCombo =
          tc is Map &&
          (tc['mode'] ?? '').toString().toLowerCase().trim() == 'combo';
      final heroes = sorted.where((e) => e.role == 'hero').toList();
      final heroLabel = heroes.isEmpty ? null : heroes.first.name.ru;
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
    this.detailOnly = false,
    required this.reorderListIndex,
    required this.pageListRow,
    required this.detail,
    required this.expansionController,
    required this.onExpansionChanged,
    required this.l10n,
    required this.combosRepo,
    required this.uploadRepo,
    required this.onExpand,
    required this.onSaveTitles,
    required this.onPickItem,
    required this.onRemoveItem,
    required this.onReorderItems,
    required this.onPatchTvVideoBg,
    required this.onPatchPageLayout,
    required this.onVideoBgPickHero,
    required this.onVideoBgApplyCombo,
    required this.onVideoBgSwitchToMenuMode,
    required this.onVideoBgSwitchToComboMode,
    required this.onDeletePage,
    required this.roleLabel,
  });

  /// Индекс в [ReorderableListView] для [ReorderableDragStartListener].
  final bool detailOnly;
  final int reorderListIndex;
  final AdminScreenPageRow pageListRow;
  final _PageDetail? detail;
  final ExpansibleController expansionController;
  final ValueChanged<bool> onExpansionChanged;
  final AppLocalizations l10n;
  final CombosAdminRepository combosRepo;
  final UploadRepository uploadRepo;
  final VoidCallback onExpand;
  final Future<void> Function(String listRu, String secondRu) onSaveTitles;
  final Future<void> Function(String role) onPickItem;
  final Future<void> Function(int itemRowId) onRemoveItem;
  final Future<void> Function(String role, int oldIndex, int newIndex)
  onReorderItems;
  final Future<void> Function(Map<String, dynamic> patch) onPatchTvVideoBg;
  final Future<void> Function(Map<String, dynamic> patch) onPatchPageLayout;
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
  final Map<String, dynamic> _pendingLayoutPatch = {};
  bool _layoutDirty = false;
  bool _savingLayout = false;

  Map<String, dynamic> _effectivePageConfig() {
    final base = Map<String, dynamic>.from(
      widget.detail?.page.config ?? widget.pageListRow.config ?? {},
    );
    for (final e in _pendingLayoutPatch.entries) {
      if (e.value == null) {
        base.remove(e.key);
      } else {
        base[e.key] = e.value;
      }
    }
    return base;
  }

  void _mergeLayoutDraft(Map<String, dynamic> patch) {
    setState(() {
      for (final e in patch.entries) {
        if (e.value == null) {
          _pendingLayoutPatch.remove(e.key);
        } else {
          _pendingLayoutPatch[e.key] = e.value;
        }
      }
      _layoutDirty = _pendingLayoutPatch.isNotEmpty;
    });
  }

  Future<void> _savePageLayout() async {
    if (!_layoutDirty || _pendingLayoutPatch.isEmpty || _savingLayout) {
      return;
    }
    setState(() => _savingLayout = true);
    try {
      await widget.onPatchPageLayout(
        Map<String, dynamic>.from(_pendingLayoutPatch),
      );
      if (!mounted) return;
      setState(() {
        _pendingLayoutPatch.clear();
        _layoutDirty = false;
      });
    } finally {
      if (mounted) setState(() => _savingLayout = false);
    }
  }

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
    final listOnly = _tv2EditorIsCatalogPage(p.pageType);
    final productGrid = _tv2EditorIsProductGrid(p.pageType);
    final fourShowcase = _tv2EditorIsFourShowcase(p.pageType);
    final editorialShowcase = _tv2EditorIsEditorialShowcase(p.pageType);
    final twoProductShowcase = _tv2EditorIsTwoProductShowcase(p.pageType);
    final pizzaPage = _tv2EditorIsPizzaPage(p.pageType);
    final videoBg = pt == 'video_bg';
    final pageCfg = _effectivePageConfig();
    final roles = _tv2EditorRoles(p.pageType, pageCfg);

    final subtitleHint = videoBg
        ? l10n.adminTv2EditorPageHintVideoBg
        : pizzaPage
        ? (pt == 'pizza_show'
              ? 'Добавьте все размеры одной пиццы (25/30/35) — на ТВ они склеятся.'
              : 'Сетка пицц: добавьте позиции всех размеров, настройте колонки и цвета.')
        : _tv2EditorIsProductGrid(p.pageType)
        ? l10n.adminTv2EditorPageHintProductGrid
        : fourShowcase
        ? 'На ТВ всегда четыре товара. Добавьте больше четырёх — позиции будут плавно сменяться.'
        : editorialShowcase
        ? 'На ТВ большой главный товар и пять акцентных. Добавьте больше шести — товары будут плавно сменяться.'
        : twoProductShowcase
        ? 'Выберите строго один товар слева и один справа. Каждый появится на экране плавно.'
        : listOnly
        ? l10n.adminTv2EditorPageHintList
        : l10n.adminTv2EditorPageHintSplit;

    final editorBody = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!videoBg) ...[
            TextField(
              controller: _listCtrl,
              decoration: InputDecoration(
                labelText: listOnly
                    ? (_tv2EditorIsProductGrid(p.pageType)
                          ? l10n.adminTv2EditorProductGridTitleRu
                          : fourShowcase
                          ? 'Служебное название страницы (на ТВ не видно)'
                          : editorialShowcase
                          ? 'Служебное название страницы (на ТВ не видно)'
                          : twoProductShowcase
                          ? 'Служебное название страницы (на ТВ не видно)'
                          : pizzaPage
                          ? 'Заголовок страницы пицц'
                          : l10n.adminTv2EditorListGridTitleRu)
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
              onPressed: () =>
                  widget.onSaveTitles(_listCtrl.text, _secondCtrl.text),
              child: Text(l10n.adminTv2EditorSaveTitles),
            ),
            if (productGrid) ...[
              const Divider(height: 24),
              _ProductGridLayoutEditor(
                l10n: l10n,
                config: pageCfg,
                itemCount: items
                    .where((e) => e.role.toLowerCase().trim() == 'list')
                    .length,
                onDraftChanged: _mergeLayoutDraft,
              ),
            ],
            if (fourShowcase) ...[
              const Divider(height: 24),
              _FourProductShowcaseLayoutEditor(
                config: pageCfg,
                itemCount: items
                    .where((e) => e.role.toLowerCase().trim() == 'list')
                    .length,
                onDraftChanged: _mergeLayoutDraft,
              ),
            ],
            if (editorialShowcase) ...[
              const Divider(height: 24),
              _EditorialShowcaseLayoutEditor(
                config: pageCfg,
                itemCount: items
                    .where((e) => e.role.toLowerCase().trim() == 'list')
                    .length,
                onDraftChanged: _mergeLayoutDraft,
              ),
            ],
            if (twoProductShowcase) ...[
              const Divider(height: 24),
              _TwoProductShowcaseLayoutEditor(
                config: pageCfg,
                diagonal: pt == 'two_product_diagonal',
                onDraftChanged: _mergeLayoutDraft,
              ),
            ],
            if (pizzaPage) ...[
              const Divider(height: 24),
              _PizzaTvLayoutEditor(
                pageType: p.pageType,
                config: pageCfg,
                onDraftChanged: _mergeLayoutDraft,
              ),
            ],
            if (!videoBg) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'ptr-${_readPageTransition(pageCfg)}-$_layoutDirty',
                ),
                isExpanded: true,
                initialValue: _readPageTransition(pageCfg),
                decoration: InputDecoration(
                  labelText: l10n.adminTv2PageTransitionPerPage,
                  helperText: l10n.adminTv2PageTransitionPerPageHint,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.adminTv2PageTransitionInherit),
                  ),
                  DropdownMenuItem(
                    value: 'fade',
                    child: Text(l10n.adminTvTransitionFade),
                  ),
                  DropdownMenuItem(
                    value: 'slideUp',
                    child: Text(l10n.adminTvTransitionSlideUp),
                  ),
                  DropdownMenuItem(
                    value: 'slide',
                    child: Text(l10n.adminTvTransitionSlide),
                  ),
                  DropdownMenuItem(
                    value: 'crossFade',
                    child: Text(l10n.adminTvTransitionCrossFade),
                  ),
                  DropdownMenuItem(
                    value: 'scale',
                    child: Text(l10n.adminTvTransitionScale),
                  ),
                  DropdownMenuItem(
                    value: 'none',
                    child: Text(l10n.adminTvTransitionNone),
                  ),
                ],
                onChanged: (v) => _mergeLayoutDraft({
                  'pageTransition': (v == null || v.isEmpty) ? null : v,
                }),
              ),
            ],
            if (_layoutDirty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.adminTv2PageLayoutUnsavedHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _savingLayout ? null : _savePageLayout,
                icon: _savingLayout
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.adminTv2PageLayoutSaveButton),
              ),
            ],
            if (!fourShowcase && !editorialShowcase && !twoProductShowcase) ...[
              const Divider(height: 24),
              _Tv2OptionalBackgroundVideoEditor(
                l10n: l10n,
                config: pageCfg,
                uploadRepo: widget.uploadRepo,
                onPatchTvVideoBg: widget.onPatchTvVideoBg,
              ),
            ],
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
              pageConfig: pageCfg,
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
              pageConfig: pageCfg,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('${_addRole}_${roles.join()}'),
                  isExpanded: true,
                  initialValue: roles.contains(_addRole)
                      ? _addRole
                      : roles.first,
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
              _PageItemsReorderSection(
                items: items,
                roles: roles,
                l10n: l10n,
                roleLabel: widget.roleLabel,
                onRemoveItem: widget.onRemoveItem,
                onReorderItems: widget.onReorderItems,
              ),
          ],
        ],
      ),
    );

    if (widget.detailOnly) {
      return Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.adminTv2EditorPageLabel} #${p.id} · ${p.pageType}',
                      style: Theme.of(context).textTheme.titleMedium,
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                subtitleHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            editorBody,
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        controller: widget.expansionController,
        onExpansionChanged: widget.onExpansionChanged,
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
        children: [editorBody],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
        Text(
          l10n.adminTv2VideoBgContentSource,
          style: theme.textTheme.titleSmall,
        ),
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
                onSelected: (v) =>
                    widget.onPatchTvVideoBg({'showDescription': v}),
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
              initialValue:
                  _comboPick != null && _combos.any((c) => c.id == _comboPick)
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
                onSelected: (v) =>
                    widget.onPatchTvVideoBg({'showDescription': v}),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowPrice),
                selected: _vgBool('showPrice', 'show_price'),
                onSelected: (v) => widget.onPatchTvVideoBg({'showPrice': v}),
              ),
              FilterChip(
                label: Text(l10n.adminTv2VideoBgShowComboComposition),
                selected: _vgBool('showComboParts', 'show_combo_parts'),
                onSelected: (v) =>
                    widget.onPatchTvVideoBg({'showComboParts': v}),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Список товаров на странице: перетаскивание внутри роли (≡ удерживать).
class _PageItemsReorderSection extends StatelessWidget {
  const _PageItemsReorderSection({
    required this.items,
    required this.roles,
    required this.l10n,
    required this.roleLabel,
    required this.onRemoveItem,
    required this.onReorderItems,
  });

  final List<ScreenPageItemRow> items;
  final List<String> roles;
  final AppLocalizations l10n;
  final String Function(AppLocalizations l10n, String role) roleLabel;
  final Future<void> Function(int itemRowId) onRemoveItem;
  final Future<void> Function(String role, int oldIndex, int newIndex)
  onReorderItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byRole = <String, List<ScreenPageItemRow>>{};
    for (final it in items) {
      byRole.putIfAbsent(it.role, () => []).add(it);
    }
    for (final list in byRole.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final orderedRoles = [
      for (final r in roles)
        if ((byRole[r] ?? []).isNotEmpty) r,
      for (final r in byRole.keys)
        if (!roles.contains(r)) r,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final role in orderedRoles) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              roleLabel(l10n, role),
              style: theme.textTheme.labelLarge,
            ),
          ),
          _RoleItemsList(
            role: role,
            items: byRole[role]!,
            l10n: l10n,
            onRemoveItem: onRemoveItem,
            onReorderItems: onReorderItems,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RoleItemsList extends StatelessWidget {
  const _RoleItemsList({
    required this.role,
    required this.items,
    required this.l10n,
    required this.onRemoveItem,
    required this.onReorderItems,
  });

  final String role;
  final List<ScreenPageItemRow> items;
  final AppLocalizations l10n;
  final Future<void> Function(int itemRowId) onRemoveItem;
  final Future<void> Function(String role, int oldIndex, int newIndex)
  onReorderItems;

  @override
  Widget build(BuildContext context) {
    if (items.length < 2) {
      final it = items.first;
      return ListTile(
        title: Text(it.name.ru),
        subtitle: Text(
          it.menuItemId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => onRemoveItem(it.id),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminTv2EditorItemsReorderHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) =>
              onReorderItems(role, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final it = items[index];
            return ListTile(
              key: ValueKey<int>(it.id),
              leading: ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              title: Text(
                it.name.ru,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                it.menuItemId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => onRemoveItem(it.id),
              ),
            );
          },
        ),
      ],
    );
  }
}
/// Конструктор сетки `product_grid`: свайп влево/вправо меняет число колонок (2–5).
class _ProductGridLayoutEditor extends StatefulWidget {
  const _ProductGridLayoutEditor({
    required this.l10n,
    required this.config,
    required this.itemCount,
    required this.onDraftChanged,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? config;
  final int itemCount;
  final void Function(Map<String, dynamic> patch) onDraftChanged;

  @override
  State<_ProductGridLayoutEditor> createState() =>
      _ProductGridLayoutEditorState();
}

class _ProductGridLayoutEditorState extends State<_ProductGridLayoutEditor> {
  late int _cols;
  late String _cardSize;
  late TvProductGridSizeMode _nameMode;
  late TvProductGridSizeMode _priceMode;
  late double _nameSize;
  late double _priceSize;
  late double _textScale;
  double _dragAccum = 0;

  @override
  void initState() {
    super.initState();
    _syncFromConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _ProductGridLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _syncFromConfig(widget.config);
    }
  }

  void _syncFromConfig(Map<String, dynamic>? cfg) {
    _cols = _readProductGridColsFromCfg(cfg);
    _cardSize = _readProductGridCardSize(cfg);
    final t = _readProductGridTypography(cfg);
    _nameMode = t.nameSizeMode;
    _priceMode = t.priceSizeMode;
    _nameSize = t.nameSize ?? 26;
    _priceSize = t.priceSize ?? 24;
    _textScale = t.textScale;
  }

  int get _displayCols =>
      _cols > 0 ? _cols : _previewProductGridCols(widget.config);

  void _emitDraft() {
    widget.onDraftChanged({
      'tv2ProductGridColumns': (_cols >= 2 && _cols <= 5) ? _cols : null,
      'tv2ProductGridCardSize': _cardSize,
      'tv2ProductGridNameSizeMode': _nameMode == TvProductGridSizeMode.auto
          ? 'auto'
          : 'manual',
      'tv2ProductGridNameSize': _nameMode == TvProductGridSizeMode.manual
          ? _nameSize.round()
          : null,
      'tv2ProductGridPriceSizeMode': _priceMode == TvProductGridSizeMode.auto
          ? 'auto'
          : 'manual',
      'tv2ProductGridPriceSize': _priceMode == TvProductGridSizeMode.manual
          ? _priceSize.round()
          : null,
      'tv2ProductGridTextScale': _textScale == 1.0 ? null : _textScale,
    });
  }

  void _commitCols(int cols) {
    setState(() => _cols = cols);
    _emitDraft();
  }

  void _bumpCols(int delta) {
    var next = _cols <= 0 ? 3 : _cols;
    next = (next + delta).clamp(2, 5);
    _commitCols(next);
  }

  void _commitCardSize(String size) {
    setState(() => _cardSize = size);
    _emitDraft();
  }

  void _commitTypography() {
    _emitDraft();
  }

  String _cardSizeLabel(AppLocalizations l10n, String size) {
    return switch (size) {
      'compact' => l10n.adminTv2ProductGridCardSizeCompact,
      'large' => l10n.adminTv2ProductGridCardSizeLarge,
      _ => l10n.adminTv2ProductGridCardSizeNormal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cols = _displayCols;
    final label = _cols <= 0
        ? l10n.adminTv2ProductGridColsAuto(cols)
        : l10n.adminTv2ProductGridColsFixed(cols);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminTv2ProductGridLayoutTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.adminTv2ProductGridDragHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.adminTv2ProductGridCardSizeLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.adminTv2ProductGridCardSizeHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'compact',
              label: Text(l10n.adminTv2ProductGridCardSizeCompact),
            ),
            ButtonSegment(
              value: 'normal',
              label: Text(l10n.adminTv2ProductGridCardSizeNormal),
            ),
            ButtonSegment(
              value: 'large',
              label: Text(l10n.adminTv2ProductGridCardSizeLarge),
            ),
          ],
          selected: {_cardSize},
          onSelectionChanged: (s) => _commitCardSize(s.first),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _cardSizeLabel(l10n, _cardSize),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.adminTv2ProductGridTypographyTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.adminTv2ProductGridTypographyHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.adminTv2ProductGridNameSizeLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SegmentedButton<TvProductGridSizeMode>(
          segments: [
            ButtonSegment(
              value: TvProductGridSizeMode.auto,
              label: Text(l10n.adminTv2ProductGridSizeAuto),
            ),
            ButtonSegment(
              value: TvProductGridSizeMode.manual,
              label: Text(l10n.adminTv2ProductGridSizeManual),
            ),
          ],
          selected: {_nameMode},
          onSelectionChanged: (s) {
            setState(() => _nameMode = s.first);
            _commitTypography();
          },
        ),
        if (_nameMode == TvProductGridSizeMode.manual) ...[
          Slider(
            value: _nameSize,
            min: 14,
            max: 48,
            divisions: 34,
            label: '${_nameSize.round()}',
            onChanged: (v) => setState(() => _nameSize = v),
            onChangeEnd: (_) => _commitTypography(),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.adminTv2ProductGridPriceSizeLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SegmentedButton<TvProductGridSizeMode>(
          segments: [
            ButtonSegment(
              value: TvProductGridSizeMode.auto,
              label: Text(l10n.adminTv2ProductGridSizeAuto),
            ),
            ButtonSegment(
              value: TvProductGridSizeMode.manual,
              label: Text(l10n.adminTv2ProductGridSizeManual),
            ),
          ],
          selected: {_priceMode},
          onSelectionChanged: (s) {
            setState(() => _priceMode = s.first);
            _commitTypography();
          },
        ),
        if (_priceMode == TvProductGridSizeMode.manual) ...[
          Slider(
            value: _priceSize,
            min: 12,
            max: 44,
            divisions: 32,
            label: '${_priceSize.round()}',
            onChanged: (v) => setState(() => _priceSize = v),
            onChangeEnd: (_) => _commitTypography(),
          ),
        ],
        if (_nameMode == TvProductGridSizeMode.auto &&
            _priceMode == TvProductGridSizeMode.auto) ...[
          const SizedBox(height: 4),
          Text(
            l10n.adminTv2ProductGridTextScaleLabel,
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _textScale,
            min: 0.75,
            max: 1.35,
            divisions: 12,
            label: _textScale.toStringAsFixed(2),
            onChanged: (v) => setState(() => _textScale = v),
            onChangeEnd: (_) => _commitTypography(),
          ),
          Text(
            l10n.adminTv2ProductGridTextScaleHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onHorizontalDragUpdate: (d) {
            _dragAccum += d.delta.dx;
            if (_dragAccum.abs() < 28) return;
            final step = _dragAccum > 0 ? 1 : -1;
            _dragAccum = 0;
            var base = _cols <= 0 ? 3 : _cols;
            base = (base + step).clamp(2, 5);
            setState(() => _cols = base);
          },
          onHorizontalDragEnd: (_) {
            _dragAccum = 0;
            final commit = _cols <= 0 ? 3 : _cols;
            _commitCols(commit);
          },
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 36),
                    child: _productGridPreviewCells(
                      context,
                      const [],
                      cols,
                      pageConfig: {
                        ...?widget.config,
                        'tv2ProductGridCardSize': _cardSize,
                      },
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Center(
                      child: Material(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swipe_rounded,
                                size: 18,
                                color: scheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l10n.adminTv2ProductGridColsLess,
              onPressed: () => _bumpCols(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Text(label, style: theme.textTheme.bodyMedium),
            IconButton(
              tooltip: l10n.adminTv2ProductGridColsMore,
              onPressed: () => _bumpCols(1),
              icon: const Icon(Icons.add_rounded),
            ),
            TextButton(
              onPressed: () => _commitCols(0),
              child: Text(l10n.adminScreenColsAuto),
            ),
          ],
        ),
      ],
    );
  }
}

/// Конструктор отдельной витрины: четыре товара остаются на экране постоянно.
class _FourProductShowcaseLayoutEditor extends StatefulWidget {
  const _FourProductShowcaseLayoutEditor({
    required this.config,
    required this.itemCount,
    required this.onDraftChanged,
  });

  final Map<String, dynamic>? config;
  final int itemCount;
  final void Function(Map<String, dynamic> patch) onDraftChanged;

  @override
  State<_FourProductShowcaseLayoutEditor> createState() =>
      _FourProductShowcaseLayoutEditorState();
}
class _FourProductShowcaseLayoutEditorState
    extends State<_FourProductShowcaseLayoutEditor> {
  late TextEditingController _backgroundStart;
  late TextEditingController _backgroundEnd;
  late TextEditingController _logoColor;
  late TextEditingController _nameColor;
  late TextEditingController _priceColor;
  late TextEditingController _priceBackground;
  late bool _showLogo;
  late String _font;
  late double _photoScale;
  late double _nameScale;
  late double _priceScale;
  late double _holdSec;
  late double _transitionSec;

  @override
  void initState() {
    super.initState();
    _backgroundStart = TextEditingController();
    _backgroundEnd = TextEditingController();
    _logoColor = TextEditingController();
    _nameColor = TextEditingController();
    _priceColor = TextEditingController();
    _priceBackground = TextEditingController();
    _syncFromConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _FourProductShowcaseLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _syncFromConfig(widget.config);
  }

  @override
  void dispose() {
    _backgroundStart.dispose();
    _backgroundEnd.dispose();
    _logoColor.dispose();
    _nameColor.dispose();
    _priceColor.dispose();
    _priceBackground.dispose();
    super.dispose();
  }

  String _hex(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return fallback;
    return value.startsWith('#') ? value : '#$value';
  }

  double _double(Object? raw, double fallback) {
    return raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  bool _bool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    final value = raw?.toString().trim().toLowerCase();
    if (value == 'false' || value == '0') return false;
    if (value == 'true' || value == '1') return true;
    return fallback;
  }

  void _syncFromConfig(Map<String, dynamic>? config) {
    final c = config ?? const <String, dynamic>{};
    _backgroundStart.text = _hex(c['fourShowcaseBackgroundStart'], '#140305');
    _backgroundEnd.text = _hex(c['fourShowcaseBackgroundEnd'], '#E4002B');
    _logoColor.text = _hex(c['fourShowcaseLogoColor'], '#FFFFFF');
    _nameColor.text = _hex(c['fourShowcaseNameColor'], '#FFFFFF');
    _priceColor.text = _hex(c['fourShowcasePriceColor'], '#FFFFFF');
    _priceBackground.text =
        _hex(c['fourShowcasePriceBackground'], '#E4002B');
    _showLogo = _bool(c['fourShowcaseShowLogo'], true);
    _font = c['fourShowcaseFont']?.toString().trim() == 'montserrat'
        ? 'montserrat'
        : 'oswald';
    _photoScale = _double(c['fourShowcasePhotoScale'], 1).clamp(.65, 1.45);
    _nameScale = _double(c['fourShowcaseNameScale'], 1).clamp(.65, 1.5);
    _priceScale = _double(c['fourShowcasePriceScale'], 1).clamp(.65, 1.5);
    _holdSec = (_double(c['fourShowcaseHoldMs'], 5000) / 1000).clamp(2, 20);
    _transitionSec =
        (_double(c['fourShowcaseTransitionMs'], 650) / 1000).clamp(.25, 2);
  }

  void _emit() {
    widget.onDraftChanged({
      'fourShowcaseBackgroundStart': _hex(_backgroundStart.text, '#140305'),
      'fourShowcaseBackgroundEnd': _hex(_backgroundEnd.text, '#E4002B'),
      'fourShowcaseLogoColor': _hex(_logoColor.text, '#FFFFFF'),
      'fourShowcaseNameColor': _hex(_nameColor.text, '#FFFFFF'),
      'fourShowcasePriceColor': _hex(_priceColor.text, '#FFFFFF'),
      'fourShowcasePriceBackground': _hex(_priceBackground.text, '#E4002B'),
      'fourShowcaseShowLogo': _showLogo,
      'fourShowcaseFont': _font,
      'fourShowcasePhotoScale': _photoScale,
      'fourShowcaseNameScale': _nameScale,
      'fourShowcasePriceScale': _priceScale,
      'fourShowcaseHoldMs': (_holdSec * 1000).round(),
      'fourShowcaseTransitionMs': (_transitionSec * 1000).round(),
    });
  }

  Widget _colorField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: '#E4002B',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _emit(),
      ),
    );
  }

  Widget _scaleSlider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: (_) => _emit(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Конструктор «4 товара»', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          widget.itemCount < 4
              ? 'Добавьте ещё ${4 - widget.itemCount} товар(а): на витрине всегда четыре места.'
              : widget.itemCount == 4
              ? 'Ровно 4 товара — витрина будет без движения.'
              : 'Товаров: ${widget.itemCount}. Каждые ${_holdSec.toStringAsFixed(0)} с крайний слева уходит, новый входит справа.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _colorField(_backgroundStart, 'Начало фона'),
        _colorField(_backgroundEnd, 'Конец фона'),
        _colorField(_nameColor, 'Цвет названия'),
        _colorField(_priceColor, 'Цвет цены'),
        _colorField(_priceBackground, 'Фон цены'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Показывать логотип DK'),
          value: _showLogo,
          onChanged: (value) {
            setState(() => _showLogo = value);
            _emit();
          },
        ),
        if (_showLogo) _colorField(_logoColor, 'Цвет логотипа'),
        const SizedBox(height: 4),
        Text('Шрифт', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'oswald', label: Text('Oswald')),
            ButtonSegment(value: 'montserrat', label: Text('Montserrat')),
          ],
          selected: {_font},
          onSelectionChanged: (value) {
            setState(() => _font = value.first);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _scaleSlider(
          context: context,
          label: 'Размер фото PNG',
          value: _photoScale,
          min: .65,
          max: 1.45,
          divisions: 16,
          onChanged: (value) => setState(() => _photoScale = value),
        ),
        _scaleSlider(
          context: context,
          label: 'Размер названия',
          value: _nameScale,
          min: .65,
          max: 1.5,
          divisions: 17,
          onChanged: (value) => setState(() => _nameScale = value),
        ),
        _scaleSlider(
          context: context,
          label: 'Размер цены',
          value: _priceScale,
          min: .65,
          max: 1.5,
          divisions: 17,
          onChanged: (value) => setState(() => _priceScale = value),
        ),
        _scaleSlider(
          context: context,
          label: 'Пауза между сменами (сек.)',
          value: _holdSec,
          min: 2,
          max: 20,
          divisions: 18,
          onChanged: (value) => setState(() => _holdSec = value),
        ),
        _scaleSlider(
          context: context,
          label: 'Длительность сдвига (сек.)',
          value: _transitionSec,
          min: .25,
          max: 2,
          divisions: 14,
          onChanged: (value) => setState(() => _transitionSec = value),
        ),
      ],
    );
  }
}
/// Конструктор красной «журнальной» витрины: главный товар + пять акцентных.
class _EditorialShowcaseLayoutEditor extends StatefulWidget {
  const _EditorialShowcaseLayoutEditor({
    required this.config,
    required this.itemCount,
    required this.onDraftChanged,
  });

  final Map<String, dynamic>? config;
  final int itemCount;
  final void Function(Map<String, dynamic> patch) onDraftChanged;

  @override
  State<_EditorialShowcaseLayoutEditor> createState() =>
      _EditorialShowcaseLayoutEditorState();
}

class _EditorialShowcaseLayoutEditorState
    extends State<_EditorialShowcaseLayoutEditor> {
  late TextEditingController _backgroundStart;
  late TextEditingController _backgroundEnd;
  late TextEditingController _logoColor;
  late TextEditingController _nameColor;
  late TextEditingController _priceColor;
  late TextEditingController _labelBackground;
  late bool _showLogo;
  late String _font;
  late double _mainPhotoScale;
  late double _tilePhotoScale;
  late double _nameScale;
  late double _priceScale;
  late double _holdSec;
  late double _transitionSec;

  @override
  void initState() {
    super.initState();
    _backgroundStart = TextEditingController();
    _backgroundEnd = TextEditingController();
    _logoColor = TextEditingController();
    _nameColor = TextEditingController();
    _priceColor = TextEditingController();
    _labelBackground = TextEditingController();
    _syncFromConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _EditorialShowcaseLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _syncFromConfig(widget.config);
  }

  @override
  void dispose() {
    _backgroundStart.dispose();
    _backgroundEnd.dispose();
    _logoColor.dispose();
    _nameColor.dispose();
    _priceColor.dispose();
    _labelBackground.dispose();
    super.dispose();
  }

  String _hex(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return fallback;
    return value.startsWith('#') ? value : '#$value';
  }

  double _double(Object? raw, double fallback) => raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString() ?? '') ?? fallback;

  bool _bool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    final value = raw?.toString().trim().toLowerCase();
    if (value == 'false' || value == '0') return false;
    if (value == 'true' || value == '1') return true;
    return fallback;
  }

  void _syncFromConfig(Map<String, dynamic>? config) {
    final c = config ?? const <String, dynamic>{};
    _backgroundStart.text = _hex(c['editorialBackgroundStart'], '#E4002B');
    _backgroundEnd.text = _hex(c['editorialBackgroundEnd'], '#B3001B');
    _logoColor.text = _hex(c['editorialLogoColor'], '#FFF4E5');
    _nameColor.text = _hex(c['editorialNameColor'], '#8B111A');
    _priceColor.text = _hex(c['editorialPriceColor'], '#8B111A');
    _labelBackground.text = _hex(c['editorialLabelBackground'], '#FFF4E5');
    _showLogo = _bool(c['editorialShowLogo'], true);
    _font = c['editorialFont']?.toString().trim() == 'montserrat'
        ? 'montserrat'
        : 'oswald';
    _mainPhotoScale =
        _double(c['editorialMainPhotoScale'], 1).clamp(.65, 1.5);
    _tilePhotoScale =
        _double(c['editorialTilePhotoScale'], 1).clamp(.65, 1.5);
    _nameScale = _double(c['editorialNameScale'], 1).clamp(.65, 1.5);
    _priceScale = _double(c['editorialPriceScale'], 1).clamp(.65, 1.5);
    _holdSec = (_double(c['editorialHoldMs'], 5000) / 1000).clamp(2, 20);
    _transitionSec =
        (_double(c['editorialTransitionMs'], 650) / 1000).clamp(.25, 2);
  }

  void _emit() => widget.onDraftChanged({
    'editorialBackgroundStart': _hex(_backgroundStart.text, '#E4002B'),
    'editorialBackgroundEnd': _hex(_backgroundEnd.text, '#B3001B'),
    'editorialLogoColor': _hex(_logoColor.text, '#FFF4E5'),
    'editorialNameColor': _hex(_nameColor.text, '#8B111A'),
    'editorialPriceColor': _hex(_priceColor.text, '#8B111A'),
    'editorialLabelBackground': _hex(_labelBackground.text, '#FFF4E5'),
    'editorialShowLogo': _showLogo,
    'editorialFont': _font,
    'editorialMainPhotoScale': _mainPhotoScale,
    'editorialTilePhotoScale': _tilePhotoScale,
    'editorialNameScale': _nameScale,
    'editorialPriceScale': _priceScale,
    'editorialHoldMs': (_holdSec * 1000).round(),
    'editorialTransitionMs': (_transitionSec * 1000).round(),
  });

  Widget _colorField(TextEditingController controller, String label) =>
      AdminColorPickerField(
        label: label,
        value: controller.text,
        compact: true,
        onChanged: (value) {
          setState(() => controller.text = value);
          _emit();
        },
      );

  Widget _slider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: (_) => _emit(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countText = widget.itemCount == 0
        ? 'Добавьте товары: центральный товар и пять акцентных мест.'
        : widget.itemCount == 1
        ? 'Добавьте ещё товары: центральная позиция начнёт сменяться от двух товаров.'
        : 'Товаров: ${widget.itemCount}. Каждые ${_holdSec.toStringAsFixed(0)} с центральный товар и витрина плавно сменяются.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Конструктор «Красная витрина»', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(countText, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _colorField(_backgroundStart, 'Начало красного фона'),
        _colorField(_backgroundEnd, 'Конец красного фона'),
        _colorField(_nameColor, 'Цвет названия'),
        _colorField(_priceColor, 'Цвет цены'),
        _colorField(_labelBackground, 'Фон плашки названия и цены'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Показывать логотип DK'),
          value: _showLogo,
          onChanged: (value) {
            setState(() => _showLogo = value);
            _emit();
          },
        ),
        if (_showLogo) _colorField(_logoColor, 'Цвет логотипа'),
        const SizedBox(height: 4),
        Text('Шрифт', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'oswald', label: Text('Oswald')),
            ButtonSegment(value: 'montserrat', label: Text('Montserrat')),
          ],
          selected: {_font},
          onSelectionChanged: (value) {
            setState(() => _font = value.first);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _slider(context: context, label: 'Размер главного фото', value: _mainPhotoScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _mainPhotoScale = value)),
        _slider(context: context, label: 'Размер остальных фото', value: _tilePhotoScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _tilePhotoScale = value)),
        _slider(context: context, label: 'Размер названий', value: _nameScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _nameScale = value)),
        _slider(context: context, label: 'Размер цен', value: _priceScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _priceScale = value)),
        _slider(context: context, label: 'Пауза между сменами (сек.)', value: _holdSec, min: 2, max: 20, divisions: 18, onChanged: (value) => setState(() => _holdSec = value)),
        _slider(context: context, label: 'Длительность анимации (сек.)', value: _transitionSec, min: .25, max: 2, divisions: 14, onChanged: (value) => setState(() => _transitionSec = value)),
      ],
    );
  }
}

/// Конструктор страниц с двумя фиксированными товарами.
class _TwoProductShowcaseLayoutEditor extends StatefulWidget {
  const _TwoProductShowcaseLayoutEditor({
    required this.config,
    required this.diagonal,
    required this.onDraftChanged,
  });

  final Map<String, dynamic>? config;
  final bool diagonal;
  final void Function(Map<String, dynamic> patch) onDraftChanged;

  @override
  State<_TwoProductShowcaseLayoutEditor> createState() =>
      _TwoProductShowcaseLayoutEditorState();
}

class _TwoProductShowcaseLayoutEditorState
    extends State<_TwoProductShowcaseLayoutEditor> {
  late TextEditingController _leftBackground;
  late TextEditingController _rightBackground;
  late TextEditingController _logoColor;
  late TextEditingController _leftNameColor;
  late TextEditingController _rightNameColor;
  late TextEditingController _leftPriceColor;
  late TextEditingController _rightPriceColor;
  late bool _showLogo;
  late String _font;
  late double _photoScale;
  late double _nameScale;
  late double _priceScale;
  late double _motionSec;

  @override
  void initState() {
    super.initState();
    _leftBackground = TextEditingController();
    _rightBackground = TextEditingController();
    _logoColor = TextEditingController();
    _leftNameColor = TextEditingController();
    _rightNameColor = TextEditingController();
    _leftPriceColor = TextEditingController();
    _rightPriceColor = TextEditingController();
    _sync(widget.config);
  }

  @override
  void didUpdateWidget(covariant _TwoProductShowcaseLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _sync(widget.config);
  }

  @override
  void dispose() {
    _leftBackground.dispose();
    _rightBackground.dispose();
    _logoColor.dispose();
    _leftNameColor.dispose();
    _rightNameColor.dispose();
    _leftPriceColor.dispose();
    _rightPriceColor.dispose();
    super.dispose();
  }

  String _hex(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return fallback;
    return value.startsWith('#') ? value : '#$value';
  }

  double _double(Object? raw, double fallback) => raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString() ?? '') ?? fallback;

  bool _bool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    final value = raw?.toString().trim().toLowerCase();
    if (value == 'false' || value == '0') return false;
    if (value == 'true' || value == '1') return true;
    return fallback;
  }

  void _sync(Map<String, dynamic>? config) {
    final c = config ?? const <String, dynamic>{};
    _leftBackground.text = _hex(c['twoProductLeftBackground'], '#970B21');
    _rightBackground.text = _hex(c['twoProductRightBackground'], '#E4002B');
    _logoColor.text = _hex(c['twoProductLogoColor'], '#FFFFFF');
    _leftNameColor.text = _hex(c['twoProductLeftNameColor'], '#FFFFFF');
    _rightNameColor.text = _hex(c['twoProductRightNameColor'], '#FFFFFF');
    _leftPriceColor.text = _hex(c['twoProductLeftPriceColor'], '#FFDD7A');
    _rightPriceColor.text = _hex(c['twoProductRightPriceColor'], '#FFDD7A');
    _showLogo = _bool(c['twoProductShowLogo'], true);
    _font = c['twoProductFont']?.toString().trim() == 'montserrat'
        ? 'montserrat'
        : 'oswald';
    _photoScale = _double(c['twoProductPhotoScale'], 1).clamp(.65, 1.5);
    _nameScale = _double(c['twoProductNameScale'], 1).clamp(.65, 1.5);
    _priceScale = _double(c['twoProductPriceScale'], 1).clamp(.65, 1.5);
    _motionSec =
        (_double(c['twoProductMotionMs'], 650) / 1000).clamp(.25, 2);
  }

  void _emit() => widget.onDraftChanged({
    'twoProductLeftBackground': _hex(_leftBackground.text, '#970B21'),
    'twoProductRightBackground': _hex(_rightBackground.text, '#E4002B'),
    'twoProductLogoColor': _hex(_logoColor.text, '#FFFFFF'),
    'twoProductLeftNameColor': _hex(_leftNameColor.text, '#FFFFFF'),
    'twoProductRightNameColor': _hex(_rightNameColor.text, '#FFFFFF'),
    'twoProductLeftPriceColor': _hex(_leftPriceColor.text, '#FFDD7A'),
    'twoProductRightPriceColor': _hex(_rightPriceColor.text, '#FFDD7A'),
    'twoProductShowLogo': _showLogo,
    'twoProductFont': _font,
    'twoProductPhotoScale': _photoScale,
    'twoProductNameScale': _nameScale,
    'twoProductPriceScale': _priceScale,
    'twoProductMotionMs': (_motionSec * 1000).round(),
  });

  Widget _colorField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: '#E4002B',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => _emit(),
    ),
  );

  Widget _slider({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.labelLarge),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: (_) => _emit(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.diagonal
              ? 'Конструктор «Два товара — акция»'
              : 'Конструктор «Два товара — поровну»',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Ниже — оформление. Сами товары выберите в секции «Товары страницы»: один левый и один правый.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _colorField(_leftBackground, 'Фон слева'),
        _colorField(_rightBackground, 'Фон справа'),
        _colorField(_leftNameColor, 'Цвет названия слева'),
        _colorField(_rightNameColor, 'Цвет названия справа'),
        _colorField(_leftPriceColor, 'Цвет цены слева'),
        _colorField(_rightPriceColor, 'Цвет цены справа'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Показывать логотип DK'),
          value: _showLogo,
          onChanged: (value) {
            setState(() => _showLogo = value);
            _emit();
          },
        ),
        if (_showLogo) _colorField(_logoColor, 'Цвет логотипа'),
        const SizedBox(height: 4),
        Text('Шрифт', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'oswald', label: Text('Oswald')),
            ButtonSegment(value: 'montserrat', label: Text('Montserrat')),
          ],
          selected: {_font},
          onSelectionChanged: (value) {
            setState(() => _font = value.first);
            _emit();
          },
        ),
        const SizedBox(height: 12),
        _slider(context: context, label: 'Размер фото PNG', value: _photoScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _photoScale = value)),
        _slider(context: context, label: 'Размер названий', value: _nameScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _nameScale = value)),
        _slider(context: context, label: 'Размер цен', value: _priceScale, min: .65, max: 1.5, divisions: 17, onChanged: (value) => setState(() => _priceScale = value)),
        _slider(context: context, label: 'Длительность появления (сек.)', value: _motionSec, min: .25, max: 2, divisions: 14, onChanged: (value) => setState(() => _motionSec = value)),
      ],
    );
  }
}

/// Конструктор страниц пиццы: цвета, масштаб, анимация, «Можете забирать».
class _PizzaTvLayoutEditor extends StatefulWidget {
  const _PizzaTvLayoutEditor({
    required this.pageType,
    required this.config,
    required this.onDraftChanged,
  });

  final String pageType;
  final Map<String, dynamic>? config;
  final void Function(Map<String, dynamic> patch) onDraftChanged;

  @override
  State<_PizzaTvLayoutEditor> createState() => _PizzaTvLayoutEditorState();
}

class _PizzaTvLayoutEditorState extends State<_PizzaTvLayoutEditor> {
  late double _photoScale;
  late double _nameFontScale;
  late double _priceFontScale;
  late double _holdSec;
  late double _transitSec;
  late double _spinRpm;
  late int _gridCols;
  late bool _announceReady;
  late TextEditingController _bgColor;
  late TextEditingController _nameColor;
  late TextEditingController _priceColor;

  bool get _isShow => widget.pageType.toLowerCase().trim() == 'pizza_show';

  @override
  void initState() {
    super.initState();
    _bgColor = TextEditingController();
    _nameColor = TextEditingController();
    _priceColor = TextEditingController();
    _syncFromConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _PizzaTvLayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _syncFromConfig(widget.config);
    }
  }

  @override
  void dispose() {
    _bgColor.dispose();
    _nameColor.dispose();
    _priceColor.dispose();
    super.dispose();
  }

  String _hex(Object? v, String fb) {
    final t = (v ?? '').toString().trim();
    if (t.isEmpty) return fb;
    return t.startsWith('#') ? t : '#$t';
  }

  double _dbl(Object? v, double fb) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fb;
  }

  int _int(Object? v, int fb) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fb;
  }

  bool _bool(Object? v, bool fb) {
    if (v == null) return fb;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == '0' || s == 'false' || s == 'no' || s == 'off') return false;
    if (s == '1' || s == 'true' || s == 'yes' || s == 'on') return true;
    return fb;
  }

  void _syncFromConfig(Map<String, dynamic>? cfg) {
    final c = cfg ?? const <String, dynamic>{};
    _photoScale =
        _dbl(c['pizzaPhotoScale'] ?? c['pizza_photo_scale'], 1).clamp(0.6, 2.2);
    _nameFontScale = _dbl(c['pizzaNameFontScale'] ?? c['pizza_name_font_scale'], 1)
        .clamp(0.6, 2);
    _priceFontScale =
        _dbl(c['pizzaPriceFontScale'] ?? c['pizza_price_font_scale'], 1)
            .clamp(0.6, 2);
    _holdSec =
        (_dbl(c['pizzaHoldMs'] ?? c['pizza_hold_ms'], 5000) / 1000).clamp(2, 15);
    _transitSec =
        (_dbl(c['pizzaTransitMs'] ?? c['pizza_transit_ms'], 1400) / 1000)
            .clamp(0.6, 4);
    _spinRpm = _dbl(c['pizzaSpinRpm'] ?? c['pizza_spin_rpm'], 0.35).clamp(0, 2);
    _gridCols =
        _int(c['pizzaGridColumns'] ?? c['pizza_grid_columns'], 3).clamp(2, 4);
    _announceReady =
        _bool(c['pizzaAnnounceReady'] ?? c['pizza_announce_ready'], true);
    _bgColor.text = _hex(c['pizzaBgColor'] ?? c['pizza_bg_color'], '#E4002B');
    _nameColor.text =
        _hex(c['pizzaNameColor'] ?? c['pizza_name_color'], '#FFFFFF');
    _priceColor.text =
        _hex(c['pizzaPriceColor'] ?? c['pizza_price_color'], '#FFFFFF');
  }

  void _emit() {
    widget.onDraftChanged({
      'pizzaBgColor':
          _bgColor.text.trim().isEmpty ? '#E4002B' : _bgColor.text.trim(),
      'pizzaNameColor':
          _nameColor.text.trim().isEmpty ? '#FFFFFF' : _nameColor.text.trim(),
      'pizzaPriceColor':
          _priceColor.text.trim().isEmpty ? '#FFFFFF' : _priceColor.text.trim(),
      'pizzaSizeColor':
          _priceColor.text.trim().isEmpty ? '#FFFFFF' : _priceColor.text.trim(),
      'pizzaPhotoScale': _photoScale,
      'pizzaNameFontScale': _nameFontScale,
      'pizzaPriceFontScale': _priceFontScale,
      'pizzaHoldMs': (_holdSec * 1000).round(),
      'pizzaTransitMs': (_transitSec * 1000).round(),
      'pizzaSpinRpm': _spinRpm,
      'pizzaGridColumns': _gridCols,
      'pizzaAnnounceReady': _announceReady,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Конструктор пиццы', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          _isShow
              ? 'Фон, масштаб фото, скорость въезда и вращение.'
              : 'Фон, колонки сетки и размеры текста.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bgColor,
          decoration: const InputDecoration(
            labelText: 'Цвет фона (#E4002B)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameColor,
          decoration: const InputDecoration(
            labelText: 'Цвет названия',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priceColor,
          decoration: const InputDecoration(
            labelText: 'Цвет цены / размеров',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        Text(
          'Масштаб фото: ${_photoScale.toStringAsFixed(2)}',
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          value: _photoScale,
          min: 0.6,
          max: 2.2,
          divisions: 32,
          onChanged: (v) => setState(() => _photoScale = v),
          onChangeEnd: (_) => _emit(),
        ),
        Text(
          'Масштаб названия: ${_nameFontScale.toStringAsFixed(2)}',
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          value: _nameFontScale,
          min: 0.6,
          max: 2.0,
          divisions: 28,
          onChanged: (v) => setState(() => _nameFontScale = v),
          onChangeEnd: (_) => _emit(),
        ),
        Text(
          'Масштаб цены: ${_priceFontScale.toStringAsFixed(2)}',
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          value: _priceFontScale,
          min: 0.6,
          max: 2.0,
          divisions: 28,
          onChanged: (v) => setState(() => _priceFontScale = v),
          onChangeEnd: (_) => _emit(),
        ),
        if (_isShow) ...[
          Text(
            'Пауза в центре: ${_holdSec.toStringAsFixed(1)} с',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _holdSec,
            min: 2,
            max: 15,
            divisions: 26,
            onChanged: (v) => setState(() => _holdSec = v),
            onChangeEnd: (_) => _emit(),
          ),
          Text(
            'Въезд / выезд: ${_transitSec.toStringAsFixed(1)} с',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _transitSec,
            min: 0.6,
            max: 4,
            divisions: 34,
            onChanged: (v) => setState(() => _transitSec = v),
            onChangeEnd: (_) => _emit(),
          ),
          Text(
            'Вращение: ${_spinRpm.toStringAsFixed(2)} об/мин',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _spinRpm,
            min: 0,
            max: 2,
            divisions: 40,
            onChanged: (v) => setState(() => _spinRpm = v),
            onChangeEnd: (_) => _emit(),
          ),
        ] else ...[
          Text(
            'Колонок в сетке: $_gridCols',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: _gridCols.toDouble(),
            min: 2,
            max: 4,
            divisions: 2,
            label: '$_gridCols',
            onChanged: (v) => setState(() => _gridCols = v.round()),
            onChangeEnd: (_) => _emit(),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('«Можете забирать» при готовности'),
          subtitle: const Text(
            'Оверлей + озвучка номера заказа. Табло очереди не показывается.',
          ),
          value: _announceReady,
          onChanged: (v) {
            setState(() => _announceReady = v);
            _emit();
          },
        ),
      ],
    );
  }
}
