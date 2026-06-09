import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_bloc.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/admin_tv_settings_screen.dart';
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

  void _openTvSettings(BuildContext context) {
    _push(
      context,
      _CatalogSubScaffold(
        title: 'Настройки ТВ',
        child: AdminTvSettingsScreen(maxBodyWidth: widget.maxBodyWidth),
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

            final tiles = <_HubTileConfig>[
              _HubTileConfig(
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
              _HubTileConfig(
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
              _HubTileConfig(
                icon: Icons.layers_rounded,
                iconColor: scheme.secondary,
                title: l10n.adminCatalogTabCombos,
                subtitle: l10n.adminCatalogHubCombosHint,
                onTap: () => _openCombos(context),
              ),
              _HubTileConfig(
                icon: Icons.tv_rounded,
                iconColor: scheme.error,
                title: l10n.adminCatalogTabScreens,
                subtitle: l10n.adminCatalogHubScreensHint,
                onTap: () => _openScreens(context),
              ),
              _HubTileConfig(
                icon: Icons.view_carousel_rounded,
                iconColor: scheme.primary,
                title: 'ТВ1 — слайды',
                subtitle:
                    'Слайд по категории: товары подтянутся автоматически (переопределение — у товара)',
                onTap: () => _openTv1Slides(context),
              ),
              _HubTileConfig(
                icon: Icons.settings_remote_rounded,
                iconColor: scheme.primary,
                title: 'Настройки ТВ',
                subtitle:
                    'Режим очереди, звук, TTS, экраны ТВ4 и оформление доски — без правки .env на приставке',
                onTap: () => _openTvSettings(context),
              ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                final cols = WindowLayout(width: constraints.maxWidth)
                    .hubGridColumns(minCellWidth: 280);
                final useGrid = cols > 1;

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (readOnly) ...[
                            Material(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.cloud_download_rounded,
                                      color: scheme.onSecondaryContainer,
                                    ),
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
                        ]),
                      ),
                    ),
                    if (useGrid)
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 24),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: cols >= 3 ? 1.55 : 1.75,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _HubTile(
                              config: tiles[i],
                              vertical: true,
                            ),
                            childCount: tiles.length,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => Padding(
                              padding: EdgeInsets.only(
                                bottom: i == tiles.length - 1 ? 0 : 12,
                              ),
                              child: _HubTile(config: tiles[i]),
                            ),
                            childCount: tiles.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
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

class _HubTileConfig {
  const _HubTileConfig({
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
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.config,
    this.vertical = false,
  });

  final _HubTileConfig config;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconBox = Container(
      width: vertical ? 48 : 52,
      height: vertical ? 48 : 52,
      decoration: BoxDecoration(
        color: config.iconColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(config.icon, color: config.iconColor, size: vertical ? 26 : 28),
    );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          maxLines: vertical ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          config.subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
          maxLines: vertical ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: config.onTap,
        child: Opacity(
          opacity: config.muted ? 0.5 : 1,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: vertical ? 16 : 18,
              vertical: vertical ? 16 : 18,
            ),
            child: vertical
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      iconBox,
                      const SizedBox(height: 12),
                      texts,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      iconBox,
                      const SizedBox(width: 16),
                      Expanded(child: texts),
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
