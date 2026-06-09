import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dk_pos/core/cache/pos_menu_image_prefetch.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_pos_actions.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_sync_state.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_idle_renderer.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_catalog_category_style.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_fly_to_cart.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_product_image.dart';
import 'package:dk_pos/shared/shared.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

/// Каталог + корзина для экрана клиента (только просмотр, без кнопок).
class CustomerDisplayMenuView extends StatefulWidget {
  const CustomerDisplayMenuView({
    super.key,
    required this.menu,
    required this.cart,
    this.cartAddPulse,
    this.syncFilePath,
    this.idleContentConfig,
  });

  final CustomerDisplayMenuSnapshot menu;
  final CustomerDisplayCartData cart;
  final CustomerDisplayCartAddPulse? cartAddPulse;
  final String? syncFilePath;
  final CustomerDisplayContentConfig? idleContentConfig;

  @override
  State<CustomerDisplayMenuView> createState() => _CustomerDisplayMenuViewState();
}

class _CustomerDisplayMenuViewState extends State<CustomerDisplayMenuView> {
  final GlobalKey _gridAreaKey = GlobalKey();
  final GlobalKey _cartAreaKey = GlobalKey();
  int _lastPlayedPulseSeq = 0;

  @override
  void initState() {
    super.initState();
    _lastPlayedPulseSeq = widget.cartAddPulse?.seq ?? 0;
  }

  @override
  void didUpdateWidget(CustomerDisplayMenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlayCartAddPulse(widget.cartAddPulse);
  }

