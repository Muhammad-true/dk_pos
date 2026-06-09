import 'dart:async';

import 'package:flutter/material.dart';

import 'package:dk_pos/features/kitchen_board/presentation/kitchen_ui_preferences.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_item_chef_status_chip.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_number_badge.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Порог: выше — список в прокрутке + готовые сворачиваются.
const kKitchenLargeOrderItemThreshold = 10;

/// Порог: выше — компактная строка вместо полного списка готовых.
const kKitchenCompactReadyThreshold = 6;

enum _KitchenListEntryKind { followUpBanner, stationHeader, item, readyGroup }

class _KitchenListEntry {
  const _KitchenListEntry._(
    this.kind, {
    this.item,
    this.stationLabel,
    this.readyItems = const [],
    this.highlightAsNew = false,
    this.deemphasized = false,
  });

  const _KitchenListEntry.followUpBanner()
      : this._(_KitchenListEntryKind.followUpBanner);

  const _KitchenListEntry.stationHeader(String label)
      : this._(_KitchenListEntryKind.stationHeader, stationLabel: label);

  const _KitchenListEntry.item(
    LocalKitchenQueueItem value, {
    bool highlightAsNew = false,
    bool deemphasized = false,
  }) : this._(
          _KitchenListEntryKind.item,
          item: value,
          highlightAsNew: highlightAsNew,
          deemphasized: deemphasized,
        );

  const _KitchenListEntry.readyGroup(List<LocalKitchenQueueItem> items)
      : this._(_KitchenListEntryKind.readyGroup, readyItems: items);

  final _KitchenListEntryKind kind;
  final LocalKitchenQueueItem? item;
  final String? stationLabel;
  final List<LocalKitchenQueueItem> readyItems;
  final bool highlightAsNew;
  final bool deemphasized;
}

