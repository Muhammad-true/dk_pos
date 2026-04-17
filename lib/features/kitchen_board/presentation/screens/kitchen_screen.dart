import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/app/router/app_router.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

const _kToneCooking = Color(0xFFE4002B);
const _kToneWaiting = Color(0xFF5B8DEF);

@RoutePage()
class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  LocalKitchenQueueSnapshot _snapshot = const LocalKitchenQueueSnapshot(
    preparing: [],
    waitingOthers: [],
    readyForPickup: [],
  );
  final _realtime = LocalOrdersRealtime();
  final _tts = FlutterTts();
  final _audioPlayer = AudioPlayer();
  StreamSubscription<LocalOrdersRealtimeEvent>? _realtimeSub;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _timer;
  bool _queueInitialized = false;
  Set<String> _knownPreparingOrderIds = <String>{};
  bool _kitchenTtsEnabled = true;
  double _kitchenTtsRate = 0.48;
  String _kitchenTtsLocale = 'ru-RU';
  String? _kitchenTtsVoiceName;
  String? _kitchenSoundPath;
  LocalKitchenTodayStats _todayStats = const LocalKitchenTodayStats(
    itemsReady: 0,
    spentSeconds: 0,
  );
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadAudioSettings();
    _reload();
    _connectRealtime();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeSub?.cancel();
    _realtime.dispose();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String get _branchId {
    final v = dotenv.maybeGet('POS_BRANCH_ID')?.trim();
    if (v != null && v.isNotEmpty) return v;
    return 'branch_1';
  }

  Future<void> _loadAudioSettings() async {
    try {
      final settings = await context
          .read<LocalAudioSettingsRepository>()
          .fetch(branchId: _branchId);
      _kitchenTtsEnabled = settings.kitchenTtsEnabled;
      _kitchenTtsRate = settings.kitchenTtsRate;
      _kitchenTtsLocale = settings.kitchenTtsLocale;
      _kitchenTtsVoiceName = settings.kitchenTtsVoiceName;
      _kitchenSoundPath = settings.kitchenSoundPath;
    } catch (_) {
      _kitchenTtsEnabled = true;
      _kitchenTtsRate = 0.48;
      _kitchenTtsLocale = 'ru-RU';
      _kitchenTtsVoiceName = null;
      _kitchenSoundPath = null;
    }
    await _applyTtsConfig();
  }

  Future<void> _applyTtsConfig() async {
    try {
      await _tts.setLanguage(_kitchenTtsLocale);
      await _tts.setSpeechRate(_kitchenTtsRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      final voiceName = (_kitchenTtsVoiceName ?? '').trim();
      if (voiceName.isNotEmpty) {
        await _tts.setVoice({'name': voiceName, 'locale': _kitchenTtsLocale});
      }
    } catch (_) {
      // noop
    }
  }

  Future<void> _connectRealtime() async {
    await _realtimeSub?.cancel();
    try {
      await _realtime.connect(
        branchId: _branchId,
        clientType: 'kitchen',
      );
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
      if (mounted) {
        await _connectRealtime();
      }
    }
  }

  Future<void> _reload({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = true;
        _statsLoading = true;
        _error = null;
        _statsError = null;
      });
    }
    try {
      final repo = context.read<LocalOrdersRepository>();
      final snap = await repo.fetchKitchenQueueMy();
      final stats = await repo.fetchKitchenMyTodayStats(branchId: _branchId);
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _todayStats = stats;
        _statsLoading = false;
        _statsError = null;
        _loading = false;
      });
      await _announceNewKitchenOrders(snap);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
        _statsError = e.toString();
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatDurationShort(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$hч $mм';
  }

  Future<void> _announceNewKitchenOrders(LocalKitchenQueueSnapshot snap) async {
    final currentIds = snap.preparing.map((e) => e.id).toSet();
    if (!_queueInitialized) {
      _queueInitialized = true;
      _knownPreparingOrderIds = currentIds;
      return;
    }
    final newOrders = snap.preparing
        .where((o) => !_knownPreparingOrderIds.contains(o.id))
        .toList(growable: false);
    _knownPreparingOrderIds = currentIds;
    if (newOrders.isEmpty) return;

    for (final order in newOrders) {
      final text = _kitchenSpeakText(order);
      if (text.isEmpty) continue;
      try {
        if ((_kitchenSoundPath ?? '').trim().isNotEmpty) {
          final url = AppConfig.mediaUrl(_kitchenSoundPath);
          if (url.isNotEmpty) {
            await _audioPlayer.stop();
            await _audioPlayer.play(UrlSource(url));
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
        if (!_kitchenTtsEnabled) continue;
        await _tts.stop();
        await _tts.speak(text);
      } catch (_) {
        // noop
      }
    }
  }

  String _kitchenSpeakText(LocalKitchenQueueOrder order) {
    final parts = order.items
        .where((i) => i.name.trim().isNotEmpty)
        .map((i) => i.quantity > 1 ? '${i.quantity} ${i.name}' : i.name)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'Готовить заказ номер ${order.number}';
    }
    return 'Готовить заказ номер ${order.number}: ${parts.join(', ')}';
  }

  Future<void> _kitchenAction(LocalKitchenQueueOrder order, String action) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<LocalOrdersRepository>().updateKitchenProgress(
            orderId: order.id,
            action: action,
          );
      await _reload(silent: true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _kitchenTypeLabel(String? type) {
    switch (type) {
      case 'pizza':
        return 'Пицца';
      case 'inside':
        return 'Внутренняя';
      case 'outside':
        return 'Внешняя';
      default:
        return 'Кухня';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final user = context.watch<AuthBloc>().state.user;
    final stationName = user?.kitchenStationName ?? 'Кухня';
    final stationType = _kitchenTypeLabel(user?.kitchenStationType);
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Смена и статистика',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                stationName,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _statsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Сегодня приготовлено',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text('Товаров: ${_todayStats.itemsReady}'),
                            Text('Время: ${_formatDurationShort(_todayStats.spentSeconds)}'),
                            if (_statsError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statsError!,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _loading ? null : () => _reload(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Обновить статистику'),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stationName),
            Text(
              stationType,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          const PosThemeToggleIconButton(),
          IconButton(
            tooltip: l10n.queueBoardTooltipOpen,
            onPressed: () => context.router.push(const QueueBoardRoute()),
            icon: const Icon(Icons.display_settings_rounded),
          ),
          IconButton(
            tooltip: l10n.actionRefreshMenu,
            onPressed: _loading ? null : () => _reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton.icon(
            onPressed: _saving
                ? null
                : () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.actionExit),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView(
                      padding: EdgeInsets.all(
                        PosQueueLayout.listPadding(context, embedded: false),
                      ),
                      children: [
                        _KitchenSectionRow(
                          label: PosQueueSectionLabel(
                            label: l10n.kitchenSectionCooking,
                            tone: _kToneCooking,
                          ),
                          count: _snapshot.preparing.length,
                        ),
                        const SizedBox(height: 10),
                        if (_snapshot.preparing.isEmpty)
                          _KitchenEmptyPanel(text: l10n.kitchenEmptyCooking),
                        for (final order in _snapshot.preparing) ...[
                          _KitchenActiveCard(
                            order: order,
                            tone: _kToneCooking,
                            busy: _saving,
                            l10n: l10n,
                            onAccept: null,
                            onReady: order.stationCanMarkReady
                                ? () => _kitchenAction(order, 'ready')
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 8),
                        _KitchenSectionRow(
                          label: PosQueueSectionLabel(
                            label: l10n.kitchenSectionWaitingOthers,
                            tone: _kToneWaiting,
                          ),
                          count: _snapshot.waitingOthers.length,
                        ),
                        const SizedBox(height: 10),
                        if (_snapshot.waitingOthers.isEmpty)
                          _KitchenEmptyPanel(text: l10n.kitchenEmptyWaiting),
                        for (final order in _snapshot.waitingOthers) ...[
                          _KitchenWaitingPanel(
                            order: order,
                            tone: _kToneWaiting,
                            l10n: l10n,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}

extension on LocalKitchenQueueOrder {
  bool get stationCanMarkReady =>
      items.isNotEmpty &&
      items.any((i) {
        final s = i.kitchenLineStatus.toLowerCase();
        return s == 'pending' || s == 'accepted';
      });
}

class _KitchenSectionRow extends StatelessWidget {
  const _KitchenSectionRow({required this.label, required this.count});

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

class _KitchenEmptyPanel extends StatelessWidget {
  const _KitchenEmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      width: double.infinity,
      padding: PosQueueLayout.cardOuterPadding(context),
      decoration: BoxDecoration(
        color: outline.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: PosQueueLayout.shortestSide(context) < 600 ? 15 : 16,
            ),
      ),
    );
  }
}

class _KitchenActiveCard extends StatelessWidget {
  const _KitchenActiveCard({
    required this.order,
    required this.tone,
    required this.busy,
    required this.l10n,
    required this.onAccept,
    required this.onReady,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final bool busy;
  final AppLocalizations l10n;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final itemLines = order.items.map((e) {
      final st = e.kitchenLineStatus;
      final icon = st == 'ready'
          ? Icons.check_circle_rounded
          : st == 'accepted'
              ? Icons.play_circle_outline_rounded
              : Icons.pending_outlined;
      final lineColor = st == 'ready' ? Colors.green.shade600 : tone;
      final qty = e.assemblyTitleWithStation();
      return Padding(
        padding: EdgeInsets.only(bottom: PosQueueLayout.itemRowSpacing(context)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: PosQueueLayout.shortestSide(context) < 600 ? 3 : 4),
              child: Icon(
                icon,
                size: PosQueueLayout.kitchenStatusIcon(context),
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
                  fontSize: PosQueueLayout.itemLine(context),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();

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
                    Text(
                      l10n.kitchenOrderNumber(order.number),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tone,
                        letterSpacing: -0.5,
                        height: 1.05,
                        fontSize: PosQueueLayout.orderTitleKitchen(context),
                      ),
                    ),
                    SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 6 : 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: PosQueueLayout.metaIcon(context),
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.expeditorItemsLine(order.items.length),
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
          SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 12 : 14),
          ...itemLines,
          if (onAccept != null || onReady != null)
            SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 10 : 12),
          if (onAccept != null)
            FilledButton.tonal(
              onPressed: busy ? null : onAccept,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: PosQueueLayout.buttonVerticalPadding(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                l10n.kitchenAccept,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: PosQueueLayout.shortestSide(context) < 600 ? 14 : null,
                ),
              ),
            ),
          if (onAccept != null && onReady != null)
            SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 6 : 8),
          if (onReady != null)
            FilledButton(
              onPressed: busy ? null : onReady,
              style: FilledButton.styleFrom(
                backgroundColor: tone,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: PosQueueLayout.buttonVerticalPadding(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                l10n.kitchenReady,
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

class _KitchenWaitingPanel extends StatelessWidget {
  const _KitchenWaitingPanel({
    required this.order,
    required this.tone,
    required this.l10n,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      padding: PosQueueLayout.cardOuterPadding(context),
      child: Row(
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
              Icons.hourglass_top_rounded,
              color: tone,
              size: PosQueueLayout.iconInner(context),
            ),
          ),
          SizedBox(width: PosQueueLayout.rowGutter(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.kitchenOrderNumber(order.number),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tone,
                    letterSpacing: -0.5,
                    height: 1.05,
                    fontSize: PosQueueLayout.orderTitleKitchen(context),
                  ),
                ),
                SizedBox(height: PosQueueLayout.shortestSide(context) < 600 ? 8 : 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade600,
                      size: PosQueueLayout.kitchenStatusIcon(context),
                    ),
                    SizedBox(width: PosQueueLayout.shortestSide(context) < 600 ? 8 : 10),
                    Expanded(
                      child: Text(
                        l10n.kitchenWaitingHint,
                        style: theme.textTheme.titleMedium?.copyWith(
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          fontSize: PosQueueLayout.waitingHint(context),
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
    );
  }
}
