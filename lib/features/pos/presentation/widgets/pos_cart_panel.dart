import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/app/pos_cart_panel/pos_cart_panel_cubit.dart';
import 'package:dk_pos/app/pos_cart_panel/pos_cart_panel_settings.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';

import 'pos_checkout_flow.dart';

/// Вкладки открытых чеков — в [AppBar.bottom], стиль как у «Тип заказа».
class PosAppBarCheckTabs extends StatelessWidget implements PreferredSizeWidget {
  const PosAppBarCheckTabs({
    super.key,
    this.openCartSheetWhenCheckSelected = false,
  });

  /// На телефоне: после смены чека открыть корзину снизу (см. [showPosCartSheet]).
  final bool openCartSheetWhenCheckSelected;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cart) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Text(
                  'Чеки',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in cart.checks)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CheckTabStripItem(
                            label: c.displayLabel,
                            selected: c.id == cart.activeCheckId,
                            showClose: cart.checks.length > 1,
                            onTap: () {
                              context
                                  .read<CartBloc>()
                                  .add(CartCheckSelected(c.id));
                              scheduleCustomerDisplayCartSync(context);
                              if (!openCartSheetWhenCheckSelected) return;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;
                                final st = context.read<CartBloc>().state;
                                if (!st.isEmpty) showPosCartSheet(context);
                              });
                            },
                            onClose: () => _confirmRemoveCheck(context, c),
                          ),
                        ),
                      IconButton.filledTonal(
                        tooltip: 'Новый чек',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          context
                              .read<CartBloc>()
                              .add(const CartCheckCreated());
                          scheduleCustomerDisplayCartSync(context);
                        },
                        icon: const Icon(Icons.add_rounded, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Содержимое корзины: список позиций, итог; для шита или боковой панели.
class PosCartPanel extends StatelessWidget {
  const PosCartPanel({
    super.key,
    this.scrollController,
    this.onClose,
    /// Контекст экрана POS под модальным листом: диалоги оформления и закрытие листа перед ними.
    this.checkoutHostContext,
  });

  final ScrollController? scrollController;
  final VoidCallback? onClose;
  final BuildContext? checkoutHostContext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PosCartPanelCubit, PosCartPanelSettings>(
      builder: (context, panelSettings) {
        return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
          builder: (context, hall) {
            return BlocBuilder<CartBloc, CartState>(
              builder: (context, cart) {
                final kitchenLocks =
                    hall.openBillAppendKitchenQtyLockedByLineKey;
                final disableClearCart = hall.openBillAppendDraft != null;
                final bottomSafe =
                    MediaQuery.viewPaddingOf(context).bottom + 10;
                final dockedCart = WindowLayout.of(context).dockPosCart;
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomSafe),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CartPanelHeader(
                        cart: cart,
                        onClose: onClose,
                        onPickTable: () => _pickTableForActiveCheck(context),
                        disableClearCart: disableClearCart,
                        compact: dockedCart,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: cart.isEmpty
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        return SingleChildScrollView(
                                          padding: const EdgeInsets.all(24),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: constraints.maxHeight,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 76,
                                                  height: 76,
                                                  decoration: BoxDecoration(
                                                    color: scheme.primary
                                                        .withValues(
                                                      alpha: 0.10,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      24,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.point_of_sale_rounded,
                                                    size: 34,
                                                    color: scheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  l10n.cartEmpty,
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  dockedCart
                                                      ? 'Добавьте позиции из каталога слева.'
                                                      : 'Добавьте позиции из каталога. Несколько чеков — переключайте вкладками «Чеки» в верхней панели.',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : _CartLinesList(
                                      lines: cart.sortedLines,
                                      kitchenLocks: kitchenLocks,
                                      scrollController: scrollController,
                                      panelSettings: panelSettings,
                                    ),
                            ),
                            _CartPanelFooterMeta(
                              cart: cart,
                              panelSettings: panelSettings,
                            ),
                          ],
                        ),
                      ),
                      _CartPanelFooterActions(
                        cart: cart,
                        panelSettings: panelSettings,
                        onCloseSheet: onClose,
                        checkoutHostContext: checkoutHostContext,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CartLinesList extends StatefulWidget {
  const _CartLinesList({
    required this.lines,
    required this.kitchenLocks,
    required this.panelSettings,
    this.scrollController,
  });

  final List<CartLine> lines;
  final Map<String, bool> kitchenLocks;
  final PosCartPanelSettings panelSettings;
  final ScrollController? scrollController;

  @override
  State<_CartLinesList> createState() => _CartLinesListState();
}

class _CartLinesListState extends State<_CartLinesList> {
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();
  int _lastLineCount = 0;
  int _lastItemCount = 0;

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(_CartLinesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lineCount = widget.lines.length;
    final itemCount = widget.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    if (lineCount > _lastLineCount || itemCount > _lastItemCount) {
      _lastLineCount = lineCount;
      _lastItemCount = itemCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    } else {
      _lastLineCount = lineCount;
      _lastItemCount = itemCount;
    }
  }

  @override
  void initState() {
    super.initState();
    _lastLineCount = widget.lines.length;
    _lastItemCount =
        widget.lines.fold<int>(0, (sum, line) => sum + line.quantity);
  }

  void _scrollToLatest() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = WindowLayout.of(context).isCompact;
    final panel = widget.panelSettings;
    final padV = panel.linePaddingV;

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      itemCount: widget.lines.length,
      itemBuilder: (_, i) {
        final line = widget.lines[i];
        final lineTotal = line.item.price * line.quantity;
        final kitchenLocked = widget.kitchenLocks[line.lineKey] == true;
        return Card(
          margin: EdgeInsets.only(bottom: panel.lineCardMargin),
          elevation: 0,
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, padV, 10, padV),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: panel.qtyBadgeSize,
                      height: panel.qtyBadgeSize,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${line.quantity}×',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line.displayName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatSomoni(lineTotal),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${formatSomoni(line.item.price)} за ${line.item.saleUnit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (kitchenLocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'На кухне уже «Готово» — убрать или изменить нельзя',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Уменьшить',
                            icon: Icon(
                              Icons.remove_rounded,
                              size: compact ? 20 : 18,
                            ),
                            constraints: BoxConstraints(
                              minWidth: compact ? 40 : 34,
                              minHeight: compact ? 40 : 34,
                            ),
                            padding: const EdgeInsets.all(6),
                            visualDensity: VisualDensity.compact,
                            onPressed: kitchenLocked
                                ? null
                                : () {
                                    context.read<CartBloc>().add(
                                          CartItemDecremented(line.lineKey),
                                        );
                                    scheduleCustomerDisplayCartSync(context);
                                  },
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${line.quantity}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Увеличить',
                            icon: Icon(
                              Icons.add_rounded,
                              size: compact ? 20 : 18,
                            ),
                            constraints: BoxConstraints(
                              minWidth: compact ? 40 : 34,
                              minHeight: compact ? 40 : 34,
                            ),
                            padding: const EdgeInsets.all(6),
                            visualDensity: VisualDensity.compact,
                            onPressed: kitchenLocked
                                ? null
                                : () {
                                    context.read<CartBloc>().add(
                                          CartItemAdded(
                                            line.item,
                                            unitPrice: line.item.price,
                                            modifiers: line.modifiers,
                                          ),
                                        );
                                    scheduleCustomerDisplayCartSync(context);
                                  },
                          ),
                        ],
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
}

class _CartPanelHeader extends StatelessWidget {
  const _CartPanelHeader({
    required this.cart,
    this.onClose,
    required this.onPickTable,
    this.disableClearCart = false,
    this.compact = false,
  });

  final CartState cart;
  final VoidCallback? onClose;
  final VoidCallback onPickTable;
  final bool disableClearCart;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.appL10n;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 10 : 12, 12, compact ? 6 : 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cartOrder,
                  style: (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cart.isEmpty
                      ? 'Нет позиций'
                      : '${cart.itemCount} поз. • ${formatSomoni(cart.payableTotal)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Стол',
            visualDensity: VisualDensity.compact,
            onPressed: onPickTable,
            icon: const Icon(Icons.table_restaurant_rounded, size: 22),
          ),
          if (!cart.isEmpty && !disableClearCart)
            IconButton(
              tooltip: l10n.cartClear,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                context.read<CartBloc>().add(const CartCleared());
                scheduleCustomerDisplayCartSync(context);
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
            ),
          if (onClose != null)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// Вкладка чека: тот же визуал, что «Тип заказа» (`_ActionMockButton`).
class _CheckTabStripItem extends StatelessWidget {
  const _CheckTabStripItem({
    required this.label,
    required this.selected,
    required this.showClose,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final bool selected;
  final bool showClose;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: showClose ? 188 : 156,
      child: Row(
        children: [
          Expanded(
            child: _ActionMockButton(
              label: label,
              icon: Icons.receipt_long_outlined,
              compact: true,
              highlighted: selected,
              onTap: onTap,
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 2),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _ensureWaiterDineInDefault(
  BuildContext context, {
  required bool waiterMode,
  required int orderTypeIndex,
  required bool lockOrderType,
}) {
  if (!waiterMode || lockOrderType || orderTypeIndex != -1) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final live = context.read<CartBloc>().state;
    if (live.activeOrderTypeIndex == -1) {
      context.read<CartBloc>().add(const CartOrderTypeIndexChanged(1));
    }
  });
}

class _CartPanelFooterMeta extends StatelessWidget {
  const _CartPanelFooterMeta({
    required this.cart,
    required this.panelSettings,
  });

  final CartState cart;
  final PosCartPanelSettings panelSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = context.watch<AuthBloc>().state.user;
    final waiterMode = user?.isWaiter == true;
    final gap = panelSettings.sectionGap;
    final orderRowH = panelSettings.orderTypeRowHeight;

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, hallState) {
        final draft = hallState.openBillAppendDraft;
        final lockOrderType = draft != null;
        _ensureWaiterDineInDefault(
          context,
          waiterMode: waiterMode,
          orderTypeIndex: cart.activeOrderTypeIndex,
          lockOrderType: lockOrderType,
        );
        final idx = draft != null
            ? posOrderTypeIndexForOpenBill(draft)
            : cart.activeOrderTypeIndex;
        final selectedType = _checkoutOrderTypeOrNull(idx);

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (draft != null) ...[
                Material(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Счёт: ${draft.tableZone?.shortLabel ?? '—'} • '
                            'стол ${draft.tableNumber?.toString() ?? '—'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context
                              .read<PosHallOrdersCubit>()
                              .clearOpenBillAppend(),
                          child: const Text('Отменить'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: gap),
              ],
              SizedBox(
                height: orderRowH,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionMockButton(
                        label: 'С собой',
                        icon: Icons.shopping_bag_outlined,
                        compact: true,
                        iconOnly: true,
                        highlighted: idx == 0,
                        onTap: lockOrderType
                            ? null
                            : () {
                                context.read<CartBloc>().add(
                                      const CartOrderTypeIndexChanged(0),
                                    );
                                scheduleCustomerDisplayCartSync(context);
                              },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionMockButton(
                        label: 'На месте',
                        icon: Icons.table_restaurant_rounded,
                        compact: true,
                        iconOnly: true,
                        highlighted: idx == 1,
                        onTap: lockOrderType
                            ? null
                            : () {
                                context.read<CartBloc>().add(
                                      const CartOrderTypeIndexChanged(1),
                                    );
                                scheduleCustomerDisplayCartSync(context);
                              },
                      ),
                    ),
                    if (!waiterMode) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionMockButton(
                          label: 'Доставка',
                          icon: Icons.delivery_dining_rounded,
                          compact: true,
                          iconOnly: true,
                          highlighted: idx == 2,
                          onTap: lockOrderType
                              ? null
                              : () {
                                  context.read<CartBloc>().add(
                                        const CartOrderTypeIndexChanged(2),
                                      );
                                  scheduleCustomerDisplayCartSync(context);
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selectedType == null) ...[
                SizedBox(height: gap * 0.5),
                Text(
                  'Выберите тип заказа',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.cartTotal,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (cart.paymentAdjustment != null &&
                          cart.paymentAdjustment!.hasDiscount) ...[
                        Text(
                          formatSomoni(cart.total),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '−${formatSomoni(cart.paymentAdjustment!.totalDiscount)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFEF6C00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      Text(
                        formatSomoni(cart.payableTotal),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartPanelFooterActions extends StatelessWidget {
  const _CartPanelFooterActions({
    required this.cart,
    required this.panelSettings,
    this.onCloseSheet,
    this.checkoutHostContext,
  });

  final CartState cart;
  final PosCartPanelSettings panelSettings;
  final VoidCallback? onCloseSheet;
  final BuildContext? checkoutHostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = context.watch<AuthBloc>().state.user;
    final waiterMode = user?.isWaiter == true;
    final canDiscount = user?.canProcessPosPayments == true;
    final phoneLayout = WindowLayout.of(context).isCompact;
    final actionRowH = panelSettings.actionRowHeight;

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, hallState) {
        final draft = hallState.openBillAppendDraft;
        final idx = draft != null
            ? posOrderTypeIndexForOpenBill(draft)
            : cart.activeOrderTypeIndex;
        final selectedType = _checkoutOrderTypeOrNull(idx);
        final hasDiscount = cart.paymentAdjustment != null &&
            cart.paymentAdjustment!.hasDiscount;

        return Material(
          color: scheme.surfaceContainer,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(
                left: BorderSide(color: scheme.outlineVariant),
                right: BorderSide(color: scheme.outlineVariant),
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Tooltip(
                  message: canDiscount
                      ? (hasDiscount ? 'Скидка' : 'Скидка %')
                      : 'Скидка доступна кассиру',
                  child: OutlinedButton(
                    onPressed: canDiscount && draft == null
                        ? () => configureCartPaymentDiscount(
                              context,
                              cartTotal: cart.total,
                            )
                        : null,
                    style: (hasDiscount
                            ? OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF6C00),
                                side: const BorderSide(
                                  color: Color(0xFFEF6C00),
                                ),
                              )
                            : OutlinedButton.styleFrom())
                        .copyWith(
                      minimumSize:
                          WidgetStatePropertyAll(Size(actionRowH, actionRowH)),
                      padding:
                          const WidgetStatePropertyAll(EdgeInsets.all(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Icon(Icons.percent_rounded, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: PosCheckoutFlowLock.inProgress,
                    builder: (context, checkoutBusy, _) {
                      final orderType = selectedType;
                      final canCheckout = !checkoutBusy &&
                          !cart.isEmpty &&
                          orderType != null;
                      final checkoutLabel = checkoutBusy
                          ? 'Оформляем...'
                          : (draft != null
                              ? 'Добавить к счёту'
                              : 'Оформить заказ');
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: Size(double.infinity, actionRowH),
                          padding: EdgeInsets.symmetric(
                            horizontal: phoneLayout ? 14 : 10,
                            vertical: 10,
                          ),
                        ),
                        onPressed: canCheckout
                            ? () => _runCheckoutFromCart(
                                  cart: context.read<CartBloc>().state,
                                  orderType: orderType,
                                  waiterMode: waiterMode,
                                  sheetContext: context,
                                  onCloseSheet: onCloseSheet,
                                  checkoutHostContext: checkoutHostContext,
                                )
                            : null,
                        icon: checkoutBusy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.receipt_long_rounded, size: 20),
                        label: Text(checkoutLabel),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

PosCheckoutOrderType? _checkoutOrderTypeOrNull(int idx) => switch (idx) {
      0 => PosCheckoutOrderType.takeAway,
      1 => PosCheckoutOrderType.dineIn,
      2 => PosCheckoutOrderType.delivery,
      _ => null,
    };

/// Лист корзины живёт в отдельном overlay-route без [PosHallOrdersCubit] сверху — перед диалогами
/// закрываем лист и вызываем оформление с [checkoutHostContext] (контекст POS под листом).
Future<void> _runCheckoutFromCart({
  required CartState cart,
  required PosCheckoutOrderType orderType,
  required bool waiterMode,
  required BuildContext sheetContext,
  required VoidCallback? onCloseSheet,
  required BuildContext? checkoutHostContext,
}) async {
  final host = checkoutHostContext ?? sheetContext;
  if (!host.mounted) return;
  final append = host.read<PosHallOrdersCubit>().state.openBillAppendDraft;
  await runPosCheckoutFlow(
    host,
    orderType: orderType,
    cart: cart,
    waiterMode: waiterMode,
    appendToOpenBill: append,
    closeCartSheet:
        onCloseSheet != null && checkoutHostContext != null ? onCloseSheet : null,
  );
}

Future<void> _pickTableForActiveCheck(BuildContext context) async {
  final outcome = await showPosTablePickDialog(
    context,
    allowSkipTable: true,
  );
  if (!context.mounted) return;
  if (outcome == null) return;
  if (outcome is PosTablePickChosen) {
    context.read<CartBloc>().add(
          CartCheckTableLabelSet(
            '${outcome.zone.shortLabel} • стол ${outcome.number}',
          ),
        );
  } else if (outcome is PosTablePickSkipTable) {
    context.read<CartBloc>().add(
          const CartCheckTableLabelSet('На месте • без стола'),
        );
  }
}

Future<void> _confirmRemoveCheck(BuildContext context, CartCheckInfo check) async {
  if (!context.mounted) return;
  if (check.itemCount > 0) {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Закрыть чек?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'В чеке «${check.displayLabel}» есть позиции (${check.itemCount} шт.). '
            'Закрыть вкладку без оформления?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
  }
  if (!context.mounted) return;
  context.read<CartBloc>().add(CartCheckRemoved(check.id));
  scheduleCustomerDisplayCartSync(context);
}

class _ActionMockButton extends StatelessWidget {
  const _ActionMockButton({
    required this.label,
    required this.icon,
    this.highlighted = false,
    this.onTap,
    this.compact = false,
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;
  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor =
        highlighted ? scheme.primary : scheme.onSurfaceVariant;

    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: iconOnly
            ? EdgeInsets.symmetric(
                horizontal: compact ? 8 : 14,
                vertical: compact ? 10 : 14,
              )
            : EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 9 : 10,
              ),
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: iconOnly
            ? Icon(
                icon,
                size: compact ? 22 : 24,
                color: iconColor,
              )
            : Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: compact ? 14 : 18,
                    color: iconColor,
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? theme.textTheme.labelSmall
                              : theme.textTheme.labelLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: highlighted ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (iconOnly) {
      return Tooltip(message: label, child: button);
    }
    return button;
  }
}

/// Корзина снизу: на весь экран (full height), открывается из AppBar и кнопок POS.
/// Диалоги оформления ([runPosCheckoutFlow]) используют корневой навигатор, чтобы
/// не «терялись» под этим листом (в т.ч. выбор стола у официанта).
void showPosCartSheet(BuildContext anchorContext) {
  if (PosCheckoutFlowLock.inProgress.value) return;
  // Cubit висит только на дереве PosRoute; лист — отдельный route, без него read<> падал на Android.
  final hall = anchorContext.read<PosHallOrdersCubit>();
  final phoneLayout = MediaQuery.sizeOf(anchorContext).width < 600;
  showModalBottomSheet<void>(
    context: anchorContext,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(anchorContext).colorScheme.surface,
    shape: phoneLayout
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          )
        : const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    clipBehavior: Clip.antiAlias,
    showDragHandle: phoneLayout,
    builder: (sheetCtx) {
      final viewPadding = MediaQuery.viewPaddingOf(sheetCtx);
      return BlocProvider.value(
        value: hall,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetCtx).height -
                (phoneLayout ? viewPadding.top * 0.15 : 0),
            child: PosCartPanel(
              onClose: () => Navigator.pop(sheetCtx),
              checkoutHostContext: anchorContext,
            ),
          ),
        ),
      );
    },
  );
}
