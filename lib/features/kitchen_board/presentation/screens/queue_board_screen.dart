import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/network_error_message.dart';
import 'package:dk_pos/core/logging/pos_perf_helpers.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_header_labels.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_number_badge.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/data/local_tv_display_queue_ws_patch.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _kTonePreparing = Color(0xFFE4002B);
const _kToneReady = Color(0xFF24B47E);

@RoutePage()
class QueueBoardScreen extends StatefulWidget {
  const QueueBoardScreen({super.key});

  @override
  State<QueueBoardScreen> createState() => _QueueBoardScreenState();
}

class _QueueBoardScreenState extends State<QueueBoardScreen> {
  LocalKitchenQueueSnapshot _snapshot = const LocalKitchenQueueSnapshot(
    preparing: [],
    waitingOthers: [],
    readyForPickup: [],
  );
  bool _loading = true;
  String? _error;
  Timer? _timer;
  Timer? _reloadDebounce;
  Timer? _realtimeReconnectTimer;
  final LocalOrdersRealtime _realtime = LocalOrdersRealtime.instance;
  bool _realtimeAcquired = false;
  StreamSubscription<LocalOrdersRealtimeEvent>? _realtimeSub;
  bool _realtimeConnected = false;
  bool _reloadInFlight = false;

  String get _branchId => AppConfig.storeBranchId;

  @override
  void initState() {
    super.initState();
    _reload();
    _connectRealtime();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_realtimeConnected) _scheduleReload(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reloadDebounce?.cancel();
    _realtimeReconnectTimer?.cancel();
    _realtimeSub?.cancel();
    if (_realtimeAcquired) {
      _realtimeAcquired = false;
      unawaited(_realtime.release());
    }
    super.dispose();
  }

