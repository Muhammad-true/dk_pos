import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snap = await context.read<LocalOrdersRepository>().fetchKitchenQueueDisplay();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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
    final more = o.items.length > maxLines ? ' +${o.items.length - maxLines}' : '';
    return '${parts.join(' · ')}$more';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);

    final preparing = _snapshot.preparing;
    final ready = _snapshot.readyForPickup;
    final allEmpty = preparing.isEmpty && ready.isEmpty && !_loading && _error == null;

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
        child: _loading && _snapshot.preparing.isEmpty && _snapshot.readyForPickup.isEmpty
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
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
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
                            for (final o in preparing) ...[
                              _QueueBoardCard(
                                order: o,
                                tone: _kTonePreparing,
                                summary: _linesSummary(o),
                                isDeliveryDemo: false,
                              ),
                              const SizedBox(height: 10),
                            ],
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
                            for (final o in ready) ...[
                              _QueueBoardCard(
                                order: o,
                                tone: _kToneReady,
                                summary: _linesSummary(o),
                                isDeliveryDemo: false,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
      ),
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              order.number,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: tone,
                letterSpacing: -0.5,
              ),
            ),
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