class KitchenActiveOrderCard extends StatefulWidget {
  const KitchenActiveOrderCard({
    super.key,
    required this.order,
    required this.tone,
    required this.busy,
    required this.l10n,
    required this.actors,
    required this.acceptColorOf,
    required this.readyColorOf,
    required this.onColorOf,
    required this.uiScale,
    required this.followUpSettings,
    required this.displayNumber,
    required this.orderTypeBadge,
    required this.onOrderAction,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final bool busy;
  final AppLocalizations l10n;
  final List<LocalKitchenActorProfile> actors;
  final Color Function(LocalKitchenActorProfile actor) acceptColorOf;
  final Color Function(LocalKitchenActorProfile actor) readyColorOf;
  final Color Function(Color background) onColorOf;
  final KitchenUiScale uiScale;
  final KitchenFollowUpSettings followUpSettings;
  final String displayNumber;
  final String? orderTypeBadge;
  final Future<void> Function({
    required LocalKitchenActorProfile actor,
    required String action,
  }) onOrderAction;

  @override
  State<KitchenActiveOrderCard> createState() => _KitchenActiveOrderCardState();
}

class _KitchenActiveOrderCardState extends State<KitchenActiveOrderCard> {
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final tone = widget.tone;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTablet = PosQueueLayout.isTablet(context);
    final compact = !isTablet;
    final baseFontSize = isTablet ? 16.0 : 14.0;
    final uiScale = widget.uiScale;
    final actionFontSize = baseFontSize * uiScale.buttonTextScale;
    final actionIconSize = (isTablet ? 20.0 : 16.0) * uiScale.buttonTextScale;
    final actionMinHeight = (isTablet ? 76.0 : 58.0) * uiScale.buttonScale;
    final actionButtonVerticalPadding = (isTablet ? 12.0 : 8.0) * uiScale.buttonScale;

    final stationItems = order.items;
    final rawFollowUp = _kitchenOrderIsFollowUp(stationItems);
    // Дозаказ: всегда показываем только pending/accepted, даже если подсветка выключена в настройках.
    final isFollowUpHighlight = widget.followUpSettings.enabled && rawFollowUp;
    final showCardHighlight = isFollowUpHighlight && widget.followUpSettings.highlightCard;
    final showLineHighlight = isFollowUpHighlight && widget.followUpSettings.highlightNewLines;
    final activeItems = rawFollowUp
        ? _kitchenOrderActiveItems(stationItems)
        : stationItems;
    final readyItems = rawFollowUp && !widget.followUpSettings.hideReadyItems
        ? _kitchenOrderReadyItems(stationItems)
        : const <LocalKitchenQueueItem>[];
    final isLargeOrder = stationItems.length >= kKitchenLargeOrderItemThreshold;
    final showReadyCollapsed = readyItems.isNotEmpty &&
        ((rawFollowUp && widget.followUpSettings.collapseReadyItems) ||
            isLargeOrder);
    final activeQty = activeItems.fold<int>(0, (sum, e) => sum + e.quantity);
    final hasPending = _kitchenOrderHasPendingItems(stationItems);

    final orderActionControls = _buildOrderActionControls(
      context,
      compact: compact,
      actionFontSize: actionFontSize,
      actionIconSize: actionIconSize,
      actionMinHeight: actionMinHeight,
      actionButtonVerticalPadding: actionButtonVerticalPadding,
      hasPending: hasPending,
      stationItems: stationItems,
    );

    final primaryAccepted = _kitchenOrderPrimaryAcceptedActor(
      items: stationItems,
      actors: widget.actors,
    );
    final orderChefAccent =
        primaryAccepted != null ? widget.acceptColorOf(primaryAccepted) : null;

    final entries = _buildKitchenCardEntries(
      activeItems: activeItems,
      readyItems: readyItems,
      showCardHighlight: showCardHighlight,
      showLineHighlight: showLineHighlight,
      showStationHeaders: _groupKitchenItemsByStation(activeItems).length > 1,
      showReadyCollapsed: showReadyCollapsed,
    );

    final lineStyle = _KitchenItemLineStyle(
      tone: tone,
      uiScale: uiScale,
      acceptColorOf: widget.acceptColorOf,
      readyColorOf: widget.readyColorOf,
      actors: widget.actors,
    );

    final itemsPanel = _KitchenVirtualItemsList(
      entries: entries,
      itemCount: activeItems.length,
      activeQty: activeQty,
      lineStyle: lineStyle,
      showCardHighlight: showCardHighlight,
      tone: tone,
    );

    final orderActionsPanel = orderActionControls.isEmpty
        ? null
        : _layoutOrderActions(
            orderActionControls,
            stackVertically: isTablet,
          );

    Widget buildCardBody() {
      if (isTablet && orderActionsPanel != null && !isLargeOrder) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: itemsPanel),
            const SizedBox(width: 12),
            SizedBox(width: 248, child: orderActionsPanel),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          itemsPanel,
          if (orderActionsPanel != null) ...[
            SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 12 : 14),
            orderActionsPanel,
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: (showCardHighlight ? Colors.deepOrange : tone).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showCardHighlight
              ? Colors.deepOrange.shade400.withValues(alpha: 0.75)
              : (orderChefAccent?.withValues(alpha: 0.55) ?? tone.withValues(alpha: 0.20)),
          width: showCardHighlight || orderChefAccent != null ? 2 : 1,
        ),
      ),
      padding: PosQueueLayout.cardOuterPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KitchenOrderCardHeader(
            displayNumber: widget.displayNumber,
            orderTypeBadge: widget.orderTypeBadge,
            tone: showCardHighlight ? Colors.deepOrange.shade700 : tone,
            uiScale: uiScale,
            showCardHighlight: showCardHighlight,
            activeQty: activeQty,
            totalItems: stationItems.length,
            isLargeOrder: isLargeOrder,
            itemsSummary: widget.l10n.expeditorItemsLine(stationItems.length),
            primaryAccepted: primaryAccepted,
            hasPending: hasPending,
            acceptColorOf: widget.acceptColorOf,
            actorLabel: primaryAccepted != null ? _actorUiLabel(primaryAccepted) : null,
          ),
          SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 12 : 14),
          buildCardBody(),
          if (widget.actors.isEmpty)
            Text(
              'Добавьте поваров в эту кухню через админку',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderActionControls(
    BuildContext context, {
    required bool compact,
    required double actionFontSize,
    required double actionIconSize,
    required double actionMinHeight,
    required double actionButtonVerticalPadding,
    required bool hasPending,
    required List<LocalKitchenQueueItem> stationItems,
  }) {
    Widget buildButton({
      required LocalKitchenActorProfile actor,
      required String action,
      required Color color,
      required IconData icon,
      required String actionLabel,
    }) {
      return _KitchenActorActionButton(
        color: color,
        onColor: widget.onColorOf(color),
        icon: icon,
        actorLabel: _actorUiLabel(actor),
        actionLabel: actionLabel,
        onPressed: widget.busy
            ? null
            : () => unawaited(widget.onOrderAction(actor: actor, action: action)),
        compact: compact,
        minHeight: actionMinHeight,
        fontSize: actionFontSize,
        iconSize: actionIconSize,
        verticalPadding: actionButtonVerticalPadding,
      );
    }

    final controls = <Widget>[];
    if (hasPending) {
      for (final actor in widget.actors) {
        controls.add(
          buildButton(
            actor: actor,
            action: 'accept',
            color: widget.acceptColorOf(actor),
            icon: Icons.pan_tool_alt_rounded,
            actionLabel: 'Принять',
          ),
        );
      }
    } else if (!_kitchenOrderAllReady(stationItems)) {
      for (final actor
          in _kitchenOrderReadyActors(items: stationItems, actors: widget.actors)) {
        controls.add(
          buildButton(
            actor: actor,
            action: 'ready',
            color: widget.readyColorOf(actor),
            icon: Icons.check_circle_rounded,
            actionLabel: 'Готово',
          ),
        );
      }
    }
    return controls;
  }
}

