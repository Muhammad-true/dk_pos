import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/app/router/app_router.dart';
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

String _actorUiLabel(LocalKitchenActorProfile actor) {
  final buttonName = (actor.kitchenButtonName ?? '').trim();
  if (buttonName.isNotEmpty) return buttonName;
  final username = actor.username.trim();
  if (username.length <= 12) return username;
  final firstWord = username.split(RegExp(r'\s+')).first;
  if (firstWord.isNotEmpty && firstWord.length <= 12) return firstWord;
  return '${username.substring(0, 10)}…';
}

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
  FlutterTts? _tts;
  AudioPlayer? _audioPlayer;
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
  String _effectiveKitchenTtsLocale = 'ru-RU';
  String? _kitchenTtsVoiceName;
  String? _kitchenSoundPath;
  LocalKitchenTodayStats _todayStats = const LocalKitchenTodayStats(
    itemsReady: 0,
    spentSeconds: 0,
  );
  bool _statsLoading = true;
  String? _statsError;
  List<LocalKitchenActorProfile> _kitchenActors = const [];
  bool _largeTouchMode = false;
  bool get _disableKitchenAudioStackOnWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _largeTouchMode = true;
    if (!_disableKitchenAudioStackOnWindows) {
      _tts = FlutterTts();
      _audioPlayer = AudioPlayer();
      _loadAudioSettings();
    }
    _reload();
    _connectRealtime();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeSub?.cancel();
    _realtimeSub = null;
    // Защищаем dispose от фоновых ошибок плагинов/сокета,
    // чтобы выход не завершал все приложение.
    _realtime.dispose().catchError((_) {});
    if (!_disableKitchenAudioStackOnWindows) {
      _tts?.stop().catchError((_) {});
      _audioPlayer?.dispose().catchError((_) {});
    }
    super.dispose();
  }

  String get _branchId => AppConfig.storeBranchId;

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
    if (_disableKitchenAudioStackOnWindows) return;
    final tts = _tts;
    if (tts == null) return;
    final rate = _kitchenTtsRate.clamp(0.2, 1.2);
    final locale = _kitchenTtsLocale.trim().isEmpty ? 'ru-RU' : _kitchenTtsLocale.trim();
    try {
      try {
        await tts.awaitSpeakCompletion(true);
      } catch (_) {
        // На некоторых платформах может быть не реализовано.
      }
      _effectiveKitchenTtsLocale = await _resolveBestLocale(locale);
      try {
        await tts.setLanguage(_effectiveKitchenTtsLocale);
      } catch (_) {
        // На части устройств заявленный голос/локаль отсутствует.
        await tts.setLanguage('ru-RU');
        _effectiveKitchenTtsLocale = 'ru-RU';
      }
      await tts.setSpeechRate(rate);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      final voiceName = (_kitchenTtsVoiceName ?? '').trim();
      if (voiceName.isNotEmpty) {
        try {
          await tts.setVoice({'name': voiceName, 'locale': _effectiveKitchenTtsLocale});
        } catch (_) {
          // Оставляем системный голос по умолчанию.
        }
      }
    } catch (_) {
      // noop
    }
  }

  Future<String> _resolveBestLocale(String preferred) async {
    final tts = _tts;
    if (tts == null) return preferred;
    try {
      final langs = await tts.getLanguages;
      if (langs is! List) return preferred;
      final normalized = langs.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (normalized.isEmpty) return preferred;
      final direct = normalized.firstWhere(
        (l) => l.toLowerCase() == preferred.toLowerCase(),
        orElse: () => '',
      );
      if (direct.isNotEmpty) return direct;
      const ruPriority = ['ru-RU', 'ru_RU', 'ru'];
      for (final candidate in ruPriority) {
        final hit = normalized.firstWhere(
          (l) => l.toLowerCase() == candidate.toLowerCase(),
          orElse: () => '',
        );
        if (hit.isNotEmpty) return hit;
      }
      final ruLike = normalized.firstWhere(
        (l) => l.toLowerCase().startsWith('ru'),
        orElse: () => '',
      );
      if (ruLike.isNotEmpty) return ruLike;
      return preferred;
    } catch (_) {
      return preferred;
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
      }, onError: (Object _, StackTrace __) async {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await _connectRealtime();
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
    final currentUserId = context.read<AuthBloc>().state.user?.id;
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
      List<LocalKitchenActorProfile> actors = _kitchenActors;
      try {
        actors = await repo.fetchKitchenTeamMyStation();
      } catch (_) {
        // Для совместимости со старыми API не блокируем загрузку экрана.
      }
      if (currentUserId != null) {
        actors = actors
            .where((a) => a.id != currentUserId)
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        _todayStats = stats;
        _kitchenActors = actors;
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
    // На Windows desktop вызовы TTS/Audio иногда приводят к нативному падению
    // при приходе нового заказа. Оставляем мгновенное обновление списка заказов,
    // но отключаем озвучку ради стабильности кухни.
    if (_disableKitchenAudioStackOnWindows) {
      return;
    }
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
        final player = _audioPlayer;
        final tts = _tts;
        if ((_kitchenSoundPath ?? '').trim().isNotEmpty) {
          final url = AppConfig.mediaUrl(_kitchenSoundPath);
          if (url.isNotEmpty && player != null) {
            await player.stop();
            await player.play(UrlSource(url));
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
        if (!_kitchenTtsEnabled || tts == null) continue;
        await tts.stop();
        await tts.speak(text);
      } catch (_) {
        // noop
      }
    }
  }

  String _kitchenSpeakText(LocalKitchenQueueOrder order) {
    final number = _speakableOrderNumber(order.number);
    if (number.isNotEmpty) {
      return 'Новый заказ. Номер $number. Удачной смены!';
    }
    return 'Новый заказ. Удачной смены!';
  }

  String _speakableOrderNumber(String raw) {
    final source = raw.trim();
    if (source.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      final isAsciiLetter =
          (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90) ||
          (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);
      final isDigit = ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
      if (isDigit || isAsciiLetter) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(ch);
      } else if (ch == '-' || ch == '_' || ch == '/' || ch == '.') {
        if (buf.isNotEmpty) buf.write(' ');
      } else {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(ch);
      }
    }
    final normalized = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? source : normalized;
  }

  Future<void> _kitchenAction({
    required LocalKitchenQueueOrder order,
    required LocalKitchenQueueItem item,
    required LocalKitchenActorProfile actor,
    required String action,
  }) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<LocalOrdersRepository>().updateKitchenProgress(
            orderId: order.id,
            action: action,
            actorUserId: actor.id,
            menuItemId: item.menuItemId,
          );
      await HapticFeedback.lightImpact();
      final actorLabel = _actorUiLabel(actor);
      final actionLabel = action == 'ready' ? 'Готово' : 'Принять';
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text('${item.name}: $actorLabel · $actionLabel'),
        ),
      );
      await _reload(silent: true);
    } catch (e) {
      await HapticFeedback.mediumImpact();
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

  Color _resolveAcceptButtonColor(String? colorHex) {
    final parsed = _parseHexColor(colorHex);
    return parsed ?? const Color(0xFFE53935);
  }

  Color _resolveReadyButtonColor(Color acceptColor) {
    return Color.lerp(acceptColor, Colors.black, 0.18) ?? const Color(0xFF2E7D32);
  }

  Color _buttonOnColor(Color background) {
    return background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
  }

  Color? _parseHexColor(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;
    final normalized = v.startsWith('#') ? v.substring(1) : v;
    if (normalized.length != 6) return null;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  Color _actorAcceptColor(LocalKitchenActorProfile actor) =>
      _resolveAcceptButtonColor(actor.kitchenButtonColorHex);

  Color _actorReadyColor(LocalKitchenActorProfile actor) =>
      _resolveReadyButtonColor(_actorAcceptColor(actor));

  Future<void> _requestLogoutWithConfirm() async {
    if (!mounted) return;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Перейти к экрану входа?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    setState(() => _saving = true);
    context.read<AuthBloc>().add(const AuthLogoutRequested());
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
        automaticallyImplyLeading: false,
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
          IconButton(
            tooltip: _largeTouchMode ? 'Обычный режим' : 'Крупные кнопки',
            onPressed: () => setState(() => _largeTouchMode = !_largeTouchMode),
            icon: Icon(
              _largeTouchMode
                  ? Icons.touch_app_rounded
                  : Icons.touch_app_outlined,
            ),
          ),
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
                : _requestLogoutWithConfirm,
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
                        _KitchenActionLegend(
                          actors: _kitchenActors,
                          acceptColorOf: _actorAcceptColor,
                          readyColorOf: _actorReadyColor,
                          onColorOf: _buttonOnColor,
                          l10n: l10n,
                        ),
                        const SizedBox(height: 12),
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
                            actors: _kitchenActors,
                            acceptColorOf: _actorAcceptColor,
                            readyColorOf: _actorReadyColor,
                            onColorOf: _buttonOnColor,
                            largeTouchMode: _largeTouchMode,
                            onAction: ({required item, required actor, required action}) =>
                                _kitchenAction(
                                  order: order,
                                  item: item,
                                  actor: actor,
                                  action: action,
                                ),
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

class _KitchenActionLegend extends StatelessWidget {
  const _KitchenActionLegend({
    required this.actors,
    required this.acceptColorOf,
    required this.readyColorOf,
    required this.onColorOf,
    required this.l10n,
  });

  final List<LocalKitchenActorProfile> actors;
  final Color Function(LocalKitchenActorProfile actor) acceptColorOf;
  final Color Function(LocalKitchenActorProfile actor) readyColorOf;
  final Color Function(Color background) onColorOf;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Повара этой кухни',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (actors.isEmpty)
            Text(
              'Не найдено ни одного повара для этой кухни',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actors.map((actor) {
                final acceptColor = acceptColorOf(actor);
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: acceptColor,
                    child: Icon(
                      Icons.person_rounded,
                      color: onColorOf(acceptColor),
                      size: 15,
                    ),
                  ),
                  label: Text(
                    _actorUiLabel(actor),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          const SizedBox(height: 6),
          Text(
            'Нажмите цвет повара на позиции: сначала Принять, потом Готово.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.pan_tool_alt_rounded, size: 16),
                label: const Text('Принять'),
              ),
              Chip(
                avatar: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Готово'),
              ),
            ],
          ),
        ],
      ),
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
    required this.actors,
    required this.acceptColorOf,
    required this.readyColorOf,
    required this.onColorOf,
    required this.largeTouchMode,
    required this.onAction,
  });

  final LocalKitchenQueueOrder order;
  final Color tone;
  final bool busy;
  final AppLocalizations l10n;
  final List<LocalKitchenActorProfile> actors;
  final Color Function(LocalKitchenActorProfile actor) acceptColorOf;
  final Color Function(LocalKitchenActorProfile actor) readyColorOf;
  final Color Function(Color background) onColorOf;
  final bool largeTouchMode;
  final Future<void> Function({
    required LocalKitchenQueueItem item,
    required LocalKitchenActorProfile actor,
    required String action,
  }) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = PosQueueLayout.shortestSide(context) < 600;
    final actionButtonVerticalPadding = PosQueueLayout.buttonVerticalPadding(context) + (largeTouchMode ? 8 : 4);
    final actionFontSize = largeTouchMode ? (compact ? 16.0 : 17.0) : (compact ? 14.0 : 15.0);
    final actionMinHeight = largeTouchMode ? (compact ? 58.0 : 64.0) : (compact ? 46.0 : 52.0);

    final itemLines = order.items.map((e) {
      final st = e.kitchenLineStatus.toLowerCase();
      final icon = st == 'ready'
          ? Icons.check_circle_rounded
          : st == 'accepted'
              ? Icons.play_circle_outline_rounded
              : Icons.pending_outlined;
      final lineColor = st == 'ready' ? Colors.green.shade600 : tone;
      final qty = e.assemblyTitleWithStation();
      final acceptedById = e.kitchenAcceptedByUserId;
      final acceptedByName = (e.kitchenAcceptedByUsername ?? '').trim();
      final readyByName = (e.kitchenReadyByUsername ?? '').trim();
      LocalKitchenActorProfile? acceptedActor;
      if (acceptedById != null) {
        for (final actor in actors) {
          if (actor.id == acceptedById) {
            acceptedActor = actor;
            break;
          }
        }
      }

      Widget buildAcceptButton(LocalKitchenActorProfile actor) {
        final color = acceptColorOf(actor);
        final on = onColorOf(color);
        return SizedBox(
          height: actionMinHeight,
          child: FilledButton.icon(
          onPressed: busy
              ? null
              : () {
                  unawaited(onAction(item: e, actor: actor, action: 'accept'));
                },
          icon: const Icon(Icons.pan_tool_alt_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: on,
            minimumSize: Size(0, actionMinHeight),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: actionButtonVerticalPadding,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          label: Text(
            '${_actorUiLabel(actor)} · Принять',
            style: theme.textTheme.labelLarge?.copyWith(
              color: on,
              fontWeight: FontWeight.w800,
              fontSize: actionFontSize,
            ),
          ),
          ),
        );
      }

      Widget buildReadyButton(LocalKitchenActorProfile actor) {
        final color = readyColorOf(actor);
        final on = onColorOf(color);
        return SizedBox(
          height: actionMinHeight,
          child: FilledButton.icon(
          onPressed: busy
              ? null
              : () {
                  unawaited(onAction(item: e, actor: actor, action: 'ready'));
                },
          icon: const Icon(Icons.check_circle_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: on,
            minimumSize: Size(0, actionMinHeight),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: actionButtonVerticalPadding,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          label: Text(
            '${_actorUiLabel(actor)} · Готово',
            style: theme.textTheme.labelLarge?.copyWith(
              color: on,
              fontWeight: FontWeight.w800,
              fontSize: actionFontSize,
            ),
          ),
          ),
        );
      }

      final controls = <Widget>[];
      if (st == 'pending') {
        controls.addAll(actors.map(buildAcceptButton));
      } else if (st == 'accepted') {
        if (acceptedActor != null) {
          controls.add(buildReadyButton(acceptedActor));
        } else {
          controls.addAll(actors.map(buildAcceptButton));
        }
      }

      return Padding(
        padding: EdgeInsets.only(bottom: PosQueueLayout.itemRowSpacing(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      fontSize: PosQueueLayout.itemLine(context) + (largeTouchMode ? 2 : 0),
                    ),
                  ),
                ),
              ],
            ),
            if (acceptedByName.isNotEmpty || readyByName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                readyByName.isNotEmpty
                    ? 'Готово: $readyByName'
                    : 'Принял: $acceptedByName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (controls.isNotEmpty) ...[
              const SizedBox(height: 8),
              controls.length == 1
                  ? SizedBox(width: double.infinity, child: controls.first)
                  : controls.length == 2
                  ? Row(
                      children: [
                        Expanded(child: controls[0]),
                        const SizedBox(width: 10),
                        Expanded(child: controls[1]),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controls,
                    ),
            ] else if (st == 'ready') ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Позиция готова'),
                backgroundColor: Colors.green.shade100,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
          if (actors.isEmpty)
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
