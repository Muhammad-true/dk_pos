import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_state.dart';
import 'package:dk_pos/features/admin/data/admin_category_row.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_station_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_stations_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_units_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_list_row_card.dart';

String _treeDots(int depth) {
  if (depth <= 0) return '';
  return '${List.filled(depth, '·').join(' ')} ';
}

/// Секция списка товаров в админке: одна кухня и её позиции.
class _KitchenItemSection {
  const _KitchenItemSection({
    required this.stationId,
    required this.title,
    required this.items,
  });

  final int? stationId;
  final String title;
  final List<AdminMenuItemRow> items;
}

List<_KitchenItemSection> _groupMenuItemsByKitchen(List<AdminMenuItemRow> items) {
  final byStation = <int?, List<AdminMenuItemRow>>{};
  for (final it in items) {
    byStation.putIfAbsent(it.kitchenStationId, () => []).add(it);
  }
  for (final list in byStation.values) {
    list.sort((a, b) {
      final c = a.category.ru.compareTo(b.category.ru);
      if (c != 0) return c;
      return a.name.ru.compareTo(b.name.ru);
    });
  }
  final ids = byStation.keys.toList()
    ..sort((a, b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      final na = byStation[a]!.first.kitchenStationName ?? '';
      final nb = byStation[b]!.first.kitchenStationName ?? '';
      final byName = na.compareTo(nb);
      if (byName != 0) return byName;
      return a.compareTo(b);
    });

  return ids.map((id) {
    final list = byStation[id]!;
    final title = id == null
        ? 'Без кухни'
        : ((list.first.kitchenStationName ?? '').trim().isNotEmpty
            ? list.first.kitchenStationName!.trim()
            : 'Кухня #$id');
    return _KitchenItemSection(stationId: id, title: title, items: list);
  }).toList();
}

class AdminMenuItemsPanel extends StatefulWidget {
  const AdminMenuItemsPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<AdminMenuItemsPanel> createState() => _AdminMenuItemsPanelState();
}