class _KitchenOrderCardHeader extends StatelessWidget {
  const _KitchenOrderCardHeader({
    required this.displayNumber,
    required this.orderTypeBadge,
    required this.tone,
    required this.uiScale,
    required this.showCardHighlight,
    required this.activeQty,
    required this.totalItems,
    required this.isLargeOrder,
    required this.itemsSummary,
    required this.primaryAccepted,
    required this.hasPending,
    required this.acceptColorOf,
    required this.actorLabel,
  });

  final String displayNumber;
  final String? orderTypeBadge;
  final Color tone;
  final KitchenUiScale uiScale;
  final bool showCardHighlight;
  final int activeQty;
  final int totalItems;
  final bool isLargeOrder;
  final String itemsSummary;
  final LocalKitchenActorProfile? primaryAccepted;
  final bool hasPending;
  final Color Function(LocalKitchenActorProfile actor) acceptColorOf;
  final String? actorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: PosQueueLayout.iconBox(context),
          height: PosQueueLayout.iconBox(context),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(PosQueueLayout.iconRadius(context)),
          ),
          child: Icon(
            Icons.restaurant_rounded,
            color: tone,
            size: PosQueueLayout.iconInner(context),
          ),
        ),
        SizedBox(width: PosQueueLayout.rowGutter(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitchenOrderNumberBadge(
                displayNumber: displayNumber,
                tone: tone,
                textScale: uiScale.itemTextScale,
              ),
              if (showCardHighlight) ...[
                const SizedBox(height: 8),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.deepOrange.withValues(alpha: 0.18),
                  side: BorderSide(color: Colors.deepOrange.shade400),
                  label: Text(
                    'Дозаказ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.deepOrange.shade900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  avatar: Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 16,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ],
              SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 8 : 10),
              Row(
                children: [
                  Icon(
                    showCardHighlight
                        ? Icons.restaurant_menu_rounded
                        : Icons.check_circle_rounded,
                    size: PosQueueLayout.metaIcon(context),
                    color: showCardHighlight
                        ? Colors.deepOrange.shade700
                        : Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      showCardHighlight
                          ? 'Готовить: $activeQty ${_kitchenQtyLabelRu(activeQty)}'
                          : isLargeOrder
                              ? 'Большой заказ · $totalItems поз.'
                              : itemsSummary,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: showCardHighlight
                            ? Colors.deepOrange.shade900
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize:
                            PosQueueLayout.shortestSide(context) < 600 ? 13 : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (orderTypeBadge != null) ...[
                const SizedBox(height: 6),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(orderTypeBadge!),
                  avatar: Icon(
                    orderTypeBadge == 'Доставка'
                        ? Icons.delivery_dining_rounded
                        : Icons.shopping_bag_outlined,
                    size: 16,
                    color: tone,
                  ),
                ),
              ],
              if (primaryAccepted != null && !hasPending && actorLabel != null) ...[
                const SizedBox(height: 8),
                KitchenItemChefStatusChip(
                  chefColor: acceptColorOf(primaryAccepted!),
                  icon: Icons.pan_tool_alt_rounded,
                  label: 'Заказ принят · $actorLabel',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _KitchenItemLineStyle {
  const _KitchenItemLineStyle({
    required this.tone,
    required this.uiScale,
    required this.acceptColorOf,
    required this.readyColorOf,
    required this.actors,
  });

  final Color tone;
  final KitchenUiScale uiScale;
  final Color Function(LocalKitchenActorProfile actor) acceptColorOf;
  final Color Function(LocalKitchenActorProfile actor) readyColorOf;
  final List<LocalKitchenActorProfile> actors;
}

class _KitchenItemLine extends StatelessWidget {
  const _KitchenItemLine({
    required this.item,
    required this.style,
    this.deemphasized = false,
    this.highlightAsNew = false,
  });

  final LocalKitchenQueueItem item;
  final _KitchenItemLineStyle style;
  final bool deemphasized;
  final bool highlightAsNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final st = item.kitchenLineStatus.toLowerCase();
    final qty = item.assemblyTitleWithStation();
    final acceptedByName = (item.kitchenAcceptedByUsername ?? '').trim();
    final readyByName = (item.kitchenReadyByUsername ?? '').trim();
    final acceptedActor = _findKitchenActor(style.actors, item.kitchenAcceptedByUserId);
    final readyActor = _findKitchenActor(style.actors, item.kitchenReadyByUserId);

    Color? chefAccent;
    IconData statusIcon;
    if (st == 'ready') {
      chefAccent =
          readyActor != null ? style.readyColorOf(readyActor) : Colors.green.shade600;
      statusIcon = Icons.check_circle_rounded;
    } else if (st == 'accepted' && acceptedActor != null) {
      chefAccent = style.acceptColorOf(acceptedActor);
      statusIcon = Icons.pan_tool_alt_rounded;
    } else {
      statusIcon =
          st == 'accepted' ? Icons.play_circle_outline_rounded : Icons.pending_outlined;
    }
    final lineColor = chefAccent ?? (st == 'ready' ? Colors.green.shade600 : style.tone);

    final statusChips = <Widget>[];
    if (st == 'accepted' && acceptedActor != null) {
      final chefColor = style.acceptColorOf(acceptedActor);
      final name =
          acceptedByName.isNotEmpty ? acceptedByName : _actorUiLabel(acceptedActor);
      statusChips.add(
        KitchenItemChefStatusChip(
          chefColor: chefColor,
          icon: Icons.pan_tool_alt_rounded,
          label: 'Принято · $name',
        ),
      );
    } else if (st == 'ready') {
      final chefColor = readyActor != null
          ? style.readyColorOf(readyActor)
          : Colors.green.shade600;
      final name = readyByName.isNotEmpty
          ? readyByName
          : (readyActor != null ? _actorUiLabel(readyActor) : '');
      statusChips.add(
        KitchenItemChefStatusChip(
          chefColor: chefColor,
          icon: Icons.check_circle_rounded,
          label: name.isNotEmpty ? 'Готово · $name' : 'Позиция готова',
        ),
      );
    }

    Widget itemColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (highlightAsNew && st == 'pending') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ГОТОВИТЬ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: PosQueueLayout.shortestSide(context) < 600 ? 3 : 4,
              ),
              child: Icon(
                statusIcon,
                size: PosQueueLayout.kitchenStatusIcon(context) * (deemphasized ? 0.9 : 1),
                color: lineColor,
              ),
            ),
            SizedBox(width: PosQueueLayout.rowGutter(context)),
            Expanded(
              child: Text(
                qty,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  fontSize: PosQueueLayout.itemLine(context) *
                      style.uiScale.itemTextScale *
                      (deemphasized ? 0.88 : 1),
                  color: deemphasized ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ],
        ),
        if (statusChips.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...statusChips,
        ],
      ],
    );

    if (highlightAsNew && st == 'pending') {
      itemColumn = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: Colors.deepOrange.shade600, width: 5)),
        ),
        child: itemColumn,
      );
    } else if (chefAccent != null && st != 'pending') {
      itemColumn = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: chefAccent.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: chefAccent, width: 5)),
        ),
        child: itemColumn,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: PosQueueLayout.itemRowSpacing(context)),
      child: deemphasized ? Opacity(opacity: 0.72, child: itemColumn) : itemColumn,
    );
  }
}