  void _maybePlayCartAddPulse(CustomerDisplayCartAddPulse? pulse) {
    if (pulse == null || pulse.seq <= 0 || pulse.seq <= _lastPlayedPulseSeq) {
      return;
    }
    _lastPlayedPulseSeq = pulse.seq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playFlyToCart(pulse);
    });
  }

  Future<void> _sendPosAction(
    CustomerDisplayPosAction action, {
    String? productId,
    List<int>? pathIds,
  }) async {
    final path = widget.syncFilePath;
    if (path == null || path.trim().isEmpty) return;
    await writeCustomerDisplayPosAction(
      path,
      action,
      productId: productId,
      pathIds: pathIds,
    );
  }

  Future<void> _playFlyToCart(CustomerDisplayCartAddPulse pulse) async {
    final gridCtx = _gridAreaKey.currentContext;
    final cartCtx = _cartAreaKey.currentContext;
    if (gridCtx == null || cartCtx == null) return;

    final gridBox = gridCtx.findRenderObject() as RenderBox?;
    final cartBox = cartCtx.findRenderObject() as RenderBox?;
    if (gridBox == null ||
        cartBox == null ||
        !gridBox.hasSize ||
        !cartBox.hasSize) {
      return;
    }

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;
    final cartRect = cartBox.localToGlobal(Offset.zero) & cartBox.size;
    final from = Rect.fromCenter(
      center: gridRect.center,
      width: math.min(96, gridRect.width * 0.35),
      height: math.min(96, gridRect.height * 0.35),
    );
    final to = Rect.fromCenter(
      center: cartRect.center,
      width: math.min(64, cartRect.width * 0.4),
      height: math.min(64, cartRect.height * 0.25),
    );

    final item = PosMenuItem(
      id: '',
      categoryId: 0,
      name: pulse.name,
      priceText: '',
      price: 0,
      imagePath: pulse.imagePath,
    );

    await PosFlyToCart.play(
      context: context,
      fromGlobal: from,
      toGlobal: to,
      item: item,
      style: PosFlyToCartVisualStyle.customerDisplay,
    );
  }

  ({double sidebar, double cart, bool showSidebar}) _resolveColumnWidths(
    double totalWidth,
  ) {
    const outerPad = 32.0;
    const gap = 12.0;
    const minCenter = 260.0;
    const minCart = 272.0;
    final inner = math.max(0, totalWidth - outerPad);

    if (inner >= 1180) {
      final fixed = 220.0 + 300.0 + gap * 2;
      if (inner - fixed >= minCenter) {
        return (sidebar: 220, cart: 300, showSidebar: true);
      }
    }

    var cartW = math.min(300.0, math.max(minCart, inner * 0.28));
    var sideW = inner >= 760 ? math.min(210.0, math.max(140.0, inner * 0.15)) : 0.0;
    final gaps = sideW > 0 ? gap * 2 : gap;
    var centerW = inner - cartW - sideW - gaps;

    if (centerW < minCenter) {
      final deficit = minCenter - centerW;
      cartW = math.max(220, cartW - deficit * 0.4);
      if (sideW > 0) {
        sideW = math.max(120, sideW - deficit * 0.6);
      }
      centerW = inner - cartW - sideW - (sideW > 0 ? gap * 2 : gap);
    }

    if (centerW < 200 && sideW > 0) {
      sideW = math.max(120, sideW - (200 - centerW));
      centerW = inner - cartW - sideW - gap * 2;
    }

    return (sidebar: sideW, cart: cartW, showSidebar: sideW >= 120);
  }

  bool get _awaitingCategory => widget.menu.pathIds.isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final welcomeConfig =
        widget.idleContentConfig ?? CustomerDisplayContentConfig.fallback();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: customerDisplayBackgroundGradient(theme),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_awaitingCategory) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: _MenuWelcomePane(config: welcomeConfig),
              );
            }

            final widths = _resolveColumnWidths(constraints.maxWidth);
            final showCategorySidebar = widths.showSidebar &&
                widget.menu.rootCategories.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showCategorySidebar) ...[
                    SizedBox(
                      width: widths.sidebar,
                      child: _CategorySidebar(
                        categories: widget.menu.rootCategories,
                        pathIds: widget.menu.pathIds,
                        onSelectRoot: (id) => _sendPosAction(
                          CustomerDisplayPosAction.setMenuPath,
                          pathIds: [id],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.menu.breadcrumb.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                if (widget.menu.pathIds.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Назад',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _sendPosAction(
                                      CustomerDisplayPosAction.menuBack,
                                    ),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                                Expanded(
                                  child: Text(
                                    widget.menu.breadcrumb.join(' › '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.menu.pathIds.isNotEmpty &&
                            widget.menu.categories.isNotEmpty) ...[
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.hardEdge,
                              itemCount: widget.menu.categories.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = widget.menu.categories[index];
                                final colors = posCategoryColors(cat.name);
                                final active = widget.menu.pathIds.isNotEmpty &&
                                    widget.menu.pathIds.last == cat.id;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _sendPosAction(
                                      CustomerDisplayPosAction.setMenuPath,
                                      pathIds: [
                                        ...widget.menu.pathIds,
                                        cat.id,
                                      ],
                                    ),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: colors,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: active
                                            ? Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                                width: 2,
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.first.withValues(
                                              alpha: active ? 0.28 : 0.18,
                                            ),
                                            blurRadius: active ? 12 : 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            posCategoryIcon(cat.name),
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat.name,
                                            style: theme
                                                .textTheme.labelLarge
                                                ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Expanded(
                          child: KeyedSubtree(
                            key: _gridAreaKey,
                            child: _ProductGrid(
                              products: widget.menu.products,
                              scrollOffset: widget.menu.catalogScrollOffset,
                              onAddProduct: (id) => _sendPosAction(
                                CustomerDisplayPosAction.addItem,
                                productId: id,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: widths.cart,
                    child: KeyedSubtree(
                      key: _cartAreaKey,
                      child: _CustomerCartSidebar(
                        cart: widget.cart,
                        syncFilePath: widget.syncFilePath,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Полный экран: анимация + QR, пока раздел меню не выбран.
class _MenuWelcomePane extends StatelessWidget {
  const _MenuWelcomePane({required this.config});

  final CustomerDisplayContentConfig config;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CustomerDisplayIdleRenderer(config: config),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.pathIds,
    required this.onSelectRoot,
  });

  final List<CustomerDisplayMenuCategoryData> categories;
  final List<int> pathIds;
  final ValueChanged<int> onSelectRoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: customerDisplayGlassFill(theme),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: customerDisplayGlassBorder(theme)),
      ),
      child: categories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Разделы меню',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final active =
                    pathIds.isNotEmpty && pathIds.first == cat.id;
                final cardColors = posCategoryCardColors(index);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelectRoot(cat.id),
                    child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: active
                          ? cardColors
                          : [
                              cardColors.first.withValues(alpha: 0.96),
                              cardColors.last.withValues(alpha: 0.88),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active
                          ? Colors.white.withValues(alpha: 0.45)
                          : scheme.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cardColors.first.withValues(
                          alpha: active ? 0.28 : 0.12,
                        ),
                        blurRadius: active ? 14 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          posCategoryIcon(cat.name),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (cat.subtitle != null &&
                                cat.subtitle!.trim().isNotEmpty)
                              Text(
                                cat.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProductGrid extends StatefulWidget {
  const _ProductGrid({
    required this.products,
    required this.scrollOffset,
    required this.onAddProduct,
  });

  final List<CustomerDisplayMenuProductData> products;
  final double scrollOffset;
  final ValueChanged<String> onAddProduct;

  @override
  State<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<_ProductGrid> {
  final ScrollController _scrollController = ScrollController();
  double _lastAppliedScroll = -1;
  List<String> _lastProductIds = const [];

  @override
  void initState() {
    super.initState();
    _lastProductIds = widget.products.map((e) => e.id).toList(growable: false);
    _prefetchProductImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyScrollOffset(widget.scrollOffset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.products.map((e) => e.id).toList(growable: false);
    if (ids.join(',') != _lastProductIds.join(',')) {
      _lastProductIds = ids;
      _lastAppliedScroll = -1;
      _prefetchProductImages();
    }
    _applyScrollOffset(widget.scrollOffset);
  }

  void _prefetchProductImages() {
    if (widget.products.isEmpty) return;
    unawaited(prefetchCustomerDisplayProducts(widget.products));
  }

  void _applyScrollOffset(double offset) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyScrollOffset(offset);
      });
      return;
    }
    if ((offset - _lastAppliedScroll).abs() < 6) return;
    _lastAppliedScroll = offset;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.products.isEmpty) {
      return Center(
        child: Text(
          'Товары появятся, когда кассир откроет категорию',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const minCellWidth = 130.0;
        final maxWidth = constraints.maxWidth;
        final columns = math.max(
          2,
          ((maxWidth + spacing) / (minCellWidth + spacing)).floor(),
        );
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(4),
          clipBehavior: Clip.hardEdge,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.82,
          ),
          itemCount: widget.products.length,
          itemBuilder: (context, index) {
            final item = widget.products[index];
            final priceLabel = item.priceText.trim().isNotEmpty
                ? item.priceText
                : formatSomoni(item.price);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onAddProduct(item.id),
                child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.surfaceContainerLowest,
                    scheme.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: customerDisplayCardBorder(theme)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PosProductImage(
                          imagePath: item.imagePath,
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                          placeholderIconSize: 40,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD92D20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              priceLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
                ),
              ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomerCartSidebar extends StatelessWidget {
  const _CustomerCartSidebar({
    required this.cart,
    this.syncFilePath,
  });

  final CustomerDisplayCartData cart;
  final String? syncFilePath;

  Future<void> _requestPosAction(
    CustomerDisplayPosAction action, {
    int? orderTypeIndex,
  }) async {
    final path = syncFilePath;
    if (path == null || path.isEmpty) return;
    await writeCustomerDisplayPosAction(
      path,
      action,
      orderTypeIndex: orderTypeIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSendActions =
        syncFilePath != null && syncFilePath!.trim().isNotEmpty;
    final orderTypeIndex = cart.activeOrderTypeIndex;
    final hasLines = cart.lines.isNotEmpty;

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: customerDisplayCardSurface(theme),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: customerDisplayCardBorder(theme)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ваш заказ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (hasLines)
                    Text(
                      '${cart.itemCount} поз.',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: !hasLines
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Пока пусто',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            key: ValueKey(cart.listSyncKey),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            itemCount: cart.lines.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 12, color: scheme.outlineVariant),
                            itemBuilder: (context, index) {
                              final line = cart.lines[index];
                              return Row(
                                key: ValueKey(
                                  line.lineKey.isNotEmpty
                                      ? line.lineKey
                                      : 'line-$index-${line.name}',
                                ),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color:
                                          scheme.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${line.quantity}×',
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      line.name,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formatSomoni(line.lineTotal),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerOrderTypeChip(
                                label: 'С собой',
                                icon: Icons.shopping_bag_outlined,
                                selected: orderTypeIndex == 0,
                                onTap: canSendActions
                                    ? () => _requestPosAction(
                                          CustomerDisplayPosAction.setOrderType,
                                          orderTypeIndex: 0,
                                        )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CustomerOrderTypeChip(
                                label: 'На месте',
                                icon: Icons.table_restaurant_rounded,
                                selected: orderTypeIndex == 1,
                                onTap: canSendActions
                                    ? () => _requestPosAction(
                                          CustomerDisplayPosAction.setOrderType,
                                          orderTypeIndex: 1,
                                        )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _CustomerOrderTypeChip(
                                label: 'Доставка',
                                icon: Icons.delivery_dining_rounded,
                                selected: orderTypeIndex == 2,
                                onTap: canSendActions
                                    ? () => _requestPosAction(
                                          CustomerDisplayPosAction.setOrderType,
                                          orderTypeIndex: 2,
                                        )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Итого',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (cart.hasDiscount) ...[
                                  Text(
                                    formatSomoni(cart.total),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '−${formatSomoni(cart.discountTotal)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFFEF6C00),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                Text(
                                  formatSomoni(cart.displayTotal),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (hasLines && orderTypeIndex < 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Выберите тип заказа',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: cart.hasDiscount ? 'Скидка' : 'Скидка %',
                    child: OutlinedButton(
                      onPressed: canSendActions && hasLines
                          ? () => _requestPosAction(
                                CustomerDisplayPosAction.discount,
                              )
                          : null,
                      style: (cart.hasDiscount
                              ? OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF6C00),
                                  side: const BorderSide(
                                    color: Color(0xFFEF6C00),
                                  ),
                                )
                              : OutlinedButton.styleFrom())
                          .copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                        padding:
                            const WidgetStatePropertyAll(EdgeInsets.all(10)),
                      ),
                      child: const Icon(Icons.percent_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canSendActions &&
                              hasLines &&
                              orderTypeIndex >= 0
                          ? () => _requestPosAction(
                                CustomerDisplayPosAction.checkout,
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: const Text('Оформить заказ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerOrderTypeChip extends StatelessWidget {
  const _CustomerOrderTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
