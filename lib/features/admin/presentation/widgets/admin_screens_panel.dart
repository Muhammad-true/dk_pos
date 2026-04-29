import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/core/locale/api_locale.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_state.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/menu_display_preview_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/customer_display_designer_screen.dart';
import 'package:dk_pos/features/admin/presentation/screens/admin_tv_preview_page.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_list_row_card.dart';

const _kScreenTypes = ['carousel', 'tv2', 'tv3', 'tv4', 'customer_display'];

const _kTv2PageTypes = ['split', 'drinks', 'carousel', 'list', 'video_bg'];

/// Ключи конфига, которые задаёт конструктор шаблона (остальное — в «доп. JSON»).
const _kTemplateStripKeys = <String>{
  'tv1SectionColumns',
  'tv1_section_columns',
  'sectionColumns',
  'carouselColumns',
  'tv2ListColumns',
  'tv2_list_columns',
  'tv2SectionColumns',
  'tv1MaxSectionsPerSlide',
  'tv1_max_sections_per_slide',
  'tv1CategoriesPerSlide',
  'uiCenterGrid',
  'center_grid',
};

int? _cfgIntInRange(dynamic v, int min, int max) {
  if (v == null) return null;
  int? n;
  if (v is int) {
    n = v;
  } else if (v is num) {
    n = v.toInt();
  } else if (v is String) {
    n = int.tryParse(v.trim());
  }
  if (n == null || n < min || n > max) return null;
  return n;
}

int? _cfgPositiveInt(dynamic v) => _cfgIntInRange(v, 1, 999999);

int? _readTv1Columns(Map<String, dynamic> c) {
  for (final k in [
    'tv1SectionColumns',
    'tv1_section_columns',
    'sectionColumns',
    'carouselColumns',
  ]) {
    final x = _cfgIntInRange(c[k], 1, 3);
    if (x != null) return x;
  }
  return null;
}

int? _readTv2Columns(Map<String, dynamic> c) {
  for (final k in [
    'tv2ListColumns',
    'tv2_list_columns',
    'tv2SectionColumns',
  ]) {
    final x = _cfgIntInRange(c[k], 1, 3);
    if (x != null) return x;
  }
  return null;
}

int? _readTv1MaxPerSlide(Map<String, dynamic> c) {
  for (final k in [
    'tv1MaxSectionsPerSlide',
    'tv1_max_sections_per_slide',
    'tv1CategoriesPerSlide',
  ]) {
    final x = _cfgPositiveInt(c[k]);
    if (x != null) return x;
  }
  return null;
}

bool _readUiCenterGrid(Map<String, dynamic> c) {
  final v = c['uiCenterGrid'] ?? c['center_grid'];
  if (v == false || v == 0 || v == '0' || v == 'false') return false;
  return true;
}

Map<String, dynamic> _copyConfigWithoutTemplateKeys(Map<String, dynamic> src) {
  final out = Map<String, dynamic>.from(src);
  for (final k in _kTemplateStripKeys) {
    out.remove(k);
  }
  return out;
}