class _KitchenVirtualItemsList extends StatelessWidget {
  const _KitchenVirtualItemsList({
    required this.entries,
    required this.itemCount,
    required this.activeQty,
    required this.lineStyle,
    required this.showCardHighlight,
    required this.tone,
  });

  final List<_KitchenListEntry> entries;
  final int itemCount;
  final int activeQty;
  final _KitchenItemLineStyle lineStyle;
  final bool showCardHighlight;
  final Color tone;

  double _maxHeight(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final fraction = shortest < 600 ? 0.32 : 0.28;
    return (screenH * fraction).clamp(220.0, shortest < 600 ? 340.0 : 400.0);
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final useScroll = entries.length > 6;
    final maxH = _maxHeight(context);

    final list = ListView.builder(
      primary: false,
      shrinkWrap: !useScroll,
      padding: EdgeInsets.zero,
      physics: useScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntry(context, entries[index]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (useScroll)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Scrollbar(
              thumbVisibility: true,
              child: list,
            ),
          )
        else
          list,
        if (useScroll)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Прокрутите список · $itemCount поз.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildEntry(BuildContext context, _KitchenListEntry entry) {
    switch (entry.kind) {
      case _KitchenListEntryKind.followUpBanner:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.deepOrange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepOrange.shade400, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: Colors.deepOrange.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ДОЗАКАЗ — готовить только новое ($activeQty)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.deepOrange.shade900,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        );
      case _KitchenListEntryKind.stationHeader:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.local_dining_rounded, size: 20, color: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.stationLabel ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tone,
                      ),
                ),
              ),
            ],
          ),
        );
      case _KitchenListEntryKind.item:
        final item = entry.item;
        if (item == null) return const SizedBox.shrink();
        return _KitchenItemLine(
          item: item,
          style: lineStyle,
          deemphasized: entry.deemphasized,
          highlightAsNew: entry.highlightAsNew,
        );
      case _KitchenListEntryKind.readyGroup:
        return _KitchenReadyItemsCollapsible(
          items: entry.readyItems,
          lineStyle: lineStyle,
        );
    }
  }
}

