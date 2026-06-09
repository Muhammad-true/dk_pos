import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_number_badge.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

/// Тона как у плиток рабочего места кассы (_WorkspaceActionCard).
const _kTonePickup = Color(0xFF5B8DEF);

String _expeditorOrderDisplayNumber(LocalKitchenQueueOrder order) {
  final number = order.number.trim();
  if (number.isEmpty) return number;
  final low = (order.orderType ?? '').trim().toLowerCase();
  if (low.contains('доставк') || low == 'delivery') return 'Д-$number';
  if (low.contains('самовывоз') ||
      low.contains('с собой') ||
      low == 'pickup' ||
      low == 'takeaway' ||
      low == 'take_away' ||
      low == 'to_go') {
    return 'С-$number';
  }
  return number;
}

String? _expeditorOrderTypeBadge(LocalKitchenQueueOrder order) {
  final low = (order.orderType ?? '').trim().toLowerCase();
  if (low.contains('доставк') || low == 'delivery') return 'Доставка';
  if (low.contains('самовывоз') ||
      low.contains('с собой') ||
      low == 'pickup' ||
      low == 'takeaway' ||
      low == 'take_away' ||
      low == 'to_go') {
    return 'Самовывоз';
  }
  return null;
}

LocalExpeditorQueueSnapshot _optimisticAfterHandoff({
  required LocalExpeditorQueueSnapshot snap,
  required String orderId,
  required String action,
}) {
  return LocalExpeditorQueueSnapshot(
    bundling: snap.bundling.where((o) => o.id != orderId).toList(growable: false),
    pickup: snap.pickup.where((o) => o.id != orderId).toList(growable: false),
  );
}

/// Очередь сборки/выдачи: одна кнопка на карточке, без дополнительных шагов.
class ExpeditorQueuePanel extends StatefulWidget {
  const ExpeditorQueuePanel({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  ExpeditorQueuePanelState createState() => ExpeditorQueuePanelState();
}

class ExpeditorQueuePanelState extends State<ExpeditorQueuePanel> {
  final _realtime = LocalOrdersRealtime();
  StreamSubscription<LocalOrdersRealtimeEvent>? _realtimeSub;
  LocalExpeditorQueueSnapshot _snapshot = const LocalExpeditorQueueSnapshot(
    bundling: [],
    pickup: [],
  );
  bool _loading = true;
  String? _busyOrderId;
  String? _error;

  String get _branchId => AppConfig.storeBranchId;

  @override
  void initState() {
    super.initState();
    _reload();
    _connectRealtime();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _realtime.dispose();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    await _realtimeSub?.cancel();
    try {
      await _realtime.connect(branchId: _branchId, clientType: 'expeditor');
      _realtimeSub = _realtime.events.listen((event) async {
        if (!mounted) return;
        final type = event.type;
        if (type == 'socket.done') {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          await _connectRealtime();
          return;
        }
        if (type == 'order.created' ||
            type == 'order.updated' ||
            type == 'order.status_changed') {
          await _reload(silent: true);
        }
      });
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) await _connectRealtime();
    }
  }

  /// Обновить список (кнопка «Обновить» на полном экране сборщика).
  Future<void> reloadFromAppBar() => _reload();

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snap = await context.read<LocalOrdersRepository>().fetchExpeditorQueue();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _handoff(String orderId, String action) async {
    if (_busyOrderId != null) return;
    final repo = context.read<LocalOrdersRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyOrderId = orderId);
    final previous = _snapshot;
    setState(() {
      _snapshot = _optimisticAfterHandoff(
        snap: _snapshot,
        orderId: orderId,
        action: action,
      );
    });
    try {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      await repo.handoffOrder(orderId: orderId, action: action);
      if (!mounted) return;
      setState(() => _busyOrderId = null);
      unawaited(_reload(silent: true));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshot = previous;
        _busyOrderId = null;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final pad = PosQueueLayout.listPadding(context, embedded: widget.embedded);
    final scheme = Theme.of(context).colorScheme;
    final gap = PosQueueLayout.cardGap(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: _SoftPanel(
            tone: scheme.error,
            child: Text(
              _error!,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ),
      );
    }

    final bundle = _snapshot.bundling;
    final pickup = _snapshot.pickup;
    final handoutQueue = [...bundle, ...pickup];
    final allEmpty = handoutQueue.isEmpty;
    final totalCount = handoutQueue.length;

    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (allEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: _SoftPanel(
                  tone: scheme.outline,
                  child: Text(
                    l10n.expeditorQueueAllEmpty,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            )
          else ...[
            if (!widget.embedded && PosQueueLayout.isPhone(context))
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                  child: _QueueSummaryStrip(
                    totalCount: totalCount,
                    pickupTone: _kTonePickup,
                    pickupLabel: l10n.expeditorSectionPickup,
                  ),
                ),
              ),
            if (handoutQueue.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, gap),
                  child: PosQueueSectionLabel(
                    label: l10n.expeditorSectionPickup,
                    tone: _kTonePickup,
                    count: handoutQueue.length,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                sliver: PosQueueLayout.kitchenGridColumns(context) <= 1
                    ? SliverList.separated(
                        itemCount: handoutQueue.length,
                        separatorBuilder: (_, __) => SizedBox(height: gap),
                        itemBuilder: (context, index) {
                          final o = handoutQueue[index];
                          return _ExpeditorOrderCard(
                            key: ValueKey('handout-${o.id}'),
                            order: o,
                            tone: _kTonePickup,
                            icon: Icons.takeout_dining_rounded,
                            actionLabel: l10n.expeditorHandOut,
                            requireAllItemsReadyForAction: true,
                            busy: _busyOrderId == o.id,
                            onAction: () => _handoff(o.id, 'hand_out'),
                          );
                        },
                      )
                    : SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              PosQueueLayout.kitchenGridColumns(context),
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          childAspectRatio: 0.58,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final o = handoutQueue[index];
                            return _ExpeditorOrderCard(
                              key: ValueKey('handout-${o.id}'),
                              order: o,
                              tone: _kTonePickup,
                              icon: Icons.takeout_dining_rounded,
                              actionLabel: l10n.expeditorHandOut,
                              requireAllItemsReadyForAction: true,
                              busy: _busyOrderId == o.id,
                              onAction: () => _handoff(o.id, 'hand_out'),
                            );
                          },
                          childCount: handoutQueue.length,
                        ),
                      ),
              ),
            ],
            if (widget.embedded && totalCount > 0)
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        ],
      ),
    );
  }
}

