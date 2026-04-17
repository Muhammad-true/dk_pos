import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/shared/shared.dart';

import 'pos_menu_item_card.dart';

/// Иерархия категорий: назад, крошки, дочерние узлы, товары текущего уровня.
class PosCatalogBody extends StatelessWidget {
  const PosCatalogBody({
    super.key,
    required this.menu,
    required this.catalogPaneWidth,
  });

  final MenuState menu;
  final double catalogPaneWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layout = WindowLayout(width: catalogPaneWidth);
    final wideCat = layout.posSideCategoryNavForCatalogPane(catalogPaneWidth);
    final activeRootId = menu.pathIds.isEmpty ? null : menu.pathIds.first;
    final sideCats = menu.categoryRoots;
    final cats = menu.currentChildCategories;
    final items = menu.currentItems;
    final crossCount = layout.posCatalogGridColumns(
      catalogPaneWidth: catalogPaneWidth,
      sideCategoryNav: wideCat,
    );
    final aspect = layout.posCatalogGridAspectRatio(catalogPaneWidth);

    final navHeader = wideCat
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                if (menu.canGoBack)
                  IconButton(
                    tooltip: l10n.posCatalogBack,
                    onPressed: () =>
                        context.read<MenuBloc>().add(const MenuCatalogBack()),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    menu.breadcrumbLine.isEmpty
                        ? l10n.posCatalogSections
                        : menu.breadcrumbLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (menu.canGoBack)
                      IconButton(
                        tooltip: l10n.posCatalogBack,
                        onPressed: () =>
                            context.read<MenuBloc>().add(const MenuCatalogBack()),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Expanded(
                      child: Text(
                        menu.breadcrumbLine.isEmpty
                            ? l10n.posCatalogSections
                            : menu.breadcrumbLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

    final grid = GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        childAspectRatio: aspect,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return PosMenuItemCard(
          item: item,
          onAdd: () => context.read<CartBloc>().add(CartItemAdded(item)),
          onConfigure: () => _showItemConfigDialog(context, item),
        );
      },
    );

    Widget rightPane() {
      if (items.isNotEmpty) {
        if (!wideCat) return grid;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PosQuickFilterChip(icon: Icons.local_fire_department_rounded, label: 'Хиты'),
                  _PosQuickFilterChip(icon: Icons.timer_outlined, label: 'Быстро'),
                  _PosQuickFilterChip(icon: Icons.star_outline_rounded, label: 'Комбо'),
                  _PosQuickFilterChip(icon: Icons.restaurant_menu_rounded, label: 'Добавки'),
                ],
              ),
            ),
            Expanded(child: grid),
          ],
        );
      }
      if (menu.pathIds.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.posCatalogNoItemsHere,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        );
      }
      if (cats.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.posCatalogPickCategory,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.menuEmpty,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget catNavContent() {
      if (sideCats.isEmpty) {
        if (menu.pathIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.menuEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          );
        }
        if (items.isNotEmpty) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.posCatalogNoSubcategories,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        );
      }
      if (wideCat) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: sideCats.length,
          itemBuilder: (_, i) {
            final c = sideCats[i];
            final hasKids = c.children.isNotEmpty;
            final selected = activeRootId == c.id;
            final cardColors = _categoryCardColors(i);
            return Card(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              elevation: selected ? 3 : 0,
              child: InkWell(
                onTap: () => context.read<MenuBloc>().add(
                  MenuCatalogPathSet([c.id]),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? cardColors
                          : [
                              cardColors.first.withValues(alpha: 0.96),
                              cardColors.last.withValues(alpha: 0.88),
                            ],
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: cardColors.first.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ListTile(
                    dense: catalogPaneWidth < WindowLayout.mediumMax,
                    minLeadingWidth: 52,
                    leading: _CategoryAvatar(category: c),
                    title: Text(
                      c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: c.subtitle != null && c.subtitle!.isNotEmpty
                        ? Text(
                            c.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          )
                        : null,
                    trailing: hasKids
                        ? const Icon(Icons.chevron_right_rounded, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            );
          },
        );
      }
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: sideCats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = sideCats[i];
          final hasKids = c.children.isNotEmpty;
          final selected = activeRootId == c.id;
          final cardColors = _categoryCardColors(i);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.read<MenuBloc>().add(
                  MenuCatalogPathSet([c.id]),
                ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: selected
                      ? cardColors
                      : [
                          cardColors.first.withValues(alpha: 0.96),
                          cardColors.last.withValues(alpha: 0.88),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? Colors.white.withValues(alpha: 0.45) : scheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cardColors.first.withValues(alpha: selected ? 0.22 : 0.12),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryAvatar(
                    category: c,
                    size: 28,
                    borderRadius: 10,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasKids)
                        Text(
                          'Раздел',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final catNav = SizedBox(
      width: wideCat ? WindowLayout.posCategoryRailWidth : double.infinity,
      height: wideCat ? double.infinity : 52,
      child: catNavContent(),
    );

    if (wideCat) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: WindowLayout.posCategoryRailWidth,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border(
                right: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                navHeader,
                Expanded(child: catNav),
              ],
            ),
          ),
          Expanded(child: rightPane()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        navHeader,
        catNav,
        Expanded(child: rightPane()),
      ],
    );
  }
}

class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.category,
    this.size = 44,
    this.borderRadius = 14,
    this.compact = false,
  });

  final PosCategory category;
  final double size;
  final double borderRadius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = _findCategoryPreviewImage(category);
    final icon = _categoryIcon(category.name);
    final colors = _categoryColors(category.name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: scheme.outlineVariant),
        gradient: imageUrl == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Builder(
              builder: (context) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final px = (size * dpr).round().clamp(1, 4096);
                return RobustNetworkImage(
                  url: imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: px,
                  cacheHeight: px,
                  errorWidget: _CategoryAvatarFallback(
                    icon: icon,
                    compact: compact,
                    colors: colors,
                  ),
                );
              },
            )
          : _CategoryAvatarFallback(
              icon: icon,
              compact: compact,
              colors: colors,
            ),
    );
  }
}