class _KitchenReadyItemsCollapsible extends StatefulWidget {
  const _KitchenReadyItemsCollapsible({
    required this.items,
    required this.lineStyle,
  });

  final List<LocalKitchenQueueItem> items;
  final _KitchenItemLineStyle lineStyle;

  @override
  State<_KitchenReadyItemsCollapsible> createState() =>
      _KitchenReadyItemsCollapsibleState();
}

class _KitchenReadyItemsCollapsibleState extends State<_KitchenReadyItemsCollapsible> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final qty = widget.items.fold<int>(0, (sum, e) => sum + e.quantity);
    final useCompactSummary =
        !_expanded && widget.items.length >= kKitchenCompactReadyThreshold;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Уже готово ($qty) — не готовить',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: widget.items.length > kKitchenCompactReadyThreshold
                    ? SizedBox(
                        height: 220,
                        child: ListView.builder(
                          primary: false,
                          itemCount: widget.items.length,
                          itemBuilder: (context, index) => _KitchenItemLine(
                            item: widget.items[index],
                            style: widget.lineStyle,
                            deemphasized: true,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in widget.items)
                            _KitchenItemLine(
                              item: item,
                              style: widget.lineStyle,
                              deemphasized: true,
                            ),
                        ],
                      ),
              ),
            ] else if (useCompactSummary) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  _compactReadySummary(widget.items),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KitchenActorActionButton extends StatelessWidget {
  const _KitchenActorActionButton({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.actorLabel,
    required this.actionLabel,
    required this.onPressed,
    required this.compact,
    required this.minHeight,
    required this.fontSize,
    required this.iconSize,
    required this.verticalPadding,
  });

  final Color color;
  final Color onColor;
  final IconData icon;
  final String actorLabel;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool compact;
  final double minHeight;
  final double fontSize;
  final double iconSize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: onColor,
        minimumSize: Size(0, minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: verticalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    height: 1.15,
                  ),
                ),
                Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize * 0.93,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_KitchenListEntry> _buildKitchenCardEntries({
  required List<LocalKitchenQueueItem> activeItems,
  required List<LocalKitchenQueueItem> readyItems,
  required bool showCardHighlight,
  required bool showLineHighlight,
  required bool showStationHeaders,
  required bool showReadyCollapsed,
}) {
  final entries = <_KitchenListEntry>[];
  if (showCardHighlight) {
    entries.add(const _KitchenListEntry.followUpBanner());
  }

  final stationGroups = _groupKitchenItemsByStation(activeItems);
  for (var gi = 0; gi < stationGroups.length; gi++) {
    final group = stationGroups[gi];
    if (showStationHeaders) {
      entries.add(_KitchenListEntry.stationHeader(group.key));
    }
    for (final item in group.value) {
      entries.add(
        _KitchenListEntry.item(
          item,
          highlightAsNew:
              showLineHighlight && item.kitchenLineStatus.toLowerCase() == 'pending',
        ),
      );
    }
  }

  if (showReadyCollapsed) {
    entries.add(_KitchenListEntry.readyGroup(readyItems));
  } else if (readyItems.isNotEmpty && showLineHighlight) {
    for (final item in readyItems) {
      entries.add(_KitchenListEntry.item(item, deemphasized: true));
    }
  }

  return entries;
}

