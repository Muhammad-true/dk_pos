import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/domain/pos_table_bill.dart';

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
                        onPressed: () => context
                            .read<CartBloc>()
                            .add(const CartCheckCreated()),
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

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, hall) {
        return BlocBuilder<CartBloc, CartState>(
          builder: (context, cart) {
            final kitchenLocks = hall.openBillAppendKitchenQtyLockedByLineKey;
            final disableClearCart = hall.openBillAppendDraft != null;
            final bottomSafe =
                MediaQuery.viewPaddingOf(context).bottom + 10;
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
                  ),
            if (cart.isEmpty)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(24),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Добавьте позиции из каталога. Несколько чеков — переключайте вкладками «Чеки» в верхней панели.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: cart.sortedLines.length,
                  itemBuilder: (_, i) {
                    final line = cart.sortedLines[i];
                    final lineTotal = line.item.price * line.quantity;
                    final kitchenLocked =
                        kitchenLocks[line.lineKey] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 7),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    line.item.name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    formatSomoni(lineTotal),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatSomoni(line.item.price)} за ${line.item.saleUnit}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
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
                                        icon: const Icon(Icons.remove_rounded, size: 18),
                                        constraints: const BoxConstraints(
                                          minWidth: 34,
                                          minHeight: 34,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: kitchenLocked
                                            ? null
                                            : () => context.read<CartBloc>().add(
                                                  CartItemDecremented(line.lineKey),
                                                ),
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
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                        constraints: const BoxConstraints(
                                          minWidth: 34,
                                          minHeight: 34,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: kitchenLocked
                                            ? null
                                            : () => context.read<CartBloc>().add(
                                                  CartItemAdded(
                                                    line.item,
                                                    unitPrice: line.item.price,
                                                    modifiers: line.modifiers,
                                                  ),
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${line.quantity} шт.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            _OrderTypeAndTotalPanel(
              cart: cart,
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
  }
}

class _CartPanelHeader extends StatelessWidget {
  const _CartPanelHeader({
    required this.cart,
    this.onClose,
    required this.onPickTable,
    this.disableClearCart = false,
  });

  final CartState cart;
  final VoidCallback? onClose;
  final VoidCallback onPickTable;
  final bool disableClearCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.appL10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cartOrder,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cart.isEmpty
                          ? 'Нет позиций в этом чеке'
                          : '${cart.itemCount} позиций в заказе',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              TextButton(
                onPressed: cart.isEmpty || disableClearCart
                    ? null
                    : () => context.read<CartBloc>().add(const CartCleared()),
                child: Text(l10n.cartClear),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                onPressed: onPickTable,
                icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                label: const Text('Стол'),
              ),
              Text(
                'Для подписи на вкладке (например, зал • стол 4)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
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

class _OrderTypeAndTotalPanel extends StatelessWidget {
  const _OrderTypeAndTotalPanel({
    required this.cart,
    this.onCloseSheet,
    this.checkoutHostContext,
  });

  final CartState cart;
  final VoidCallback? onCloseSheet;
  final BuildContext? checkoutHostContext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = context.watch<AuthBloc>().state.user;
    final waiterMode = user?.isWaiter == true;

    return BlocBuilder<PosHallOrdersCubit, PosHallOrdersState>(
      builder: (context, hallState) {
        final draft = hallState.openBillAppendDraft;
        final idx = draft != null
            ? posOrderTypeIndexForOpenBill(draft)
            : cart.activeOrderTypeIndex;
        final selectedType = _checkoutOrderTypeOrNull(idx);
        final lockOrderType = draft != null;
        final orderTypeLabel = switch (idx) {
          1 => 'На месте',
          2 => 'Доставка',
          _ => 'Самовывоз',
        };
        final orderTypeIcon = switch (idx) {
          1 => Icons.table_restaurant_rounded,
          2 => Icons.delivery_dining_rounded,
          _ => Icons.shopping_bag_outlined,
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (draft != null) ...[
                Material(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 22,
                              color: scheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Текущий тип: $orderTypeLabel',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Зал: ${draft.tableZone?.shortLabel ?? '—'} • '
                          'Стол: ${draft.tableNumber?.toString() ?? '—'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    orderTypeIcon,
                                    size: 14,
                                    color: scheme.onSurface,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    orderTypeLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onCloseSheet != null)
                              OutlinedButton.icon(
                                onPressed: onCloseSheet,
                                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                                label: const Text('Добавить товар'),
                              ),
                            TextButton(
                              onPressed: () => context
                                  .read<PosHallOrdersCubit>()
                                  .clearOpenBillAppend(),
                              child: const Text('Отменить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Тип заказа',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ActionMockButton(
                      label: 'С собой',
                      icon: Icons.shopping_bag_outlined,
                      compact: true,
                      highlighted: idx == 0,
                      onTap: lockOrderType
                          ? null
                          : () => context.read<CartBloc>().add(
                                const CartOrderTypeIndexChanged(0),
                              ),
                    ),
                  ),
                  Expanded(
                    child: _ActionMockButton(
                      label: 'На месте',
                      icon: Icons.table_restaurant_rounded,
                      compact: true,
                      highlighted: idx == 1,
                      onTap: lockOrderType
                          ? null
                          : () => context.read<CartBloc>().add(
                                const CartOrderTypeIndexChanged(1),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionMockButton(
                      label: 'Доставка',
                      icon: Icons.delivery_dining_rounded,
                      compact: true,
                      highlighted: idx == 2,
                      onTap: lockOrderType
                          ? null
                          : () => context.read<CartBloc>().add(
                                const CartOrderTypeIndexChanged(2),
                              ),
                    ),
                  ),
                ],
              ),
              if (selectedType == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Сначала выберите тип заказа.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (waiterMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Официант: оплату и печать чека проводит касса. Для «На месте» при оформлении нужно выбрать стол.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    l10n.cartTotal,
                    style: theme.textTheme.titleMedium,
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
                          'Скидка −${formatSomoni(cart.paymentAdjustment!.totalDiscount)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFEF6C00),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      Text(
                        formatSomoni(cart.payableTotal),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: draft != null
                          ? null
                          : () => configureCartPaymentDiscount(
                                context,
                                cartTotal: cart.total,
                              ),
                      icon: const Icon(Icons.percent_rounded),
                      label: Text(
                        cart.paymentAdjustment != null &&
                                cart.paymentAdjustment!.hasDiscount
                            ? 'Скидка'
                            : '%',
                      ),
                      style: cart.paymentAdjustment != null &&
                              cart.paymentAdjustment!.hasDiscount
                          ? OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF6C00),
                              side: const BorderSide(color: Color(0xFFEF6C00)),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: cart.isEmpty || selectedType == null
                          ? null
                          : () => _runCheckoutFromCart(
                                cart: context.read<CartBloc>().state,
                                orderType: selectedType,
                                waiterMode: waiterMode,
                                sheetContext: context,
                                onCloseSheet: onCloseSheet,
                                checkoutHostContext: checkoutHostContext,
                              ),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: Text(draft != null ? 'Добавить к счёту (сохранить)' : 'Оформить заказ'),
                    ),
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
  final close = onCloseSheet;
  if (close != null && checkoutHostContext != null) {
    close();
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  if (!host.mounted) return;
  final append = host.read<PosHallOrdersCubit>().state.openBillAppendDraft;
  await runPosCheckoutFlow(
    host,
    orderType: orderType,
    cart: cart,
    waiterMode: waiterMode,
    appendToOpenBill: append,
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
}

class _ActionMockButton extends StatelessWidget {
  const _ActionMockButton({
    required this.label,
    required this.icon,
    this.highlighted = false,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
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
        child: Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: compact ? 14 : 18,
              color: highlighted ? scheme.primary : scheme.onSurfaceVariant,
            ),
            SizedBox(width: compact ? 4 : 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: highlighted ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Корзина снизу: на весь экран (full height), открывается из AppBar и кнопок POS.
/// Диалоги оформления ([runPosCheckoutFlow]) используют корневой навигатор, чтобы
/// не «терялись» под этим листом (в т.ч. выбор стола у официанта).
void showPosCartSheet(BuildContext anchorContext) {
  // Cubit висит только на дереве PosRoute; лист — отдельный route, без него read<> падал на Android.
  final hall = anchorContext.read<PosHallOrdersCubit>();
  showModalBottomSheet<void>(
    context: anchorContext,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(anchorContext).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    clipBehavior: Clip.none,
    showDragHandle: false,
    builder: (sheetCtx) {
      return BlocProvider.value(
        value: hall,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetCtx).height,
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