  void _scheduleReload({bool silent = true, bool immediate = false}) {
    _reloadDebounce?.cancel();
    if (immediate) {
      if (mounted) unawaited(_reload(silent: silent));
      return;
    }
    _reloadDebounce = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) unawaited(_reload(silent: silent));
    });
  }

  void _verifyQueueRevision(Map<String, dynamic> payload) {
    // revision в hello/pong — для диагностики; resync делаем при miss patch.
    final rev = payload['queueRevision'] ?? payload['queue_revision'];
    if (rev is int && rev > 0) {
      /* keep for future gap-detect */
    }
  }

  bool _applyTvQueueWsPatch(Map<String, dynamic> payload) {
    final patches = parseTvDisplayQueuePatches(payload['tvQueuePatches']);
    if (patches.isEmpty) return false;
    final revRaw = payload['queueRevision'] ?? payload['queue_revision'];
    final rev = revRaw is int ? revRaw : int.tryParse(revRaw?.toString() ?? '');
    final next = applyTvDisplayQueuePatches(
      _snapshot,
      patches,
      queueRevision: rev,
    );
    if (!mounted) return true;
    setState(() {
      _snapshot = next;
      _loading = false;
      _error = null;
    });
    AppFileLogger.instance.info(
      'queue_board_ws',
      'tv patch orders=${patches.map((e) => e.orderId).join(',')}',
    );
    return true;
  }

  Future<void> _connectRealtime() async {
    _realtimeReconnectTimer?.cancel();
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    try {
      if (!_realtimeAcquired) {
        await _realtime.acquire(branchId: _branchId, clientType: 'kitchen');
        _realtimeAcquired = true;
      } else {
        await _realtime.connect(branchId: _branchId, clientType: 'kitchen');
      }
    } catch (e, st) {
      AppFileLogger.instance.error('queue_board_ws', 'connect failed', e, st);
      _scheduleRealtimeReconnect();
      return;
    }
    _realtimeSub = _realtime.events.listen(
      (event) async {
        if (!mounted) return;
        final type = event.type;
        if (type == 'hello') {
          _reconnectAttempts = 0;
          _verifyQueueRevision(event.payload);
          setState(() => _realtimeConnected = true);
          return;
        }
        if (type == 'socket.done') {
          setState(() => _realtimeConnected = false);
          _scheduleRealtimeReconnect();
          return;
        }
        if (type == 'pong') {
          _verifyQueueRevision(event.payload);
          return;
        }
        if (type == 'kitchen.queue_changed') {
          _verifyQueueRevision(event.payload);
          // Патчи очереди — без full GET (раньше каждое событие долбило /queue).
          if (!_applyTvQueueWsPatch(event.payload)) {
            _scheduleReload(silent: true);
          }
        }
        // order.* / payment.* игнорируем — ждём kitchen.queue_changed
      },
      onError: (Object e, StackTrace st) {
        AppFileLogger.instance.error('queue_board_ws', 'stream error', e, st);
        if (mounted) setState(() => _realtimeConnected = false);
        _scheduleRealtimeReconnect();
      },
    );
  }

  int _reconnectAttempts = 0;

  void _scheduleRealtimeReconnect() {
    _realtimeReconnectTimer?.cancel();
    final attempt = _reconnectAttempts < 6 ? _reconnectAttempts : 6;
    final baseMs = 2500;
    final delayMs =
        (baseMs * (1 << attempt)) + (DateTime.now().millisecond % 1500);
    _reconnectAttempts++;

    _realtimeReconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) unawaited(_connectRealtime());
    });
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted || _reloadInFlight) return;
    _reloadInFlight = true;
    final started = DateTime.now();
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snap = await context
          .read<LocalOrdersRepository>()
          .fetchKitchenQueueDisplay();
      if (!mounted) return;
      if (snap.queueRevision != null) {}
      if (kitchenSnapshotChanged(_snapshot, snap) || !silent) {
        setState(() {
          _snapshot = snap;
          _loading = false;
          _error = null;
        });
      } else {
        _loading = false;
      }
      AppFileLogger.instance.slow(
        'queue_board',
        'reload preparing=${snap.preparing.length} ready=${snap.readyForPickup.length}',
        DateTime.now().difference(started).inMilliseconds,
      );
    } catch (e) {
      if (!mounted) return;
      AppFileLogger.instance.error('queue_board', 'reload failed', e);
      setState(() {
        _loading = false;
        _error = formatNetworkErrorMessage(e);
      });
    } finally {
      _reloadInFlight = false;
    }
  }

  static String _linesSummary(LocalKitchenQueueOrder o) {
    if (o.items.isEmpty) return '—';
    final parts = <String>[];
    const maxLines = 4;
    for (var i = 0; i < o.items.length && i < maxLines; i++) {
      final it = o.items[i];
      parts.add('${it.assemblyTitleWithStation()} ${it.assemblyStatusShortRu}');
    }
    final more = o.items.length > maxLines
        ? ' +${o.items.length - maxLines}'
        : '';
    return '${parts.join(' · ')}$more';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);

    final preparing = _snapshot.preparing;
    final ready = _snapshot.readyForPickup;
    final allEmpty =
        preparing.isEmpty && ready.isEmpty && !_loading && _error == null;

    return Scaffold(
      appBar: AppBar(
        leading: context.router.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.router.maybePop(),
              )
            : null,
        title: Text(l10n.queueBoardTitle),
        actions: [
          const PosThemeToggleIconButton(),
          IconButton(
            tooltip: l10n.actionRefreshMenu,
            onPressed: _loading ? null : () => _reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: posWorkspaceBodyGradient(theme),
          ),
        ),
        child:
            _loading &&
                _snapshot.preparing.isEmpty &&
                _snapshot.readyForPickup.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (allEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          l10n.queueBoardEmpty,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else ...[
                      if (preparing.isNotEmpty) ...[
                        _SectionRow(
                          label: PosQueueSectionLabel(
                            label: l10n.queueBoardSectionPreparing,
                            tone: _kTonePreparing,
                          ),
                          count: preparing.length,
                        ),
                        const SizedBox(height: 10),
                        _QueueBoardOrdersGrid(
                          orders: preparing,
                          tone: _kTonePreparing,
                          linesSummary: _linesSummary,
                        ),
                      ],
                      if (ready.isNotEmpty) ...[
                        if (preparing.isNotEmpty) const SizedBox(height: 8),
                        _SectionRow(
                          label: PosQueueSectionLabel(
                            label: l10n.queueBoardSectionReady,
                            tone: _kToneReady,
                          ),
                          count: ready.length,
                        ),
                        const SizedBox(height: 10),
                        _QueueBoardOrdersGrid(
                          orders: ready,
                          tone: _kToneReady,
                          linesSummary: _linesSummary,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _QueueBoardOrdersGrid extends StatelessWidget {
  const _QueueBoardOrdersGrid({
    required this.orders,
    required this.tone,
    required this.linesSummary,
  });

  final List<LocalKitchenQueueOrder> orders;
  final Color tone;
  final String Function(LocalKitchenQueueOrder) linesSummary;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = PosQueueLayout.kitchenGridColumns(context);
        if (cols <= 1) {
          return Column(
            children: [
              for (var i = 0; i < orders.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _QueueBoardCard(
                  order: orders[i],
                  tone: tone,
                  summary: linesSummary(orders[i]),
                  isDeliveryDemo: false,
                ),
              ],
            ],
          );
        }

        const gap = 10.0;
        final cardWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final o in orders)
              SizedBox(
                width: cardWidth,
                child: _QueueBoardCard(
                  order: o,
                  tone: tone,
                  summary: linesSummary(o),
                  isDeliveryDemo: false,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.label, required this.count});

  final Widget label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _QueueBoardCard extends StatelessWidget {
  const _QueueBoardCard({
    required this.order,
    required this.tone,
    required this.summary,
    required this.isDeliveryDemo,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final String summary;
  final bool isDeliveryDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.appL10n;

    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitchenOrderNumberBadge(
            displayNumber: kitchenOrderDisplayNumber(order),
            tone: tone,
            orderTypeLabel: kitchenOrderTypeHeadlineRu(order),
            tableHeadline: kitchenTableHeadlineRu(order),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                if (isDeliveryDemo) ...[
                  const SizedBox(height: 6),
                  Icon(
                    Icons.delivery_dining_rounded,
                    size: 18,
                    color: const Color(0xFF4FC3F7),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  l10n.expeditorItemsLine(order.items.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