String _compactReadySummary(List<LocalKitchenQueueItem> items) {
  final parts = items
      .take(4)
      .map((e) => e.quantity > 1 ? '${e.quantity}× ${e.name}' : e.name)
      .toList(growable: false);
  if (items.length <= 4) return parts.join(', ');
  return '${parts.join(', ')} и ещё ${items.length - 4}';
}

Widget _layoutOrderActions(
  List<Widget> controls, {
  required bool stackVertically,
}) {
  if (controls.isEmpty) return const SizedBox.shrink();
  if (stackVertically) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < controls.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          controls[i],
        ],
      ],
    );
  }
  if (controls.length == 1) {
    return SizedBox(width: double.infinity, child: controls.first);
  }
  if (controls.length == 2) {
    return Row(
      children: [
        Expanded(child: controls[0]),
        const SizedBox(width: 10),
        Expanded(child: controls[1]),
      ],
    );
  }
  return Wrap(spacing: 8, runSpacing: 8, children: controls);
}

String _actorUiLabel(LocalKitchenActorProfile actor) {
  final buttonName = (actor.kitchenButtonName ?? '').trim();
  if (buttonName.isNotEmpty) return buttonName;
  final username = actor.username.trim();
  if (username.length <= 12) return username;
  final firstWord = username.split(RegExp(r'\s+')).first;
  if (firstWord.isNotEmpty && firstWord.length <= 12) return firstWord;
  return '${username.substring(0, 10)}…';
}

LocalKitchenActorProfile? _findKitchenActor(
  List<LocalKitchenActorProfile> actors,
  int? userId,
) {
  if (userId == null) return null;
  for (final actor in actors) {
    if (actor.id == userId) return actor;
  }
  return null;
}