class AdminScreensPanel extends StatelessWidget {
  const AdminScreensPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminScreensTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: l10n.actionRetry,
                    onPressed: () => context
                        .read<ScreensAdminBloc>()
                        .add(const ScreensLoadRequested()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<ScreensAdminBloc, ScreensAdminState>(
                    buildWhen: (p, c) =>
                        p.status != c.status || p.screens != c.screens,
                    builder: (context, state) {
                      return FilledButton.icon(
                        onPressed: state.status == ScreensAdminStatus.loaded
                            ? () => _openEditor(context, l10n, null)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.adminScreenAdd),
                      );
                    },
                  ),
                ],
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: ExpansionTile(
                leading: Icon(
                  Icons.help_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  l10n.adminScreensHelpTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.adminScreensHelpBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<ScreensAdminBloc, ScreensAdminState>(
                builder: (context, state) {
                  if (state.status == ScreensAdminStatus.initial ||
                      (state.status == ScreensAdminStatus.loading &&
                          state.screens.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ScreensAdminStatus.failure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? l10n.adminScreensLoadError,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context
                                  .read<ScreensAdminBloc>()
                                  .add(const ScreensLoadRequested()),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.screens.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.adminScreensEmpty,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 20),
                    physics: kAdminListScrollPhysics,
                    itemCount: state.screens.length,
                    itemBuilder: (context, i) {
                      final s = state.screens[i];
                      final sub =
                          '${s.slug} · ${s.type} · ${s.isActive ? l10n.adminScreenActive : l10n.adminScreenInactive}';
                      return AdminListRowCard(
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.adminScreenPreviewTooltip,
                                icon: const Icon(Icons.tv_rounded),
                                onPressed: () =>
                                    _openSavedScreenPreview(context, l10n, s),
                              ),
                              IconButton(
                                tooltip: l10n.adminUsersEdit,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  if (s.type == 'customer_display') {
                                    Navigator.of(context, rootNavigator: true).push(
                                      MaterialPageRoute(
                                        builder: (_) => MultiProvider(
                                          providers: [
                                            RepositoryProvider.value(
                                              value: context.read<ScreensAdminRepository>(),
                                            ),
                                            RepositoryProvider.value(
                                              value: context.read<UploadRepository>(),
                                            ),
                                          ],
                                          child: CustomerDisplayDesignerScreen(
                                            screen: s,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    _openEditor(context, l10n, s);
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: l10n.adminScreenDelete,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, l10n, s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
    AdminScreenRow? existing,
  ) async {
    final repo = context.read<ScreensAdminRepository>();
    final bloc = context.read<ScreensAdminBloc>();
    final saved = await showDialog<AdminScreenRow>(
      context: context,
      builder: (ctx) => RepositoryProvider.value(
        value: repo,
        child: _ScreenEditorDialog(l10n: l10n, existing: existing),
      ),
    );
    if (saved != null && saved.type == 'customer_display' && context.mounted) {
      await Navigator.of(context, rootNavigator: true).push<AdminScreenRow>(
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              RepositoryProvider.value(value: repo),
              RepositoryProvider.value(value: context.read<UploadRepository>()),
            ],
            child: CustomerDisplayDesignerScreen(screen: saved),
          ),
        ),
      );
    }
    if (context.mounted) {
      bloc.add(const ScreensLoadRequested());
    }
  }

  Future<void> _openSavedScreenPreview(
    BuildContext context,
    AppLocalizations l10n,
    AdminScreenRow s,
  ) async {
    if (s.type == 'customer_display') {
      final repo = context.read<ScreensAdminRepository>();
      final uploadRepo = context.read<UploadRepository>();
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MultiProvider(
            providers: [
              RepositoryProvider.value(value: repo),
              RepositoryProvider.value(value: uploadRepo),
            ],
            child: CustomerDisplayDesignerScreen(screen: s, readOnly: true),
          ),
        ),
      );
      return;
    }
    final previewRepo = context.read<MenuDisplayPreviewRepository>();
    final screensRepo = context.read<ScreensAdminRepository>();
    final locale = context.read<LocaleBloc>().state.locale;
    final lang = menuApiLanguageCode(locale.languageCode);
    final body = <String, dynamic>{
      'type': s.type,
      'name': s.name,
      'config': s.config ?? <String, dynamic>{},
      'lang': lang,
      'screen_id': s.id,
    };
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminTvPreviewPage(
          previewRepo: previewRepo,
          screensRepo: screensRepo,
          requestBody: body,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    AdminScreenRow s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenDelete),
        content: Text(l10n.adminScreenDeleteConfirm(s.name)),
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
    final repo = context.read<ScreensAdminRepository>();
    final bloc = context.read<ScreensAdminBloc>();
    try {
      await repo.deleteScreen(s.id);
      bloc.add(const ScreensLoadRequested());
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreenDeleted)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _ScreenEditorDialog extends StatefulWidget {
  const _ScreenEditorDialog({required this.l10n, this.existing});

  final AppLocalizations l10n;
  final AdminScreenRow? existing;

  @override
  State<_ScreenEditorDialog> createState() => _ScreenEditorDialogState();
}

class _ScreenEditorDialogState extends State<_ScreenEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _extraConfigCtrl;
  late final TextEditingController _tv1MaxSectionsCtrl;
  late String _type;
  late bool _active;
  bool _saving = false;
  List<AdminScreenPageRow> _tv2Pages = [];
  bool _tv2PagesLoading = false;
  String _newTv2PageType = 'split';
  /// 0 = авто; 1–3 = фиксированное число колонок (ТВ1).
  int _tv1ColMode = 0;
  /// 0 = авто; 1–3 = колонки списка ТВ2.
  int _tv2ColMode = 0;
  bool _uiCenterGrid = true;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _slugCtrl = TextEditingController(text: e?.slug ?? '');
    _sortCtrl = TextEditingController(
      text: e != null ? e.sortOrder.toString() : '0',
    );
    _extraConfigCtrl = TextEditingController(text: '{}');
    _tv1MaxSectionsCtrl = TextEditingController();
    _type = e != null && _kScreenTypes.contains(e.type) ? e.type : 'carousel';
    _active = e?.isActive ?? true;
    _applyConfigToTemplate(e?.config);
    if (e != null && e.type == 'tv2') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTv2Pages());
    }
  }

  void _applyConfigToTemplate(Map<String, dynamic>? cfg) {
    _tv1ColMode = 0;
    _tv2ColMode = 0;
    _tv1MaxSectionsCtrl.clear();
    _uiCenterGrid = true;
    if (cfg == null || cfg.isEmpty) {
      _extraConfigCtrl.text = '{}';
      return;
    }
    final v1 = _readTv1Columns(cfg);
    if (v1 != null) _tv1ColMode = v1;
    final v2 = _readTv2Columns(cfg);
    if (v2 != null) _tv2ColMode = v2;
    final mx = _readTv1MaxPerSlide(cfg);
    if (mx != null) _tv1MaxSectionsCtrl.text = mx.toString();
    _uiCenterGrid = _readUiCenterGrid(cfg);
    final stripped = _copyConfigWithoutTemplateKeys(cfg);
    _extraConfigCtrl.text = stripped.isEmpty
        ? '{}'
        : const JsonEncoder.withIndent('  ').convert(stripped);
  }

  Map<String, dynamic> _buildTemplateConfigLayer() {
    final m = <String, dynamic>{};
    switch (_type) {
      case 'carousel':
        if (_tv1ColMode > 0) m['tv1SectionColumns'] = _tv1ColMode;
        final t = _tv1MaxSectionsCtrl.text.trim();
        if (t.isNotEmpty) {
          final n = int.tryParse(t);
          if (n != null && n > 0) m['tv1MaxSectionsPerSlide'] = n;
        }
        if (!_uiCenterGrid) m['uiCenterGrid'] = false;
        break;
      case 'tv2':
        if (_tv2ColMode > 0) m['tv2ListColumns'] = _tv2ColMode;
        if (!_uiCenterGrid) m['uiCenterGrid'] = false;
        break;
      default:
        break;
    }
    return m;
  }

  Map<String, dynamic>? _parseExtraConfigMap() {
    final rawCfg = _extraConfigCtrl.text.trim();
    if (rawCfg.isEmpty || rawCfg == '{}') return <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawCfg);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _composeConfigMap() {
    final extra = _parseExtraConfigMap();
    if (extra == null) return null;
    final layer = _buildTemplateConfigLayer();
    return {...extra, ...layer};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _sortCtrl.dispose();
    _extraConfigCtrl.dispose();
    _tv1MaxSectionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPreview() async {
    final l10n = widget.l10n;
    if (_type == 'customer_display') {
      if (_isCreate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сначала сохраните экран, потом откройте конструктор'),
          ),
        );
        return;
      }
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => MultiProvider(
            providers: [
              RepositoryProvider.value(value: context.read<ScreensAdminRepository>()),
              RepositoryProvider.value(value: context.read<UploadRepository>()),
            ],
            child: CustomerDisplayDesignerScreen(
              screen: widget.existing!,
              readOnly: true,
            ),
          ),
        ),
      );
      return;
    }
    final configMap = _composeConfigMap();
    if (configMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminScreenConfigInvalid)),
      );
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty
        ? l10n.adminTvPreviewTitle
        : _nameCtrl.text.trim();
    final locale = context.read<LocaleBloc>().state.locale;
    final lang = menuApiLanguageCode(locale.languageCode);
    final body = <String, dynamic>{
      'type': _type,
      'name': name,
      'config': configMap,
      'lang': lang,
    };
    if (!_isCreate) {
      body['screen_id'] = widget.existing!.id;
    }
    final previewRepo = context.read<MenuDisplayPreviewRepository>();
    final screensRepo = context.read<ScreensAdminRepository>();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminTvPreviewPage(
          previewRepo: previewRepo,
          screensRepo: screensRepo,
          requestBody: body,
        ),
      ),
    );
  }

  Future<void> _loadTv2Pages() async {
    if (_isCreate || widget.existing == null) return;
    setState(() => _tv2PagesLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = widget.l10n;
    try {
      final repo = context.read<ScreensAdminRepository>();
      final list = await repo.fetchScreenPages(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        _tv2Pages = list;
        _tv2PagesLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _tv2PagesLoading = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _tv2PagesLoading = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreensLoadError)));
    }
  }

  Future<void> _addTv2Page() async {
    if (_isCreate || widget.existing == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = widget.l10n;
    final nextOrder = _tv2Pages.isEmpty
        ? 0
        : _tv2Pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    setState(() => _saving = true);
    try {
      final repo = context.read<ScreensAdminRepository>();
      await repo.addScreenPage(
        widget.existing!.id,
        pageType: _newTv2PageType,
        sortOrder: nextOrder,
      );
      await _loadTv2Pages();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreenPageAdded)));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteTv2Page(AdminScreenPageRow p) async {
    final l10n = widget.l10n;
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || widget.existing == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final repo = context.read<ScreensAdminRepository>();
      await repo.deleteScreenPage(widget.existing!.id, p.id);
      await _loadTv2Pages();
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreenPageDeleted)));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = widget.l10n;
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final configMap = _composeConfigMap();
    if (configMap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminScreenConfigInvalid)),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<ScreensAdminRepository>();
    final nav = Navigator.of(context);

    try {
      if (_isCreate) {
        final created = await repo.createScreen({
          'name': _nameCtrl.text.trim(),
          'slug': _slugCtrl.text.trim(),
          'type': _type,
          'sort_order': sort,
          'config': configMap,
        });
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreenCreated)));
        if (mounted) nav.pop(created);
      } else {
        final updated = await repo.updateScreen(widget.existing!.id, {
          'name': _nameCtrl.text.trim(),
          'slug': _slugCtrl.text.trim(),
          'type': _type,
          'sort_order': sort,
          'is_active': _active ? 1 : 0,
          'config': configMap,
        });
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminScreenUpdated)));
        if (mounted) nav.pop(updated);
      }
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
        _isCreate ? l10n.adminScreenCreateTitle : l10n.adminScreenEditTitle,
      ),
      content: SizedBox(
        width: math.min(440, MediaQuery.sizeOf(context).width * 0.94),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminScreenName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.adminScreenNameError : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slugCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminScreenSlug,
                    hintText: 'tv-hall-1',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.adminScreenSlugError : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('screen_type_$_type'),
                  initialValue: _type,
                  isExpanded: true,
                  selectedItemBuilder: (context) => _kScreenTypes
                      .map(
                        (t) => Text(
                          _typeLabel(l10n, t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                  decoration: InputDecoration(
                    labelText: l10n.adminScreenType,
                    border: const OutlineInputBorder(),
                  ),
                  items: _kScreenTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(l10n, t)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _type = v;
                            if (v == 'tv2' && widget.existing != null) {
                              _loadTv2Pages();
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategorySortOrder,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (!_isCreate) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(l10n.adminScreenActive),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _active = v),
                  ),
                ],
                if (_type == 'tv2') ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: Text(l10n.adminScreenTv2Pages),
                    subtitle: Text(
                      l10n.adminScreenTv2PagesHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                      if (_isCreate)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.adminScreenTv2SaveFirst),
                            ],
                          ),
                        )
                      else if (_tv2PagesLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        ..._tv2Pages.map(
                          (p) => ListTile(
                            dense: true,
                            title: Text(_tv2PageTypeLabel(l10n, p.pageType)),
                            subtitle: Text(l10n.adminScreenPageItems(p.itemsCount)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: _saving
                                  ? null
                                  : () => _confirmDeleteTv2Page(p),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey('new_tv2_page_$_newTv2PageType'),
                                initialValue: _newTv2PageType,
                                isExpanded: true,
                                selectedItemBuilder: (context) => _kTv2PageTypes
                                    .map(
                                      (t) => Text(
                                        _tv2PageTypeLabel(l10n, t),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                    .toList(),
                                decoration: InputDecoration(
                                  labelText: l10n.adminScreenPageTypeLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                items: _kTv2PageTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(_tv2PageTypeLabel(l10n, t)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          setState(() => _newTv2PageType = v);
                                        }
                                      },
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.add_rounded),
                                label: Text(l10n.adminScreenPageAdd),
                                onPressed: _saving ? null : _addTv2Page,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(l10n.adminScreenDisplayTemplateTitle),
                  subtitle: Text(
                    l10n.adminScreenDisplayTemplateSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_type == 'carousel') ...[
                            DropdownButtonFormField<int>(
                              key: ValueKey('tv1cols_$_tv1ColMode'),
                              initialValue: _tv1ColMode,
                              isExpanded: true,
                              selectedItemBuilder: (context) => [
                                Text(
                                  l10n.adminScreenColsAuto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text('1', maxLines: 1, overflow: TextOverflow.ellipsis),
                                const Text('2', maxLines: 1, overflow: TextOverflow.ellipsis),
                                const Text('3', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.adminScreenTv1Columns,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(l10n.adminScreenColsAuto),
                                ),
                                const DropdownMenuItem(value: 1, child: Text('1')),
                                const DropdownMenuItem(value: 2, child: Text('2')),
                                const DropdownMenuItem(value: 3, child: Text('3')),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setState(() => _tv1ColMode = v);
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _tv1MaxSectionsCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.adminScreenMaxCategoriesPerSlide,
                                helperText: l10n.adminScreenMaxCategoriesHint,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                          if (_type == 'tv2') ...[
                            DropdownButtonFormField<int>(
                              key: ValueKey('tv2cols_$_tv2ColMode'),
                              initialValue: _tv2ColMode,
                              isExpanded: true,
                              selectedItemBuilder: (context) => [
                                Text(
                                  l10n.adminScreenColsAuto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text('1', maxLines: 1, overflow: TextOverflow.ellipsis),
                                const Text('2', maxLines: 1, overflow: TextOverflow.ellipsis),
                                const Text('3', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              decoration: InputDecoration(
                                labelText: l10n.adminScreenTv2Columns,
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(l10n.adminScreenColsAuto),
                                ),
                                const DropdownMenuItem(value: 1, child: Text('1')),
                                const DropdownMenuItem(value: 2, child: Text('2')),
                                const DropdownMenuItem(value: 3, child: Text('3')),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setState(() => _tv2ColMode = v);
                                      }
                                    },
                            ),
                          ],
                          if (_type == 'carousel' || _type == 'tv2') ...[
                            const SizedBox(height: 4),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.adminScreenCenterGrid),
                              subtitle: Text(
                                l10n.adminScreenCenterGridSubtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              value: _uiCenterGrid,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _uiCenterGrid = v),
                            ),
                          ],
                          if (_type == 'tv3' || _type == 'tv4')
                            Text(
                              l10n.adminScreenTemplateNotForType,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _extraConfigCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.adminScreenExtraConfigJson,
                    helperText: l10n.adminScreenExtraConfigHint,
                    hintText: '{}',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _openPreview,
          icon: const Icon(Icons.visibility_outlined),
          label: Text(l10n.adminScreenPreview),
        ),
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

  String _typeLabel(AppLocalizations l10n, String t) {
    switch (t) {
      case 'carousel':
        return l10n.adminScreenTypeCarousel;
      case 'tv2':
        return l10n.adminScreenTypeTv2;
      case 'tv3':
        return l10n.adminScreenTypeTv3;
      case 'tv4':
        return l10n.adminScreenTypeTv4;
      case 'customer_display':
        return 'Customer Display';
      default:
        return t;
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
}