class _CategoryAvatarFallback extends StatelessWidget {
  const _CategoryAvatarFallback({
    required this.icon,
    required this.compact,
    required this.colors,
  });

  final IconData icon;
  final bool compact;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: compact ? 16 : 22,
      ),
    );
  }
}

String? _findCategoryPreviewImage(PosCategory category) {
  for (final item in category.items) {
    final path = item.imagePath?.trim();
    if (path != null && path.isNotEmpty) {
      final url = AppConfig.mediaUrl(path);
      if (url.isNotEmpty) return url;
    }
  }
  for (final child in category.children) {
    final nested = _findCategoryPreviewImage(child);
    if (nested != null) return nested;
  }
  return null;
}

IconData _categoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('бург')) return Icons.lunch_dining_rounded;
  if (value.contains('донер') || value.contains('шаур')) return Icons.kebab_dining_rounded;
  if (value.contains('комбо')) return Icons.fastfood_rounded;
  if (value.contains('напит')) return Icons.local_drink_rounded;
  if (value.contains('соус')) return Icons.soup_kitchen_rounded;
  if (value.contains('десерт')) return Icons.icecream_rounded;
  if (value.contains('снек') || value.contains('закуск')) return Icons.tapas_rounded;
  if (value.contains('карто')) return Icons.set_meal_rounded;
  return Icons.restaurant_menu_rounded;
}

List<Color> _categoryColors(String name) {
  final value = name.toLowerCase();
  if (value.contains('бург')) {
    return const [Color(0xFFE4002B), Color(0xFF9F0020)];
  }
  if (value.contains('донер') || value.contains('шаур')) {
    return const [Color(0xFF00A86B), Color(0xFF0A6C4A)];
  }
  if (value.contains('комбо')) {
    return const [Color(0xFFFF7A00), Color(0xFFC25700)];
  }
  if (value.contains('напит')) {
    return const [Color(0xFF1D8BFF), Color(0xFF1353B7)];
  }
  if (value.contains('соус')) {
    return const [Color(0xFFFFC21A), Color(0xFFC78B00)];
  }
  if (value.contains('десерт')) {
    return const [Color(0xFF9B5CFF), Color(0xFF6630C2)];
  }
  return const [Color(0xFF5F6B7A), Color(0xFF394350)];
}

List<Color> _categoryCardColors(int index) {
  const palette = [
    [Color(0xFFE4002B), Color(0xFFB00022)],
    [Color(0xFF14A44D), Color(0xFF0D6B32)],
    [Color(0xFFFF8A00), Color(0xFFC96A00)],
    [Color(0xFF2B8DFF), Color(0xFF1A5DD1)],
    [Color(0xFFFFC107), Color(0xFFD69200)],
    [Color(0xFFB06CFF), Color(0xFF7F3FE0)],
    [Color(0xFF00B8A9), Color(0xFF00796B)],
    [Color(0xFFFF6B6B), Color(0xFFC44545)],
  ];
  return palette[index % palette.length];
}

class _PosQuickFilterChip extends StatelessWidget {
  const _PosQuickFilterChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModifierOption extends StatelessWidget {
  const _ModifierOption({
    required this.label,
    this.selected = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.16) : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? scheme.primary.withValues(alpha: 0.6) : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showItemConfigDialog(BuildContext context, PosMenuItem item) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(
          item.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Настройка позиции',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Прожарка',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModifierOption(label: 'Medium', selected: true),
                    _ModifierOption(label: 'Well Done'),
                    _ModifierOption(label: 'Rare'),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Добавки',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModifierOption(label: 'Бекон', icon: Icons.add),
                    _ModifierOption(label: 'Халапеньо', icon: Icons.add),
                    _ModifierOption(label: 'Сыр', icon: Icons.add),
                    _ModifierOption(label: 'Без лука', icon: Icons.close),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Добавить'),
          ),
        ],
      );
    },
  );
}
