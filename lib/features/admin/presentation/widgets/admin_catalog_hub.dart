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
import 'package:dk_pos/features/admin/presentation/widgets/admin_screens_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/combos_admin_panel.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Точка входа в каталог: карточки разделов → отдельные экраны с анимацией перехода.
class AdminCatalogHub extends StatelessWidget {
  const AdminCatalogHub({
    super.key,
    required this.l10n,
    required this.maxBodyWidth,
  });

  final AppLocalizations l10n;
  final double maxBodyWidth;

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
          title: l10n.adminCatalogTabCategories,
          child: AdminCatalogPanel(maxBodyWidth: maxBodyWidth),
        ),
      ),
    );
  }

  void _openProducts(BuildContext context) {
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
          title: l10n.adminCatalogTabProducts,
          child: AdminMenuItemsPanel(maxBodyWidth: maxBodyWidth),
        ),
      ),
    );
  }

  void _openCombos(BuildContext context) {
    _push(
      context,
      _CatalogSubScaffold(
        title: l10n.adminCatalogTabCombos,
        child: CombosAdminPanel(maxBodyWidth: maxBodyWidth),
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
          title: l10n.adminCatalogTabScreens,
          child: AdminScreensPanel(maxBodyWidth: maxBodyWidth),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBodyWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          children: [
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
              onTap: () => _openCategories(context),
            ),
            const SizedBox(height: 12),
            _HubTile(
              icon: Icons.fastfood_rounded,
              iconColor: scheme.tertiary,
              title: l10n.adminCatalogTabProducts,
              subtitle: l10n.adminCatalogHubProductsHint,
              onTap: () => _openProducts(context),
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
              icon: Icons.format_list_numbered_rounded,
              iconColor: scheme.primary,
              title: 'ТВ-очередь',
              subtitle:
                  'Цвета, размеры шапки, полосок, анимация смены номеров (экран очереди, не меню)',
              onTap: () => _openTvQueueDesigner(context),
            ),
          ],
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
    );
  }
}