class _QueueSummaryStrip extends StatelessWidget {
  const _QueueSummaryStrip({
    required this.totalCount,
    required this.pickupTone,
    required this.pickupLabel,
  });

  final int totalCount;
  final Color pickupTone;
  final String pickupLabel;

  @override
  Widget build(BuildContext context) {
    return _SummaryChip(
      tone: pickupTone,
      label: pickupLabel,
      count: totalCount,
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.tone,
    required this.label,
    required this.count,
  });

  final Color tone;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: tone,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({required this.child, required this.tone});

  final Widget child;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

class _ExpeditorOrderCard extends StatefulWidget {
  const _ExpeditorOrderCard({
    super.key,
    required this.order,
    required this.tone,
    required this.icon,
    required this.actionLabel,
    required this.requireAllItemsReadyForAction,
    required this.busy,
    required this.onAction,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final IconData icon;
  final String actionLabel;
  final bool requireAllItemsReadyForAction;
  final bool busy;
  final VoidCallback onAction;

  @override
  State<_ExpeditorOrderCard> createState() => _ExpeditorOrderCardState();
}

class _ExpeditorOrderCardState extends State<_ExpeditorOrderCard> {
  bool _itemsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.appL10n;
    final isPhone = PosQueueLayout.isPhone(context);
    const maxItemLines = 14;
    final items = widget.order.items;
    final shown = items.take(maxItemLines).toList(growable: false);
    final hidden = items.length - shown.length;
    final readyCount = items.where((it) => it.isAssemblyLineReady).length;
    final allReady = items.isNotEmpty && readyCount == items.length;
    final canRunAction = !widget.requireAllItemsReadyForAction || allReady;
    final progress = items.isEmpty ? 0.0 : readyCount / items.length;
    final progressText = items.isEmpty ? '0/0' : '$readyCount/${items.length}';
    final typeBadge = _expeditorOrderTypeBadge(widget.order);
    final displayNumber = _expeditorOrderDisplayNumber(widget.order);
    final gutter = PosQueueLayout.rowGutter(context);
    final itemSp = PosQueueLayout.itemRowSpacing(context);

    final actionButton = _ExpeditorPrimaryAction(
      tone: widget.tone,
      icon: widget.icon,
      label: widget.actionLabel,
      busy: widget.busy,
      enabled: canRunAction,
      onPressed: widget.onAction,
    );

    return Material(
      color: scheme.surface,
      elevation: isPhone ? 1 : 0,
      shadowColor: widget.tone.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.tone.withValues(alpha: isPhone ? 0.34 : 0.20),
            width: isPhone ? 1.5 : 1,
          ),
        ),
        padding: PosQueueLayout.cardOuterPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitchenOrderNumberBadge(
                  displayNumber: displayNumber,
                  tone: widget.tone,
                ),
                SizedBox(width: gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (typeBadge != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _TypeBadge(label: typeBadge, tone: widget.tone),
                        ),
                      if (typeBadge != null) const SizedBox(height: 8),
                      _ReadyProgressRow(
                        allReady: allReady,
                        progressText: progressText,
                        itemCount: items.length,
                        progress: progress,
                        tone: widget.tone,
                        itemsSummary: l10n.expeditorItemsLine(items.length),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isPhone ? 12 : 14),
            if (isPhone) ...[
              actionButton,
              if (items.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ItemsToggle(
                  expanded: _itemsExpanded,
                  itemCount: items.length,
                  onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
                ),
              ],
            ] else ...[
              if (items.isNotEmpty) _buildItemsList(context, shown, hidden, itemSp, gutter),
              if (widget.requireAllItemsReadyForAction && !allReady) ...[
                const SizedBox(height: 8),
                Text(
                  'Ждём готовность всех кухонь ($progressText)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              actionButton,
            ],
            if (isPhone && _itemsExpanded && items.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildItemsList(context, shown, hidden, itemSp, gutter),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<LocalKitchenQueueItem> shown,
    int hidden,
    double itemSp,
    double gutter,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bullet = PosQueueLayout.isPhone(context) ? 7.0 : 8.0;

    return Column(
      children: [
        for (final it in shown)
          Padding(
            padding: EdgeInsets.only(bottom: itemSp),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: PosQueueLayout.bulletTopPad(context) - 1),
                  child: Icon(
                    it.isAssemblyLineReady
                        ? Icons.check_circle_rounded
                        : (it.kitchenLineStatus.toLowerCase() == 'accepted'
                            ? Icons.autorenew_rounded
                            : Icons.schedule_rounded),
                    size: bullet + 9,
                    color: it.isAssemblyLineReady
                        ? Colors.green.shade700
                        : (it.kitchenLineStatus.toLowerCase() == 'accepted'
                            ? scheme.tertiary
                            : scheme.primary),
                  ),
                ),
                SizedBox(width: gutter),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        fontSize: PosQueueLayout.itemLine(context),
                      ),
                      children: [
                        TextSpan(text: it.assemblyTitleWithStation()),
                        TextSpan(
                          text: ' — ${it.assemblyStatusShortRu}',
                          style: TextStyle(
                            color: it.isAssemblyLineReady
                                ? Colors.green.shade700
                                : (it.kitchenLineStatus.toLowerCase() == 'accepted'
                                    ? scheme.tertiary
                                    : scheme.primary),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '+$hidden поз.',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Доставка' ? Icons.delivery_dining_rounded : Icons.shopping_bag_outlined,
            size: 15,
            color: tone,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadyProgressRow extends StatelessWidget {
  const _ReadyProgressRow({
    required this.allReady,
    required this.progressText,
    required this.itemCount,
    required this.progress,
    required this.tone,
    required this.itemsSummary,
  });

  final bool allReady;
  final String progressText;
  final int itemCount;
  final double progress;
  final Color tone;
  final String itemsSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPhone = PosQueueLayout.isPhone(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              allReady ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
              size: PosQueueLayout.metaIcon(context) + (isPhone ? 1 : 0),
              color: allReady ? Colors.green.shade600 : scheme.tertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                itemCount == 0 ? itemsSummary : 'Готово $progressText',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: isPhone ? 14 : null,
                ),
              ),
            ),
          ],
        ),
        if (itemCount > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: isPhone ? 6 : 5,
              value: progress,
              backgroundColor: scheme.surfaceContainerHighest,
              color: allReady ? Colors.green.shade600 : tone,
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemsToggle extends StatelessWidget {
  const _ItemsToggle({
    required this.expanded,
    required this.itemCount,
    required this.onTap,
  });

  final bool expanded;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  expanded ? 'Скрыть позиции' : 'Позиции · $itemCount',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpeditorPrimaryAction extends StatelessWidget {
  const _ExpeditorPrimaryAction({
    required this.tone,
    required this.icon,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final Color tone;
  final IconData icon;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = PosQueueLayout.actionButtonHeight(context);
    final isPhone = PosQueueLayout.isPhone(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: (busy || !enabled) ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tone,
          disabledBackgroundColor: tone.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 16 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: isPhone ? 22 : 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isPhone ? 16 : 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
