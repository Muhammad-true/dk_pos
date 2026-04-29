import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/admin/bloc/screens_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_bloc.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/admin_tv_queue_board_designer_screen.dart';
import 'package:dk_pos/features/admin/presentation/navigation/admin_modern_page_route.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_catalog_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_menu_items_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_tv1_slides_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_screens_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/combos_admin_panel.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Точка входа в каталог: карточки разделов → отдельные экраны с анимацией перехода.
class AdminCatalogHub extends StatefulWidget {
  const AdminCatalogHub({
    super.key,
    required this.l10n,
    required this.maxBodyWidth,
  });

  final AppLocalizations l10n;
  final double maxBodyWidth;

  @override
  State<AdminCatalogHub> createState() => _AdminCatalogHubState();
}

class _AdminCatalogHubState extends State<AdminCatalogHub> {
  Future<AdminSyncStatus>? _syncFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFuture ??= context.read<AdminReportsRepository>().fetchSyncStatus();
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      AdminModernPageRoute<void>(page: page),
    );
  }

  void _openCategories(BuildContext context) {
    final bloc = context.read<CatalogAdminBloc>();
    _push(
      context,
      BlocProvider.value(
        value: bloc,
        child: _CatalogSubScaffold(
          title: widget.l10n.adminCatalogTabCategories,
          child: AdminCatalogPanel(maxBodyWidth: widget.maxBodyWidth),
        ),
      ),
    );
  }

  void _openProducts(
    BuildContext context, {
    required bool restrictGlobalCatalogEdits,
  }) {
    final catalogBloc = context.read<CatalogAdminBloc>();
    final menuBloc = context.read<MenuItemsAdminBloc>();
    _push(
      context,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: catalogBloc),
          BlocProvider.value(value: menuBloc),
        ],
        child: _CatalogSubScaffold(
          title: widget.l10n.adminCatalogTabProducts,
          child: AdminMenuItemsPanel(
            maxBodyWidth: widget.maxBodyWidth,
            restrictGlobalCatalogEdits: restrictGlobalCatalogEdits,
          ),
        ),
      ),
    );
  }

  void _openCombos(BuildContext context) {
    _push(
      context,
      _CatalogSubScaffold(
        title: widget.l10n.adminCatalogTabCombos,
        child: CombosAdminPanel(maxBodyWidth: widget.maxBodyWidth),
      ),
    );
  }

  void _openScreens(BuildContext context) {
    final repo = context.read<ScreensAdminRepository>();
    _push(
      context,
      BlocProvider(
        create: (_) =>
            ScreensAdminBloc(repo)..add(const ScreensLoadRequested()),
        child: _CatalogSubScaffold(
          title: widget.l10n.adminCatalogTabScreens,
          child: AdminScreensPanel(maxBodyWidth: widget.maxBodyWidth),
        ),
      ),
    );
  }

  void _openTvQueueDesigner(BuildContext context) {
    _push(
      context,
      const _CatalogSubScaffold(
        title: 'ТВ-очередь',
        child: AdminTvQueueBoardDesignerScreen(),
      ),
    );
  }

  void _openTv1Slides(BuildContext context) {
    final catalogBloc = context.read<CatalogAdminBloc>();
    _push(
      context,
      BlocProvider.value(
        value: catalogBloc,
        child: _CatalogSubScaffold(
          title: 'ТВ1 — слайды',
          child: AdminTv1SlidesPanel(maxBodyWidth: widget.maxBodyWidth),
        ),
      ),
    );
  }

  void _showGlobalOnlyHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Категории и товары задаются в глобальной админке. Здесь только синхронизация (pull).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = widget.l10n;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: FutureBuilder<AdminSyncStatus>(
          future: _syncFuture,
          builder: (context, snap) {
            final readOnly = snap.data?.globalCatalogLocalEditDisabled ?? false;
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
              children: [
                if (readOnly) ...[
                  Material(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.cloud_download_rounded, color: scheme.onSecondaryContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Каталог (названия, цены, категории) — в глобальной админке и pull. На точке: «Товары» — кухня; «ТВ1 — слайды» — слайд карусели по категории (categories.tv1_page); у товара можно своё tv1_page. Создание категорий здесь недоступно.',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.adminCatalogHubLead,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _HubTile(
                  icon: Icons.category_rounded,
                  iconColor: scheme.primary,
                  title: l10n.adminCatalogTabCategories,
                  subtitle: l10n.adminCatalogHubCategoriesHint,
                  muted: readOnly,
                  onTap: () {
                    if (readOnly) {
                      _showGlobalOnlyHint(context);
                    } else {
                      _openCategories(context);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _HubTile(
                  icon: Icons.fastfood_rounded,
                  iconColor: scheme.tertiary,
                  title: l10n.adminCatalogTabProducts,
                  subtitle: readOnly
                      ? 'Распределение по кухням на этой точке (каталог — через pull)'
                      : l10n.adminCatalogHubProductsHint,
                  onTap: () => _openProducts(
                    context,
                    restrictGlobalCatalogEdits: readOnly,
                  ),
                ),
                const SizedBox(height: 12),
                _HubTile(
                  icon: Icons.layers_rounded,
                  iconColor: scheme.secondary,
                  title: l10n.adminCatalogTabCombos,
                  subtitle: l10n.adminCatalogHubCombosHint,
                  onTap: () => _openCombos(context),
                ),
                const SizedBox(height: 12),
                _HubTile(
                  icon: Icons.tv_rounded,
                  iconColor: scheme.error,
                  title: l10n.adminCatalogTabScreens,
                  subtitle: l10n.adminCatalogHubScreensHint,
                  onTap: () => _openScreens(context),
                ),
                const SizedBox(height: 12),
                _HubTile(
                  icon: Icons.view_carousel_rounded,
                  iconColor: scheme.primary,
                  title: 'ТВ1 — слайды',
                  subtitle:
                      'Слайд по категории: товары подтянутся автоматически (переопределение — у товара)',
                  onTap: () => _openTv1Slides(context),
                ),
                const SizedBox(height: 12),
                _HubTile(
                  icon: Icons.format_list_numbered_rounded,
                  iconColor: scheme.primary,
                  title: 'ТВ-очередь',
                  subtitle:
                      'Цвета, размеры шапки, полосок, анимация смены номеров (экран очереди, не меню)',
                  onTap: () => _openTvQueueDesigner(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CatalogSubScaffold extends StatelessWidget {
  const _CatalogSubScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: child,
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: muted ? 0.5 : 1,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