class _AdminMenuItemsPanelState extends State<AdminMenuItemsPanel> {
  int? _defaultKitchenStationId;
  bool _bulkMode = false;
  final Set<String> _selectedIds = {};
  List<KitchenStationRow> _kitchenStations = [];
  bool _kitchensLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKitchens());
  }

  Future<void> _loadKitchens() async {
    if (!mounted) return;
    setState(() => _kitchensLoading = true);
    try {
      final list =
          await context.read<KitchenStationsRepository>().fetchStations();
      if (!mounted) return;
      setState(() {
        _kitchenStations = list.where((e) => e.isActive == 1).toList();
        _kitchensLoading = false;
        if (_defaultKitchenStationId != null &&
            !_kitchenStations.any((e) => e.id == _defaultKitchenStationId)) {
          _defaultKitchenStationId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kitchenStations = [];
        _kitchensLoading = false;
      });
    }
  }

  Future<void> _bulkAssignKitchen(BuildContext context) async {
    final l10n = context.appL10n;
    if (_selectedIds.isEmpty) return;

    final repo = context.read<MenuItemsAdminRepository>();
    final bloc = context.read<MenuItemsAdminBloc>();
    final messenger = ScaffoldMessenger.of(context);

    int? chosen = _defaultKitchenStationId;
    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Назначить кухню: ${_selectedIds.length} товар(ов)',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        key: ValueKey<int?>(chosen),
                        initialValue: chosen,
                        decoration: const InputDecoration(
                          labelText: 'Кухня',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Без кухни'),
                          ),
                          ..._kitchenStations.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setModal(() => chosen = v),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.actionCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Применить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (apply != true || !mounted) return;

    var ok = 0;
    var fail = 0;
    String? lastErr;
    for (final id in _selectedIds.toList()) {
      try {
        await repo.updateItem(id, {'kitchen_station_id': chosen});
        ok++;
      } on ApiException catch (e) {
        fail++;
        lastErr = e.message;
      } catch (_) {
        fail++;
      }
    }
    bloc.add(const MenuItemsLoadRequested());
    setState(() {
      _selectedIds.clear();
      _bulkMode = false;
    });
    final tail = fail > 0
        ? ' Ошибок: $fail.${lastErr != null ? ' $lastErr' : ''}'
        : '';
    messenger.showSnackBar(
      SnackBar(content: Text('Обновлено позиций: $ok.$tail')),
    );
  }

  Widget _menuItemTile(
    BuildContext context,
    AppLocalizations l10n,
    AdminMenuItemRow it, {
    required bool showKitchenInSubtitle,
  }) {
    final sub = it.tvVolumeVariants.isNotEmpty
        ? '${it.category.ru} · ${it.tvVolumeVariants.map((v) => '${v.label} ${v.priceText}').join(', ')} · ${it.saleUnitDisplay}'
        : '${it.category.ru} · ${it.priceText.ru} · ${it.saleUnitDisplay}';
    final subFull = showKitchenInSubtitle
        ? '$sub · ${it.kitchenStationName ?? 'без кухни'}'
        : sub;
    final selected = _selectedIds.contains(it.id);
    return AdminListRowCard(
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _bulkMode
            ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIds.add(it.id);
                    } else {
                      _selectedIds.remove(it.id);
                    }
                  });
                },
              )
            : null,
        onTap: _bulkMode
            ? () => setState(() {
                  if (selected) {
                    _selectedIds.remove(it.id);
                  } else {
                    _selectedIds.add(it.id);
                  }
                })
            : null,
        title: Text(
          it.name.ru,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subFull,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.adminUsersEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditor(context, l10n, it),
            ),
            IconButton(
              tooltip: l10n.adminMenuItemDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmDelete(context, l10n, it),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminMenuItemsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: l10n.actionRetry,
                    onPressed: () {
                      context
                          .read<MenuItemsAdminBloc>()
                          .add(const MenuItemsLoadRequested());
                      _loadKitchens();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<MenuItemsAdminBloc, MenuItemsAdminState>(
                    buildWhen: (p, c) =>
                        p.status != c.status || p.items != c.items,
                    builder: (context, state) {
                      return FilledButton.icon(
                        onPressed: state.status == MenuItemsAdminStatus.loaded
                            ? () => _openEditor(context, l10n, null)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.adminMenuItemAdd),
                      );
                    },
                  ),
                ],
              ),
            ),
            BlocBuilder<MenuItemsAdminBloc, MenuItemsAdminState>(
              buildWhen: (p, c) => p.status != c.status,
              builder: (context, state) {
                if (state.status != MenuItemsAdminStatus.loaded) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _kitchensLoading
                            ? const LinearProgressIndicator(minHeight: 4)
                            : DropdownButtonFormField<int?>(
                                key: ValueKey(
                                  'default_kitchen_$_defaultKitchenStationId',
                                ),
                                initialValue: _defaultKitchenStationId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Кухня для новых товаров',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Не задано'),
                                  ),
                                  ..._kitchenStations.map(
                                    (s) => DropdownMenuItem<int?>(
                                      value: s.id,
                                      child: Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _defaultKitchenStationId = v,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: _bulkMode
                            ? 'Отменить выбор'
                            : 'Выбрать несколько',
                        onPressed: () => setState(() {
                          _bulkMode = !_bulkMode;
                          if (!_bulkMode) _selectedIds.clear();
                        }),
                        icon: Icon(
                          _bulkMode
                              ? Icons.close_rounded
                              : Icons.checklist_rounded,
                        ),
                      ),
                      if (_bulkMode && _selectedIds.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        FilledButton.tonal(
                          onPressed: () => _bulkAssignKitchen(context),
                          child: Text('Кухня (${_selectedIds.length})'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: BlocBuilder<MenuItemsAdminBloc, MenuItemsAdminState>(
                builder: (context, state) {
                  if (state.status == MenuItemsAdminStatus.initial ||
                      (state.status == MenuItemsAdminStatus.loading &&
                          state.items.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == MenuItemsAdminStatus.failure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ??
                                  l10n.adminMenuItemsLoadError,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context
                                  .read<MenuItemsAdminBloc>()
                                  .add(const MenuItemsLoadRequested()),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.items.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.adminMenuItemsEmpty,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.errorMessage != null)
                        Material(
                          color:
                              Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => context
                                      .read<MenuItemsAdminBloc>()
                                      .add(const MenuItemsErrorDismissed()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (state.errorMessage != null)
                        const SizedBox(height: 12),
                      Expanded(
                        child: state.status == MenuItemsAdminStatus.loading
                            ? const Center(child: CircularProgressIndicator())
                            : Builder(
                                builder: (context) {
                                  final sections =
                                      _groupMenuItemsByKitchen(state.items);
                                  final scheme =
                                      Theme.of(context).colorScheme;
                                  return ListView(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 20,
                                    ),
                                    physics: kAdminListScrollPhysics,
                                    children: [
                                      for (var si = 0;
                                          si < sections.length;
                                          si++) ...[
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            4,
                                            si == 0 ? 0 : 18,
                                            4,
                                            8,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.soup_kitchen_outlined,
                                                size: 22,
                                                color: scheme.primary,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${sections[si].title} · ${sections[si].items.length}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            scheme.onSurface,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...sections[si].items.map(
                                          (it) => _menuItemTile(
                                            context,
                                            l10n,
                                            it,
                                            showKitchenInSubtitle: false,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    AppLocalizations l10n,
    AdminMenuItemRow? existing,
  ) async {
    final categories = context.read<CatalogAdminBloc>().state.categories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCatalogEmpty)),
      );
      return;
    }
    final ordered = orderCategoriesForAdminTree(categories);
    final repo = context.read<MenuItemsAdminRepository>();
    final itemsBloc = context.read<MenuItemsAdminBloc>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => RepositoryProvider.value(
        value: repo,
        child: BlocProvider.value(
          value: itemsBloc,
          child: _MenuItemEditorDialog(
            l10n: l10n,
            categoriesOrdered: ordered,
            existing: existing,
            defaultKitchenStationId: existing == null
                ? _defaultKitchenStationId
                : null,
            onCreatedKitchenSaved: existing == null
                ? (k) {
                    if (mounted) {
                      setState(() => _defaultKitchenStationId = k);
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    AdminMenuItemRow it,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminMenuItemDelete),
        content: Text(l10n.adminMenuItemDeleteConfirm(it.name.ru)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<MenuItemsAdminRepository>();
    final bloc = context.read<MenuItemsAdminBloc>();
    try {
      await repo.deleteItem(it.id);
      bloc.add(const MenuItemsLoadRequested());
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminMenuItemDeleted)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _MenuItemEditorDialog extends StatefulWidget {
  const _MenuItemEditorDialog({
    required this.l10n,
    required this.categoriesOrdered,
    this.existing,
    this.defaultKitchenStationId,
    this.onCreatedKitchenSaved,
  });

  final AppLocalizations l10n;
  final List<AdminCategoryRow> categoriesOrdered;
  final AdminMenuItemRow? existing;
  final int? defaultKitchenStationId;
  final void Function(int? kitchenStationId)? onCreatedKitchenSaved;

  @override
  State<_MenuItemEditorDialog> createState() => _MenuItemEditorDialogState();
}

class _MenuItemEditorDialogState extends State<_MenuItemEditorDialog> {
  static const int _newKitchenStationValue = -1;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameRuCtrl;
  late final TextEditingController _nameTjCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _priceTextRuCtrl;
  late final TextEditingController _priceTextTjCtrl;
  late final TextEditingController _priceTextEnCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _descRuCtrl;
  late final TextEditingController _compRuCtrl;
  late final TextEditingController _volumeVariantsJsonCtrl;

  late int _categoryId;
  int? _saleUnitId;
  int? _kitchenStationId;
  List<MenuUnitOption> _units = [];
  List<KitchenStationRow> _kitchenStations = [];
  bool _unitsLoading = true;
  String? _unitsError;
  bool _kitchenLoading = true;
  late bool _available;
  late bool _trackStock;
  bool _saving = false;
  bool _uploadingImage = false;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idCtrl = TextEditingController(text: e?.id ?? '');
    _nameRuCtrl = TextEditingController(text: e?.name.ru ?? '');
    _nameTjCtrl = TextEditingController(text: e?.name.tj ?? '');
    _nameEnCtrl = TextEditingController(text: e?.name.en ?? '');
    _priceCtrl = TextEditingController(
      text: e != null ? e.price.toStringAsFixed(e.price == e.price.roundToDouble() ? 0 : 2) : '',
    );
    _priceTextRuCtrl = TextEditingController(text: e?.priceText.ru ?? '');
    _priceTextTjCtrl = TextEditingController(text: e?.priceText.tj ?? '');
    _priceTextEnCtrl = TextEditingController(text: e?.priceText.en ?? '');
    _imageCtrl = TextEditingController(text: e?.imagePath ?? '');
    _skuCtrl = TextEditingController(text: e?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: e?.barcode ?? '');
    _sortCtrl = TextEditingController(
      text: e != null ? e.sortOrder.toString() : '0',
    );
    _descRuCtrl = TextEditingController(text: e?.description?.ru ?? '');
    _compRuCtrl = TextEditingController(text: e?.composition?.ru ?? '');
    _volumeVariantsJsonCtrl = TextEditingController(
      text: _initialVolumeVariantsJson(e),
    );
    _categoryId = e?.categoryId ?? widget.categoriesOrdered.first.id;
    _saleUnitId = e != null && e.saleUnitId > 0 ? e.saleUnitId : null;
    _kitchenStationId =
        e?.kitchenStationId ?? widget.defaultKitchenStationId;
    _available = (e?.isAvailable ?? 1) == 1;
    _trackStock = (e?.trackStock ?? 1) == 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnits());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKitchenStations());
  }

  Future<void> _loadUnits() async {
    if (!mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _unitsLoading = true;
      _unitsError = null;
    });
    try {
      final list =
          await context.read<MenuUnitsRepository>().fetchUnits(lang);
      if (!mounted) return;
      setState(() {
        _units = list;
        _unitsLoading = false;
        if (_saleUnitId != null &&
            !_units.any((u) => u.id == _saleUnitId)) {
          _saleUnitId = null;
        }
        _saleUnitId ??= _units.isNotEmpty ? _units.first.id : null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _unitsLoading = false;
        _unitsError = err.toString();
      });
    }
  }

  Future<void> _loadKitchenStations() async {
    if (!mounted) return;
    setState(() => _kitchenLoading = true);
    try {
      final list = await context.read<KitchenStationsRepository>().fetchStations();
      if (!mounted) return;
      setState(() {
        _kitchenStations = list.where((e) => e.isActive == 1).toList();
        _kitchenLoading = false;
        if (_kitchenStationId != null &&
            !_kitchenStations.any((e) => e.id == _kitchenStationId)) {
          _kitchenStationId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kitchenStations = [];
        _kitchenLoading = false;
      });
    }
  }

  Future<void> _createKitchenStationInline() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _QuickCreateKitchenStationDialog(),
    );
    if (created == true) {
      await _loadKitchenStations();
    }
  }

  Future<void> _pickImage() async {
    final picked = await _pickImageBytes();
    if (picked == null || !mounted) return;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.adminMenuItemImageReadError)),
      );
      return;
    }
    setState(() => _uploadingImage = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await context.read<UploadRepository>().uploadMenuImageBytes(
            bytes,
            picked.name,
          );
      if (mounted) _imageCtrl.text = path;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<_SelectedImage?> _pickImageBytes() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return _SelectedImage(
        name: picked.name.isEmpty ? 'image.jpg' : picked.name,
        bytes: await picked.readAsBytes(),
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return _SelectedImage(name: file.name, bytes: file.bytes);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameRuCtrl.dispose();
    _nameTjCtrl.dispose();
    _nameEnCtrl.dispose();
    _priceCtrl.dispose();
    _priceTextRuCtrl.dispose();
    _priceTextTjCtrl.dispose();
    _priceTextEnCtrl.dispose();
    _imageCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _sortCtrl.dispose();
    _descRuCtrl.dispose();
    _compRuCtrl.dispose();
    _volumeVariantsJsonCtrl.dispose();
    super.dispose();
  }

  static String _initialVolumeVariantsJson(AdminMenuItemRow? e) {
    if (e == null || e.tvVolumeVariants.isEmpty) return '';
    return const JsonEncoder.withIndent('  ').convert(
      e.tvVolumeVariants
          .map((v) => {'label': v.label, 'priceText': v.priceText})
          .toList(),
    );
  }

  /// Пустая строка → []; битый формат → null.
  static List<Map<String, dynamic>>? _parseVolumeVariantsBody(String text) {
    final t = text.trim();
    if (t.isEmpty) return [];
    try {
      final decoded = jsonDecode(t);
      if (decoded is! List) return null;
      final out = <Map<String, dynamic>>[];
      for (final e in decoded) {
        if (e is! Map) return null;
        final label = (e['label'] ?? e['volume'] ?? '').toString().trim();
        final pt =
            (e['priceText'] ?? e['price_text'] ?? '').toString().trim();
        if (label.isEmpty || pt.isEmpty) return null;
        out.add({'label': label, 'priceText': pt});
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _nameMap() {
    final m = <String, dynamic>{'ru': _nameRuCtrl.text.trim()};
    final tj = _nameTjCtrl.text.trim();
    final en = _nameEnCtrl.text.trim();
    if (tj.isNotEmpty) m['tj'] = tj;
    if (en.isNotEmpty) m['en'] = en;
    return m;
  }

  Map<String, dynamic> _priceTextMap() {
    final m = <String, dynamic>{'ru': _priceTextRuCtrl.text.trim()};
    final tj = _priceTextTjCtrl.text.trim();
    final en = _priceTextEnCtrl.text.trim();
    if (tj.isNotEmpty) m['tj'] = tj;
    if (en.isNotEmpty) m['en'] = en;
    return m;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = widget.l10n;
    final price = double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminMenuItemPriceInvalid)),
      );
      return;
    }
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final cid = _categoryId;
    final unitId = _saleUnitId;

    if (unitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminMenuItemUnitRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<MenuItemsAdminRepository>();
    final bloc = context.read<MenuItemsAdminBloc>();
    final nav = Navigator.of(context);

    final descRu = _descRuCtrl.text.trim();
    final compRu = _compRuCtrl.text.trim();
    final imageRaw = _imageCtrl.text.trim();
    final skuRaw = _skuCtrl.text.trim();
    final bcRaw = _barcodeCtrl.text.trim();

    final volParsed = _parseVolumeVariantsBody(_volumeVariantsJsonCtrl.text);
    if (volParsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminMenuItemVolumeVariantsInvalid)),
      );
      return;
    }

    try {
      if (_isCreate) {
        final body = <String, dynamic>{
          'id': _idCtrl.text.trim(),
          'category_id': cid,
          'name': _nameMap(),
          'price': price,
          'price_text': _priceTextMap(),
          'sort_order': sort,
          'is_available': _available ? 1 : 0,
          'sale_unit_id': unitId,
          'kitchen_station_id': _kitchenStationId,
          'image_path': imageRaw.isEmpty ? null : imageRaw,
          'sku': skuRaw.isEmpty ? null : skuRaw,
          'barcode': bcRaw.isEmpty ? null : bcRaw,
          'track_stock': _trackStock ? 1 : 0,
        };
        if (descRu.isNotEmpty) {
          body['description'] = {'ru': descRu};
        }
        if (compRu.isNotEmpty) {
          body['composition'] = {'ru': compRu};
        }
        body['tv_volume_variants'] = volParsed;
        await repo.createItem(body);
        widget.onCreatedKitchenSaved?.call(_kitchenStationId);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.adminMenuItemCreated)),
        );
      } else {
        final id = widget.existing!.id;
        final body = <String, dynamic>{
          'category_id': cid,
          'name': _nameMap(),
          'price': price,
          'price_text': _priceTextMap(),
          'sort_order': sort,
          'is_available': _available ? 1 : 0,
          'sale_unit_id': unitId,
          'kitchen_station_id': _kitchenStationId,
          'image_path': imageRaw.isEmpty ? null : imageRaw,
          'sku': skuRaw.isEmpty ? null : skuRaw,
          'barcode': bcRaw.isEmpty ? null : bcRaw,
          'track_stock': _trackStock ? 1 : 0,
          'description': {'ru': descRu},
          'composition': {'ru': compRu},
          'tv_volume_variants': volParsed,
        };
        await repo.updateItem(id, body);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.adminMenuItemUpdated)),
        );
      }
      bloc.add(const MenuItemsLoadRequested());
      if (mounted) nav.pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(
        _isCreate ? l10n.adminMenuItemCreateTitle : l10n.adminMenuItemEditTitle,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isCreate) ...[
                  TextFormField(
                    controller: _idCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.adminMenuItemId,
                      hintText: l10n.adminMenuItemIdHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l10n.adminMenuItemIdError : null,
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<int>(
                  key: ValueKey('admin_item_cat_$_categoryId'),
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemCategory,
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.categoriesOrdered
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            '${_treeDots(c.depth)}${c.name.ru}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) setState(() => _categoryId = v);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameRuCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategoryNameRu,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.adminCategoryNameRuError
                          : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameTjCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategoryNameTg,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameEnCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategoryNameEn,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemPrice,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.adminMenuItemPriceInvalid
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceTextRuCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemPriceTextRu,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.adminMenuItemPriceTextRuError
                          : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceTextTjCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemPriceTextTg,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceTextEnCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemPriceTextEn,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_unitsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_unitsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.adminMenuItemUnitsLoadError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _loadUnits,
                          child: Text(l10n.actionRetry),
                        ),
                      ],
                    ),
                  )
                else if (_units.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.adminMenuItemUnitsEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'admin_item_unit_${_saleUnitId ?? _units.first.id}',
                    ),
                    initialValue: _saleUnitId ?? _units.first.id,
                    decoration: InputDecoration(
                      labelText: l10n.adminMenuItemSaleUnit,
                      border: const OutlineInputBorder(),
                    ),
                    items: _units
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _saleUnitId = v),
                  ),
                const SizedBox(height: 12),
                if (_kitchenLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  DropdownButtonFormField<int?>(
                    initialValue: _kitchenStationId,
                    decoration: const InputDecoration(
                      labelText: 'Кухня',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Без кухни'),
                      ),
                      const DropdownMenuItem<int?>(
                        value: _newKitchenStationValue,
                        child: Text('(+ новый)'),
                      ),
                      ..._kitchenStations.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) async {
                            if (v == _newKitchenStationValue) {
                              await _createKitchenStationInline();
                              return;
                            }
                            if (!mounted) return;
                            setState(() => _kitchenStationId = v);
                          },
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _imageCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminMenuItemImagePath,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.adminMenuItemPickImage,
                      child: IconButton.filledTonal(
                        onPressed: (_saving || _uploadingImage) ? null : _pickImage,
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _skuCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemSku,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _barcodeCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemBarcode,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategorySortOrder,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.adminCategorySortInvalid;
                    }
                    if (int.tryParse(v.trim()) == null) {
                      return l10n.adminCategorySortInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(l10n.adminMenuItemAvailable),
                  value: _available,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _available = v),
                ),
                SwitchListTile(
                  title: Text(l10n.adminMenuItemTrackStock),
                  value: _trackStock,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _trackStock = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descRuCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemDescriptionRu,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _compRuCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemCompositionRu,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _volumeVariantsJsonCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminMenuItemVolumeVariantsJson,
                    hintText: l10n.adminMenuItemVolumeVariantsHint,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List? bytes;
}

class _QuickCreateKitchenStationDialog extends StatefulWidget {
  const _QuickCreateKitchenStationDialog();

  @override
  State<_QuickCreateKitchenStationDialog> createState() =>
      _QuickCreateKitchenStationDialogState();
}

class _QuickCreateKitchenStationDialogState
    extends State<_QuickCreateKitchenStationDialog> {
  final _nameCtrl = TextEditingController();
  final _typeCodeCtrl = TextEditingController();
  final _typeNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCodeCtrl.dispose();
    _typeNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final typeCode = _typeCodeCtrl.text.trim().toLowerCase();
    final typeName = _typeNameCtrl.text.trim();
    if (name.isEmpty || typeCode.isEmpty || typeName.isEmpty) return;

    setState(() => _saving = true);
    final repo = context.read<KitchenStationsRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.createType(code: typeCode, name: typeName, isActive: 1);
    } on ApiException {
      // Тип уже может существовать — это не блокирует создание кухни.
    }
    try {
      await repo.createStation(
        name: name,
        type: typeCode,
        sortOrder: 0,
        isActive: 1,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая кухня'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название кухни',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _typeNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Название типа кухни',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _typeCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Код типа (latin)',
                hintText: 'например: grill',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
