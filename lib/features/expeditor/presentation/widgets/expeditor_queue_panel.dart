import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

/// Тона как у плиток рабочего места кассы (_WorkspaceActionCard).
const _kToneBundle = Color(0xFF24B47E);
const _kTonePickup = Color(0xFF5B8DEF);

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
  bool _busy = false;
  String? _error;

  String get _branchId {
    final v = dotenv.maybeGet('POS_BRANCH_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'branch_1';
  }

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
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<LocalOrdersRepository>().handoffOrder(orderId: orderId, action: action);
      await _reload(silent: true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final pad = PosQueueLayout.listPadding(context, embedded: widget.embedded);
    final scheme = Theme.of(context).colorScheme;

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
    final allEmpty = bundle.isEmpty && pickup.isEmpty;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          if (allEmpty)
            _SoftPanel(
              tone: scheme.outline,
              child: Text(
                l10n.expeditorQueueAllEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else ...[
            if (bundle.isNotEmpty) ...[
              PosQueueSectionLabel(label: l10n.expeditorSectionBundling, tone: _kToneBundle),
              const SizedBox(height: 10),
              for (final o in bundle) ...[
                _ExpeditorOrderCard(
                  order: o,
                  tone: _kToneBundle,
                  icon: Icons.inventory_2_outlined,
                  actionLabel: l10n.expeditorConfirmReady,
                  requireAllItemsReadyForAction: true,
                  busy: _busy,
                  onAction: () => _handoff(o.id, 'confirm_ready'),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (pickup.isNotEmpty) ...[
              if (bundle.isNotEmpty) const SizedBox(height: 8),
              PosQueueSectionLabel(label: l10n.expeditorSectionPickup, tone: _kTonePickup),
              const SizedBox(height: 10),
              for (final o in pickup) ...[
                _ExpeditorOrderCard(
                  order: o,
                  tone: _kTonePickup,
                  icon: Icons.takeout_dining_rounded,
                  actionLabel: l10n.expeditorHandOut,
                  requireAllItemsReadyForAction: false,
                  busy: _busy,
                  onAction: () => _handoff(o.id, 'hand_out'),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
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

class _ExpeditorOrderCard extends StatelessWidget {
  const _ExpeditorOrderCard({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.appL10n;
    const maxItemLines = 14;
    final items = order.items;
    final shown = items.take(maxItemLines).toList(growable: false);
    final hidden = items.length - shown.length;
    final readyCount = items.where((it) => it.isAssemblyLineReady).length;
    final allReady = items.isNotEmpty && readyCount == items.length;
    final canRunAction = !requireAllItemsReadyForAction || allReady;
    final progressText = items.isEmpty
        ? '0/0'
        : '$readyCount/${items.length}';
    final box = PosQueueLayout.iconBox(context);
    final iSz = PosQueueLayout.iconInner(context);
    final gutter = PosQueueLayout.rowGutter(context);
    final itemSp = PosQueueLayout.itemRowSpacing(context);
    final bullet = PosQueueLayout.shortestSide(context) < 600 ? 7.0 : 8.0;

    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.20)),
      ),
      padding: PosQueueLayout.cardOuterPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(PosQueueLayout.iconRadius(context)),
                ),
                child: Icon(icon, color: tone, size: iSz),
              ),
              SizedBox(width: gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.kitchenOrderNumber(order.number),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tone,
                        letterSpacing: -0.5,
                        height: 1.05,
                        fontSize: PosQueueLayout.orderTitleExpeditor(context),
                      ),
                    ),
                    SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 8 : 10),
                    Row(
                      children: [
                        Icon(
                          allReady
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_bottom_rounded,
                          size: PosQueueLayout.metaIcon(context),
                          color: allReady ? Colors.green.shade600 : scheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l10n.expeditorItemsLine(order.items.length)} • готово $progressText',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: PosQueueLayout.shortestSide(context) < 600 ? 13 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (items.isEmpty) ...[
            SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 10 : 12),
            Text(
              '—',
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: PosQueueLayout.itemLine(context),
              ),
            ),
          ] else ...[
            SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 12 : 14),
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            fontSize: PosQueueLayout.itemLine(context),
                            color: theme.textTheme.titleLarge?.color,
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$hidden',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: PosQueueLayout.itemLine(context) - 1,
                  ),
                ),
              ),
          ],
          SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 14 : 16),
          if (requireAllItemsReadyForAction && !allReady) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ждём готовность всех кухонь ($progressText)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          FilledButton(
            onPressed: (busy || !canRunAction) ? null : onAction,
            style: FilledButton.styleFrom(
              backgroundColor: tone,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: PosQueueLayout.buttonVerticalPadding(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              actionLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: PosQueueLayout.shortestSide(context) < 600 ? 14 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