String _kitchenStationGroupLabel(LocalKitchenQueueItem item) {
  final name = (item.kitchenStationName ?? '').trim();
  if (name.isNotEmpty) return name;
  final id = item.kitchenStationId;
  if (id != null) return 'Станция $id';
  return 'Без кухни';
}

List<MapEntry<String, List<LocalKitchenQueueItem>>> _groupKitchenItemsByStation(
  List<LocalKitchenQueueItem> items,
) {
  final map = <String, List<LocalKitchenQueueItem>>{};
  for (final item in items) {
    final key = _kitchenStationGroupLabel(item);
    map.putIfAbsent(key, () => []).add(item);
  }
  final keys = map.keys.toList()
    ..sort((a, b) {
      if (a == 'Без кухни') return 1;
      if (b == 'Без кухни') return -1;
      return a.compareTo(b);
    });
  return [for (final k in keys) MapEntry(k, map[k]!)];
}

bool _kitchenOrderHasPendingItems(List<LocalKitchenQueueItem> items) {
  return items.any((e) => e.kitchenLineStatus.toLowerCase() == 'pending');
}

bool _kitchenOrderAllReady(List<LocalKitchenQueueItem> items) {
  return items.isNotEmpty &&
      items.every((e) => e.kitchenLineStatus.toLowerCase() == 'ready');
}

bool _kitchenItemNeedsWork(LocalKitchenQueueItem item) {
  final st = item.kitchenLineStatus.toLowerCase();
  return st == 'pending' || st == 'accepted';
}

bool _kitchenItemIsReady(LocalKitchenQueueItem item) {
  return item.kitchenLineStatus.toLowerCase() == 'ready';
}

bool _kitchenOrderIsFollowUp(List<LocalKitchenQueueItem> items) {
  if (items.any(_kitchenItemIsReady) && items.any(_kitchenItemNeedsWork)) {
    return true;
  }
  final hasPending =
      items.any((e) => e.kitchenLineStatus.toLowerCase() == 'pending');
  final hasAccepted =
      items.any((e) => e.kitchenLineStatus.toLowerCase() == 'accepted');
  return hasPending && hasAccepted;
}

List<LocalKitchenQueueItem> _kitchenOrderActiveItems(List<LocalKitchenQueueItem> items) {
  final active = items.where(_kitchenItemNeedsWork).toList(growable: false);
  active.sort((a, b) {
    final aPending = a.kitchenLineStatus.toLowerCase() == 'pending' ? 0 : 1;
    final bPending = b.kitchenLineStatus.toLowerCase() == 'pending' ? 0 : 1;
    return aPending.compareTo(bPending);
  });
  return active;
}

List<LocalKitchenQueueItem> _kitchenOrderReadyItems(List<LocalKitchenQueueItem> items) {
  return items.where(_kitchenItemIsReady).toList(growable: false);
}

String _kitchenQtyLabelRu(int qty) {
  final mod10 = qty % 10;
  final mod100 = qty % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'позиций';
  if (mod10 == 1) return 'позицию';
  if (mod10 >= 2 && mod10 <= 4) return 'позиции';
  return 'позиций';
}

List<LocalKitchenActorProfile> _kitchenOrderReadyActors({
  required List<LocalKitchenQueueItem> items,
  required List<LocalKitchenActorProfile> actors,
}) {
  final ids = <int>{};
  for (final e in items) {
    if (e.kitchenLineStatus.toLowerCase() == 'accepted') {
      final id = e.kitchenAcceptedByUserId;
      if (id != null && id > 0) ids.add(id);
    }
  }
  return actors.where((a) => ids.contains(a.id)).toList(growable: false);
}

LocalKitchenActorProfile? _kitchenOrderPrimaryAcceptedActor({
  required List<LocalKitchenQueueItem> items,
  required List<LocalKitchenActorProfile> actors,
}) {
  final readyActors = _kitchenOrderReadyActors(items: items, actors: actors);
  if (readyActors.length == 1) return readyActors.first;
  return null;
}
