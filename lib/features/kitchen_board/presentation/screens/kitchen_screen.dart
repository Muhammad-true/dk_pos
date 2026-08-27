import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:auto_route/auto_route.dart';
import 'package:dk_digitial_menu/core/app_file_logger.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/app/router/app_router.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_applier.dart';
import 'package:dk_pos/core/error/network_error_message.dart';
import 'package:dk_pos/core/logging/pos_perf_helpers.dart';
import 'package:dk_pos/core/utils/order_line_key.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/kitchen_board/audio/kitchen_order_alert.dart';
import 'package:dk_pos/features/kitchen_board/presentation/kitchen_ui_preferences.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_active_order_card.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_header_labels.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_order_number_badge.dart';
import 'package:dk_pos/features/kitchen_board/presentation/widgets/kitchen_ui_settings_sheet.dart';
import 'package:dk_pos/features/orders/data/local_kitchen_queue_ws_patch.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/presentation/pos_queue_layout.dart';
import 'package:dk_pos/features/orders/presentation/widgets/pos_queue_section_label.dart';
import 'package:dk_pos/features/shifts/presentation/shift_close_guard.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _KitchenOrderTrack {
  const _KitchenOrderTrack({
    required this.signature,
    required this.totalQty,
    required this.pendingQty,
    required this.hadProgress,
  });

  final String signature;
  final int totalQty;
  final int pendingQty;
  final bool hadProgress;
}

enum _KitchenOrderLineChange { added, removed, replaced }

class _KitchenOrderLineChangeEvent {
  const _KitchenOrderLineChangeEvent({
    required this.order,
    required this.change,
    required this.notifyWithSound,
  });

  final LocalKitchenQueueOrder order;
  final _KitchenOrderLineChange change;
  final bool notifyWithSound;
}

String _kitchenOrderItemsSignature(LocalKitchenQueueOrder order) {
  final items = order.items;
  if (items.length > 20) {
    var pending = 0;
    var accepted = 0;
    var ready = 0;
    var totalQty = 0;
    for (final e in items) {
      totalQty += e.quantity;
      switch (e.kitchenLineStatus.trim().toLowerCase()) {
        case 'pending':
          pending += 1;
        case 'accepted':
          accepted += 1;
        case 'ready':
          ready += 1;
      }
    }
    return 'bulk:$totalQty:$pending:$accepted:$ready:${items.length}';
  }
  final parts =
      items
          .map(
            (e) =>
                '${e.lineKey ?? e.menuItemId}:${e.quantity}:${e.kitchenLineStatus.trim().toLowerCase()}',
          )
          .toList(growable: false)
        ..sort();
  return parts.join(';');
}

int _kitchenPendingQty(LocalKitchenQueueOrder order) {
  var sum = 0;
  for (final e in order.items) {
    if (e.kitchenLineStatus.trim().toLowerCase() == 'pending') {
      sum += e.quantity;
    }
  }
  return sum;
}

int _kitchenOrderTotalQty(LocalKitchenQueueOrder order) {
  var sum = 0;
  for (final e in order.items) {
    sum += e.quantity;
  }
  return sum;
}

bool _kitchenOrderHadProgress(LocalKitchenQueueOrder order) {
  return order.items.any((e) {
    final st = e.kitchenLineStatus.trim().toLowerCase();
    return st == 'accepted' || st == 'ready';
  });
}

bool _kitchenOrderLooksLikeFollowUp(LocalKitchenQueueOrder order) {
  final items = order.items;
  if (items.any((e) => isFollowUpOrderLineKey(e.lineKey ?? ''))) {
    return true;
  }
  final hasReady = items.any(
    (e) => e.kitchenLineStatus.toLowerCase() == 'ready',
  );
  final hasPending = items.any(
    (e) => e.kitchenLineStatus.toLowerCase() == 'pending',
  );
  final hasAccepted = items.any(
    (e) => e.kitchenLineStatus.toLowerCase() == 'accepted',
  );
  return (hasReady && (hasPending || hasAccepted)) ||
      (hasPending && hasAccepted);
}

@RoutePage()
class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  LocalKitchenQueueSnapshot _snapshot = const LocalKitchenQueueSnapshot(
    preparing: [],
    waitingOthers: [],
    readyForPickup: [],
  );
  final _realtime = LocalOrdersRealtime.instance;
  bool _realtimeAcquired = false;
  FlutterTts? _tts;
  AudioPlayer? _audioPlayer;
  StreamSubscription<LocalOrdersRealtimeEvent>? _realtimeSub;
  bool _loading = true;
  bool _saving = false;
  bool _reloadInFlight = false;
  bool _reloadPending = false;
  final Map<String, DateTime> _kitchenTapGuard = <String, DateTime>{};
  String? _error;
  String? _syncWarning;
  Timer? _watchdogTimer;
  Timer? _reloadDebounce;
  Timer? _silentRetryTimer;
  Timer? _realtimeReconnectTimer;
  bool _recoveryInFlight = false;
  DateTime? _lastSuccessfulSyncAt;
  bool _realtimeConnected = false;
  bool _queueInitialized = false;
  Set<String> _knownPreparingOrderIds = <String>{};
  Set<String> _knownWaitingOrderIds = <String>{};
  Map<String, _KitchenOrderTrack> _knownOrderTracks =
      <String, _KitchenOrderTrack>{};
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
  DateTime? _lastKitchenActorsRefreshAt;
  static const _kitchenActorsRefreshInterval = Duration(minutes: 2);
  KitchenUiScale _uiScale = KitchenUiScale.standard;
  KitchenFollowUpSettings _followUpSettings = KitchenFollowUpSettings.defaults;
  bool get _kitchenAudioStackEnabled {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return AppConfig.posEnableKitchenAudioOnWindows;
    }
    return true;
  }

  Future<void> _ensureKitchenAudioStackReady() async {
    if (!_kitchenAudioStackEnabled) return;
    _tts ??= FlutterTts();
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
    if (!mounted) return;
    await _loadAudioSettings();
  }

  // Wi‑Fi LAN: онлайн — только проверка «устарело»; офлайн — реже, чем 5 с, чтобы не штормить сервер.
  static const _watchdogIntervalOnline = Duration(seconds: 45);
  static const _watchdogIntervalOffline = Duration(seconds: 10);
  static const _staleSyncThreshold = Duration(seconds: 120);
  static const _realtimeReconnectDelay = Duration(seconds: 2);
  static const _maxReconnectAttempt = 6; // 2s * 2^6 ≈ 128s + jitter

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadKitchenUiPreferences());
    if (_kitchenAudioStackEnabled) {
      unawaited(_ensureKitchenAudioStackReady());
    }
    _reload();
    _connectRealtime();
    _startConnectionWatchdog();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recoverConnection(silent: true));
    }
  }

  void _startConnectionWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogTickInterval(), (_) {
      if (!mounted) return;
      unawaited(_runConnectionWatchdogTick());
    });
  }

  Duration _watchdogTickInterval() {
    if (_syncWarning != null || !_realtimeConnected) {
      return _watchdogIntervalOffline;
    }
    return _watchdogIntervalOnline;
  }

  void _rescheduleConnectionWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogTickInterval(), (_) {
      if (!mounted) return;
      unawaited(_runConnectionWatchdogTick());
    });
  }

  Future<void> _runConnectionWatchdogTick() async {
    if (!mounted || _recoveryInFlight) return;

    final offline = _syncWarning != null || !_realtimeConnected;
    final stale =
        _lastSuccessfulSyncAt != null &&
        DateTime.now().difference(_lastSuccessfulSyncAt!) > _staleSyncThreshold;
    final needsBootstrap = _lastSuccessfulSyncAt == null && !_loading;

    if (offline) {
      // Reconnect уже в backoff — не дублируем health/connect (Wi‑Fi storm).
      if (_realtimeReconnectTimer?.isActive == true) return;
      await _recoverConnection(silent: true);
      return;
    }

    if (stale || needsBootstrap) {
      await _recoverConnection(silent: true);
    }

    // При живом WS патчи — источник правды. Периодический full reload не делаем.
  }

  Future<void> _recoverConnection({bool silent = true}) async {
    if (!mounted || _recoveryInFlight) return;
    _recoveryInFlight = true;
    try {
      final serverOk = await ServerEndpointApplier.probeHealth(
        AppConfig.apiOrigin,
      );
      if (!serverOk) {
        if (mounted) {
          setState(() {
            _realtimeConnected = false;
            _syncWarning =
                'Нет связи с ${AppConfig.apiOrigin}. Переподключаемся автоматически…';
          });
        }
        // Без immediate: на Wi‑Fi все клиенты иначе бьют сервер разом после glitch.
        _scheduleRealtimeReconnect();
        return;
      }

      if (!_realtimeConnected) {
        await _connectRealtime();
      }
      if (!_reloadInFlight) {
        await _reload(silent: silent);
      }
    } finally {
      _recoveryInFlight = false;
      if (mounted) _rescheduleConnectionWatchdog();
    }
  }

  int _reconnectAttempts = 0;

  void _scheduleRealtimeReconnect({bool immediate = false}) {
    _realtimeReconnectTimer?.cancel();
    if (immediate) {
      if (mounted) unawaited(_connectRealtime());
      return;
    }

    final attempt = _reconnectAttempts < _maxReconnectAttempt
        ? _reconnectAttempts
        : _maxReconnectAttempt;
    final baseMs = _realtimeReconnectDelay.inMilliseconds;
    // Экспонента + jitter: клиенты на одном Wi‑Fi не синхронизируются в один тик.
    final jitterMs = DateTime.now().millisecond % 1500;
    final delayMs = (baseMs * (1 << attempt)) + jitterMs;
    _reconnectAttempts++;

    _realtimeReconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) unawaited(_connectRealtime());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    _reloadDebounce?.cancel();
    _silentRetryTimer?.cancel();
    _realtimeReconnectTimer?.cancel();
    _realtimeSub?.cancel();
    _realtimeSub = null;
    if (_realtimeAcquired) {
      _realtimeAcquired = false;
      _realtime.release().catchError((_) {});
    }
    if (_kitchenAudioStackEnabled) {
      _tts?.stop().catchError((_) {});
      _audioPlayer?.dispose().catchError((_) {});
    }
    super.dispose();
  }

  String get _branchId => AppConfig.storeBranchId;

  Future<void> _loadKitchenUiPreferences() async {
    final configured = await KitchenUiPreferences.isConfigured();
    var scale = await KitchenUiPreferences.load();
    var followUp = await KitchenFollowUpPreferences.load();
    if (!mounted) return;
    if (!configured) {
      final side = MediaQuery.sizeOf(context).shortestSide;
      scale = side >= 600 ? KitchenUiScale.tablet : KitchenUiScale.standard;
      await KitchenUiPreferences.save(scale);
    } else if (!await KitchenUiPreferences.hasOrderColumnsPreference()) {
      final w = MediaQuery.sizeOf(context).width;
      scale = KitchenUiScale(
        buttonScale: scale.buttonScale,
        buttonTextScale: scale.buttonTextScale,
        itemTextScale: scale.itemTextScale,
        orderColumns: w >= 720 ? 2 : 1,
      );
      await KitchenUiPreferences.save(scale);
    }
    if (!mounted) return;
    setState(() {
      _uiScale = scale;
      _followUpSettings = followUp;
    });
  }

  Future<void> _openKitchenUiSettings() async {
    final updated = await showKitchenUiSettingsSheet(
      context,
      initial: KitchenScreenSettings(
        uiScale: _uiScale,
        followUp: _followUpSettings,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _uiScale = updated.uiScale;
      _followUpSettings = updated.followUp;
    });
  }

  Future<void> _loadAudioSettings({bool forceRefresh = false}) async {
    try {
      final settings = await context.read<LocalAudioSettingsRepository>().fetch(
        branchId: _branchId,
        forceRefresh: forceRefresh,
      );
      _kitchenTtsEnabled = settings.kitchenTtsEnabled;
      _kitchenTtsRate = settings.kitchenTtsRate;
      _kitchenTtsLocale = settings.kitchenTtsLocale;
      _kitchenTtsVoiceName = settings.kitchenTtsVoiceName;
      _kitchenSoundPath = settings.kitchenSoundPath;
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bg_kitchen_sound_path', _kitchenSoundPath ?? '');
      }
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
    if (!_kitchenAudioStackEnabled) return;
    final tts = _tts;
    if (tts == null) return;
    final rate = _kitchenTtsRate.clamp(0.2, 1.2);
    final locale = _kitchenTtsLocale.trim().isEmpty
        ? 'ru-RU'
        : _kitchenTtsLocale.trim();
    try {
      try {
        await tts.awaitSpeakCompletion(false);
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
          await tts.setVoice({
            'name': voiceName,
            'locale': _effectiveKitchenTtsLocale,
          });
        } catch (_) {
          // Оставляем системный голос по умолчанию.
        }
      }
    } catch (e, st) {
      AppFileLogger.instance.error('kitchen_tts', 'apply config failed', e, st);
    }
  }

  Future<void> _speakKitchenText(String text) async {
    if (!_kitchenAudioStackEnabled || !_kitchenTtsEnabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _ensureKitchenAudioStackReady();
      final tts = _tts;
      if (tts == null) return;
      await _audioPlayer?.stop();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tts.stop();
      final result = await tts.speak(trimmed);
      AppFileLogger.instance.info(
        'kitchen_tts',
        'speak result=$result len=${trimmed.length}',
      );
    } catch (e, st) {
      AppFileLogger.instance.error(
        'kitchen_tts',
        'speak failed: $trimmed',
        e,
        st,
      );
    }
  }

  Future<String> _resolveBestLocale(String preferred) async {
    final tts = _tts;
    if (tts == null) return preferred;
    try {
      final langs = await tts.getLanguages;
      if (langs is! List) return preferred;
      final normalized = langs
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
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

  int? _lastQueueRevision;

  void _verifyQueueRevision(
    Map<String, dynamic> payload, {
    bool forceReloadOnGap = false,
  }) {
    final rev = payload['queueRevision'] ?? payload['queue_revision'];
    if (rev is int && rev > 0) {
      // При живых патчах дыра в revision не значит «данные битые» — debounce bump на сервере.
      if (forceReloadOnGap &&
          _lastQueueRevision != null &&
          rev != _lastQueueRevision &&
          rev != _lastQueueRevision! + 1) {
        _scheduleReload(silent: true);
      }
      _lastQueueRevision = rev;
    }
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
      _realtimeSub = _realtime.events.listen(
        (event) async {
          if (!mounted) return;
          final type = event.type;
          if (type == 'hello') {
            final wasReconnect = _reconnectAttempts > 0;
            _reconnectAttempts = 0;
            _verifyQueueRevision(event.payload);
            if (mounted) {
              setState(() {
                _realtimeConnected = true;
                _syncWarning = null;
              });
              _rescheduleConnectionWatchdog();
            }
            AppFileLogger.instance.info(
              'kitchen_ws',
              'connected branch=$_branchId',
            );
            // После Wi‑Fi glitch один silent snapshot — догоняем пропущенные патчи.
            if (wasReconnect && !_reloadInFlight) {
              _scheduleReload(silent: true);
            }
            return;
          }
          if (type == 'socket.done') {
            if (mounted) setState(() => _realtimeConnected = false);
            AppFileLogger.instance.warn(
              'kitchen_ws',
              'socket closed, reconnecting…',
            );
            if (mounted) {
              setState(() {
                _syncWarning ??=
                    'Связь с сервером прервана. Переподключаемся автоматически…';
              });
            }
            // Один путь: reconnect с backoff. Watchdog подхватит HTTP, если WS не оживёт.
            _scheduleRealtimeReconnect();
            return;
          }
          if (type == 'pong') {
            _verifyQueueRevision(event.payload);
            return;
          }
          if (type == 'order.created' || type == 'order.updated') {
            // Игнорируем, так как сервер пришлёт kitchen.queue_changed с патчами.
            return;
          }
          if (type == 'kitchen.queue_changed') {
            _verifyQueueRevision(event.payload);
            final patched = _applyKitchenQueueWsPatch(event.payload);
            if (!patched) {
              _scheduleReload(silent: true);
            }
          }
        },
        onError: (Object e, StackTrace st) async {
          AppFileLogger.instance.error('kitchen_ws', 'stream error', e, st);
          if (!mounted) return;
          setState(() {
            _realtimeConnected = false;
            _syncWarning ??=
                'Ошибка связи с сервером. Переподключаемся автоматически…';
          });
          _scheduleRealtimeReconnect();
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _realtimeConnected = false;
          _syncWarning ??=
              'Не удалось подключиться к серверу. Повторяем автоматически…';
        });
      }
      _scheduleRealtimeReconnect();
    }
  }

  bool _applyKitchenQueueWsPatch(Map<String, dynamic> payload) {
    final patches = parseKitchenStationPatches(payload['stationPatches']);
    if (patches.isEmpty) return false;

    final myStationId = context.read<AuthBloc>().state.user?.kitchenStationId;
    final mine = kitchenStationPatchesForUser(
      patches: patches,
      kitchenStationId: myStationId,
    );
    if (mine.isEmpty) return false;

    final prev = _snapshot;
    var next = applyKitchenStationPatches(prev, mine);

    final rev = payload['queueRevision'] ?? payload['queue_revision'];
    if (rev is int && rev > 0) {
      next = LocalKitchenQueueSnapshot(
        preparing: next.preparing,
        waitingOthers: next.waitingOthers,
        readyForPickup: next.readyForPickup,
        queueRevision: rev,
      );
      _lastQueueRevision = rev;
    }

    final uiChanged =
        kitchenSnapshotItemsChanged(prev, next) ||
        kitchenSnapshotChanged(prev, next);
    if (!uiChanged) {
      // Патч не изменил UI для этой станции — это нормально (например, обновилась другая станция).
      // НЕ делаем полный reload, чтобы не перегружать сеть.
      return true;
    }

    if (!mounted) return true;
    setState(() {
      _snapshot = next;
      _syncWarning = null;
      _silentRetryTimer?.cancel();
    });
    _lastSuccessfulSyncAt = DateTime.now();
    AppFileLogger.instance.info(
      'kitchen_ws',
      'patch applied station=$myStationId orders=${mine.map((e) => e.orderId).join(',')}',
    );
    unawaited(_announceKitchenQueueChanges(next));
    return true;
  }

  void _scheduleReload({bool silent = true}) {
    _reloadDebounce?.cancel();
    // Небольшой debounce: пачка WS-событий после восстановления Wi‑Fi → один HTTP.
    _reloadDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) unawaited(_reload(silent: silent));
    });
  }

  void _scheduleSilentRetryReload() {
    _silentRetryTimer?.cancel();
    _silentRetryTimer = Timer(_watchdogIntervalOffline, () {
      if (!mounted) return;
      unawaited(_recoverConnection(silent: true));
    });
  }

  Future<void> _reload({bool silent = false, bool skipAnnounce = false}) async {
    if (!mounted) return;
    if (_reloadInFlight) {
      _reloadPending = true;
      return;
    }
    _reloadInFlight = true;
    final started = DateTime.now();
    final currentUserId = context.read<AuthBloc>().state.user?.id;
    if (!silent) {
      setState(() {
        _loading = true;
        _statsLoading = true;
        _error = null;
        _syncWarning = null;
        _statsError = null;
      });
    }
    try {
      final repo = context.read<LocalOrdersRepository>();
      final snap = await repo.fetchKitchenQueueMy();
      if (snap.queueRevision != null) {
        _lastQueueRevision = snap.queueRevision;
      }
      LocalKitchenTodayStats stats = _todayStats;
      if (!silent) {
        stats = await repo.fetchKitchenMyTodayStats(branchId: _branchId);
      }
      List<LocalKitchenActorProfile> actors = _kitchenActors;
      final shouldRefreshActors =
          !silent ||
          _lastKitchenActorsRefreshAt == null ||
          DateTime.now().difference(_lastKitchenActorsRefreshAt!) >
              _kitchenActorsRefreshInterval;
      if (shouldRefreshActors) {
        try {
          actors = await repo.fetchKitchenTeamMyStation();
          _lastKitchenActorsRefreshAt = DateTime.now();
        } catch (_) {
          // Для совместимости со старыми API не блокируем загрузку экрана.
        }
      }
      if (currentUserId != null) {
        actors = actors
            .where((a) => a.id != currentUserId)
            .toList(growable: false);
      }
      if (!mounted) return;
      final changed =
          kitchenSnapshotChanged(_snapshot, snap) ||
          kitchenSnapshotItemsChanged(_snapshot, snap);
      if (changed || !silent) {
        setState(() {
          _snapshot = snap;
          if (!silent) {
            _todayStats = stats;
            _statsLoading = false;
            _statsError = null;
          }
          _kitchenActors = actors;
          _loading = false;
          _error = null;
          _syncWarning = null;
          _silentRetryTimer?.cancel();
        });
        _lastSuccessfulSyncAt = DateTime.now();
        _rescheduleConnectionWatchdog();
      } else if (_loading) {
        setState(() => _loading = false);
      } else {
        _lastSuccessfulSyncAt = DateTime.now();
      }
      AppFileLogger.instance.slow(
        'kitchen',
        'reload preparing=${snap.preparing.length}',
        DateTime.now().difference(started).inMilliseconds,
      );
      if (!skipAnnounce && changed) {
        await _announceKitchenQueueChanges(snap);
      }
    } catch (e) {
      if (!mounted) return;
      AppFileLogger.instance.error('kitchen', 'reload failed', e);
      final friendly = formatNetworkErrorMessage(e);
      setState(() {
        _loading = false;
        if (silent) {
          _syncWarning =
              '$friendly\nПовторим автоматически через несколько секунд.';
          _scheduleSilentRetryReload();
          _rescheduleConnectionWatchdog();
        } else {
          _statsLoading = false;
          _statsError = friendly;
          _error =
              _snapshot.preparing.isEmpty &&
                  _snapshot.waitingOthers.isEmpty &&
                  _snapshot.readyForPickup.isEmpty
              ? friendly
              : null;
          if (_error == null) {
            _syncWarning = friendly;
          }
        }
      });
    } finally {
      _reloadInFlight = false;
      if (_reloadPending && mounted) {
        _reloadPending = false;
        unawaited(_reload(silent: true, skipAnnounce: true));
      }
    }
  }

  String _formatDurationShort(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$hч $mм';
  }

  Future<void> _announceKitchenQueueChanges(
    LocalKitchenQueueSnapshot snap,
  ) async {
    final currentPreparingIds = snap.preparing.map((e) => e.id).toSet();
    final currentWaitingIds = snap.waitingOthers.map((e) => e.id).toSet();
    if (!_queueInitialized) {
      _queueInitialized = true;
      _knownPreparingOrderIds = currentPreparingIds;
      _knownWaitingOrderIds = currentWaitingIds;
      _knownOrderTracks = _buildKitchenOrderTracks([
        ...snap.preparing,
        ...snap.waitingOthers,
      ]);
      return;
    }

    final newOrders = snap.preparing
        .where(
          (o) =>
              !_knownPreparingOrderIds.contains(o.id) &&
              !_knownWaitingOrderIds.contains(o.id),
        )
        .toList(growable: false);
    var lineChanges = _detectKitchenOrderLineChanges(snap.preparing);

    // Дозаказ: заказ снова в «готовится» после «ожидания других станций» (кухня уже приняла).
    final reenteredFromWaiting = snap.preparing
        .where(
          (o) =>
              !_knownPreparingOrderIds.contains(o.id) &&
              _knownWaitingOrderIds.contains(o.id),
        )
        .toList(growable: false);
    for (final order in reenteredFromWaiting) {
      lineChanges = [
        ...lineChanges,
        _KitchenOrderLineChangeEvent(
          order: order,
          change: _KitchenOrderLineChange.added,
          notifyWithSound: true,
        ),
      ];
    }

    _knownPreparingOrderIds = currentPreparingIds;
    _knownWaitingOrderIds = currentWaitingIds;
    _knownOrderTracks = _buildKitchenOrderTracks([
      ...snap.preparing,
      ...snap.waitingOthers,
    ]);

    if (newOrders.isEmpty && lineChanges.isEmpty) return;

    // Настройки в фоне — звук сразу, без ожидания GET audio-settings.
    unawaited(_loadAudioSettings());

    for (final order in newOrders) {
      await _notifyKitchenNewOrder(order);
    }
    for (final change in lineChanges) {
      await _notifyKitchenOrderLineChange(change);
    }
  }

  Future<void> _notifyKitchenNewOrder(LocalKitchenQueueOrder order) async {
    if (_kitchenAudioStackEnabled) {
      try {
        await _ensureKitchenAudioStackReady();
        await _playKitchenAlertSound();
      } catch (e, st) {
        AppFileLogger.instance.error('kitchen', 'alert sound failed', e, st);
      }
      await _speakKitchenText(_kitchenSpeakText(order));
    }
    if (!mounted) return;
    _showKitchenSnack(
      _kitchenNewOrderSnackText(order),
      background: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Future<void> _notifyKitchenOrderLineChange(
    _KitchenOrderLineChangeEvent change,
  ) async {
    if (!change.notifyWithSound) return;

    final rawFollowUp = _kitchenOrderLooksLikeFollowUp(change.order);
    final isFollowUpChange =
        rawFollowUp &&
        (change.change == _KitchenOrderLineChange.added ||
            change.change == _KitchenOrderLineChange.replaced);
    final playSound = !isFollowUpChange || _followUpSettings.notifySound;
    final speakTts =
        _kitchenTtsEnabled &&
        (!isFollowUpChange || _followUpSettings.notifyTts);
    final showSnack = !isFollowUpChange || _followUpSettings.notifySnack;

    if (!playSound && !speakTts && !showSnack) return;

    if (playSound && _kitchenAudioStackEnabled) {
      try {
        await _ensureKitchenAudioStackReady();
        await HapticFeedback.mediumImpact();
        await _playKitchenAlertSound();
      } catch (e, st) {
        AppFileLogger.instance.error(
          'kitchen',
          'line change alert failed',
          e,
          st,
        );
      }
      if (speakTts) {
        await _speakKitchenText(_kitchenLineChangeSpeakText(change));
      }
    } else if (playSound) {
      await HapticFeedback.lightImpact();
    } else if (speakTts && _kitchenAudioStackEnabled) {
      await _speakKitchenText(_kitchenLineChangeSpeakText(change));
    }

    if (!mounted || !showSnack) return;
    final scheme = Theme.of(context).colorScheme;
    _showKitchenSnack(
      _kitchenLineChangeSnackText(change),
      background: change.change == _KitchenOrderLineChange.removed
          ? scheme.errorContainer
          : scheme.tertiaryContainer,
    );
  }

  Future<void> _playKitchenAlertSound() async {
    final player = _audioPlayer;
    if (player == null) return;
    await KitchenOrderAlert.play(player, customUploadPath: _kitchenSoundPath);
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  void _showKitchenSnack(String message, {Color? background}) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: background,
        content: Text(message),
      ),
    );
  }

  String _kitchenNewOrderSnackText(LocalKitchenQueueOrder order) {
    final no = kitchenOrderDisplayNumber(order);
    if (no.isNotEmpty) return 'Новый заказ №$no';
    return 'Новый заказ';
  }

  String _kitchenLineChangeSpeakText(_KitchenOrderLineChangeEvent change) {
    final number = _speakableOrderNumber(
      kitchenOrderDisplayNumber(change.order),
    );
    final toCook = _kitchenActiveItemsSummaryRu(change.order.items);
    return switch (change.change) {
      _KitchenOrderLineChange.added when toCook.isNotEmpty =>
        number.isNotEmpty
            ? 'Дозаказ номер $number. Приготовить только: $toCook.'
            : 'Дозаказ. Приготовить только: $toCook.',
      _KitchenOrderLineChange.added =>
        number.isNotEmpty
            ? 'В заказе номер $number добавили блюда. Проверьте список.'
            : 'В заказ добавили блюда. Проверьте список.',
      _KitchenOrderLineChange.removed =>
        number.isNotEmpty
            ? 'Из заказа номер $number убрали позиции.'
            : 'Из заказа убрали позиции.',
      _KitchenOrderLineChange.replaced when toCook.isNotEmpty =>
        number.isNotEmpty
            ? 'Заказ номер $number изменён. Приготовить: $toCook.'
            : 'Состав заказа изменён. Приготовить: $toCook.',
      _KitchenOrderLineChange.replaced =>
        number.isNotEmpty
            ? 'Заказ номер $number изменён. Проверьте состав.'
            : 'Состав заказа изменён. Проверьте список.',
    };
  }

  String _kitchenLineChangeSnackText(_KitchenOrderLineChangeEvent change) {
    final no = kitchenOrderDisplayNumber(change.order);
    final prefix = no.isNotEmpty ? 'Заказ №$no: ' : '';
    final toCook = _kitchenActiveItemsSummaryRu(change.order.items);
    return switch (change.change) {
      _KitchenOrderLineChange.added when toCook.isNotEmpty =>
        '$prefixдозаказ — готовить: $toCook',
      _KitchenOrderLineChange.added => '$prefixдобавили позиции',
      _KitchenOrderLineChange.removed => '$prefixубрали позиции',
      _KitchenOrderLineChange.replaced when toCook.isNotEmpty =>
        '$prefixизменён состав — готовить: $toCook',
      _KitchenOrderLineChange.replaced => '$prefixизменили состав',
    };
  }

  Map<String, _KitchenOrderTrack> _buildKitchenOrderTracks(
    List<LocalKitchenQueueOrder> orders,
  ) {
    return {
      for (final o in orders)
        o.id: _KitchenOrderTrack(
          signature: _kitchenOrderItemsSignature(o),
          totalQty: _kitchenOrderTotalQty(o),
          pendingQty: _kitchenPendingQty(o),
          hadProgress: _kitchenOrderHadProgress(o),
        ),
    };
  }

  List<_KitchenOrderLineChangeEvent> _detectKitchenOrderLineChanges(
    List<LocalKitchenQueueOrder> preparing,
  ) {
    final out = <_KitchenOrderLineChangeEvent>[];
    for (final order in preparing) {
      final prev = _knownOrderTracks[order.id];
      if (prev == null) continue;
      final signature = _kitchenOrderItemsSignature(order);
      if (signature == prev.signature) continue;

      final qty = _kitchenOrderTotalQty(order);
      late final _KitchenOrderLineChange change;
      if (qty > prev.totalQty) {
        change = _KitchenOrderLineChange.added;
      } else if (qty < prev.totalQty) {
        change = _KitchenOrderLineChange.removed;
      } else {
        change = _KitchenOrderLineChange.replaced;
      }

      final pendingNow = _kitchenPendingQty(order);
      final pendingBefore = prev.pendingQty;
      final notifyWithSound = switch (change) {
        _KitchenOrderLineChange.removed => true,
        // Дозаказ / новая pending-строка после «Принять» или «Готово».
        _KitchenOrderLineChange.added => true,
        _KitchenOrderLineChange.replaced =>
          pendingNow > pendingBefore || (prev.hadProgress && pendingNow > 0),
      };

      out.add(
        _KitchenOrderLineChangeEvent(
          order: order,
          change: change,
          notifyWithSound: notifyWithSound,
        ),
      );
    }
    return out;
  }

  String _kitchenSpeakText(LocalKitchenQueueOrder order) {
    final number = _speakableOrderNumber(kitchenOrderDisplayNumber(order));
    final typeBadge = kitchenOrderTypeHeadlineRu(order);
    if (number.isNotEmpty) {
      if (typeBadge != null) {
        return 'Новый заказ. $typeBadge. Номер $number. Удачной смены!';
      }
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

  void _applyOptimisticKitchenAction({
    required LocalKitchenQueueOrder order,
    required LocalKitchenActorProfile actor,
    required String action,
  }) {
    final now = DateTime.now().toIso8601String();
    LocalKitchenQueueOrder? sourceOrder;
    for (final candidate in _snapshot.preparing) {
      if (candidate.id == order.id) {
        sourceOrder = candidate;
        break;
      }
    }
    sourceOrder ??= order;
    final actionScopeKeys = {
      for (final item in kitchenOrderActionScopeItems(sourceOrder.items))
        item.lineKey ?? item.menuItemId,
    };

    LocalKitchenQueueItem patchItem(LocalKitchenQueueItem item) {
      final itemKey = item.lineKey ?? item.menuItemId;
      final status = item.kitchenLineStatus.toLowerCase();
      if (action == 'accept' && status == 'pending') {
        if (!actionScopeKeys.contains(itemKey)) return item;
        return LocalKitchenQueueItem(
          menuItemId: item.menuItemId,
          name: item.name,
          quantity: item.quantity,
          lineKey: item.lineKey,
          saleMeasure: item.saleMeasure,
          actualQty: item.actualQty,
          defaultSaleQty: item.defaultSaleQty,
          kitchenLineStatus: 'accepted',
          kitchenAcceptedByUserId: actor.id,
          kitchenAcceptedByUsername: actor.username,
          kitchenAcceptedAtIso: now,
          kitchenReadyByUserId: item.kitchenReadyByUserId,
          kitchenReadyByUsername: item.kitchenReadyByUsername,
          kitchenReadyAtIso: item.kitchenReadyAtIso,
          kitchenStationId: item.kitchenStationId,
          kitchenStationName: item.kitchenStationName,
        );
      }
      // Ready: как на бэкенде — все accepted станции, не только action scope
      // (иначе база после закрытого дозаказа остаётся accepted локально).
      if (action == 'ready' && status == 'accepted') {
        return LocalKitchenQueueItem(
          menuItemId: item.menuItemId,
          name: item.name,
          quantity: item.quantity,
          lineKey: item.lineKey,
          saleMeasure: item.saleMeasure,
          actualQty: item.actualQty,
          defaultSaleQty: item.defaultSaleQty,
          kitchenLineStatus: 'ready',
          kitchenAcceptedByUserId: item.kitchenAcceptedByUserId,
          kitchenAcceptedByUsername: item.kitchenAcceptedByUsername,
          kitchenAcceptedAtIso: item.kitchenAcceptedAtIso,
          kitchenReadyByUserId: actor.id,
          kitchenReadyByUsername: actor.username,
          kitchenReadyAtIso: now,
          kitchenStationId: item.kitchenStationId,
          kitchenStationName: item.kitchenStationName,
        );
      }
      return item;
    }

    LocalKitchenQueueOrder patchOrder(LocalKitchenQueueOrder value) {
      if (value.id != order.id) return value;
      return LocalKitchenQueueOrder(
        id: value.id,
        number: value.number,
        orderType: value.orderType,
        tableLabel: value.tableLabel,
        status: value.status,
        totalPrice: value.totalPrice,
        items: value.items.map(patchItem).toList(growable: false),
        handOutSource: value.handOutSource,
      );
    }

    List<LocalKitchenQueueOrder> patchList(List<LocalKitchenQueueOrder> list) =>
        list.map(patchOrder).toList(growable: false);

    setState(() {
      _snapshot = LocalKitchenQueueSnapshot(
        preparing: patchList(_snapshot.preparing),
        waitingOthers: patchList(_snapshot.waitingOthers),
        readyForPickup: patchList(_snapshot.readyForPickup),
      );
    });
    _knownOrderTracks = _buildKitchenOrderTracks([
      ..._snapshot.preparing,
      ..._snapshot.waitingOthers,
    ]);
    if (action == 'ready') {
      _moveOrderToWaitingOthersIfStationReady(order.id);
      _knownWaitingOrderIds = {..._knownWaitingOrderIds, order.id};
      _knownOrderTracks = _buildKitchenOrderTracks([
        ..._snapshot.preparing,
        ..._snapshot.waitingOthers,
      ]);
    }
  }

  bool _kitchenStationItemsAllReady(LocalKitchenQueueOrder order) {
    return order.items.isNotEmpty &&
        order.items.every(
          (item) => item.kitchenLineStatus.toLowerCase() == 'ready',
        );
  }

  void _moveOrderToWaitingOthersIfStationReady(String orderId) {
    LocalKitchenQueueOrder? order;
    for (final candidate in _snapshot.preparing) {
      if (candidate.id == orderId) {
        order = candidate;
        break;
      }
    }
    if (order == null || !_kitchenStationItemsAllReady(order)) return;
    final moved = order;
    setState(() {
      final preparing = _snapshot.preparing
          .where((value) => value.id != orderId)
          .toList(growable: false);
      final waitingOthers = [
        ..._snapshot.waitingOthers.where((value) => value.id != orderId),
        moved,
      ];
      _snapshot = LocalKitchenQueueSnapshot(
        preparing: preparing,
        waitingOthers: waitingOthers,
        readyForPickup: _snapshot.readyForPickup,
      );
    });
  }

  bool _canTapKitchenAction({
    required String orderId,
    required String action,
    required int actorId,
  }) {
    final key = '$orderId:$action:$actorId';
    final last = _kitchenTapGuard[key];
    final now = DateTime.now();
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 450)) {
      return false;
    }
    _kitchenTapGuard[key] = now;
    return true;
  }

  Future<void> _kitchenAction({
    required LocalKitchenQueueOrder order,
    required LocalKitchenActorProfile actor,
    required String action,
  }) async {
    if (!_canTapKitchenAction(
      orderId: order.id,
      action: action,
      actorId: actor.id,
    )) {
      return;
    }

    _applyOptimisticKitchenAction(order: order, actor: actor, action: action);
    unawaited(
      _submitKitchenActionInBackground(
        order: order,
        actor: actor,
        action: action,
      ),
    );
  }

  Future<void> _submitKitchenActionInBackground({
    required LocalKitchenQueueOrder order,
    required LocalKitchenActorProfile actor,
    required String action,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<LocalOrdersRepository>().updateKitchenProgress(
        orderId: order.id,
        action: action,
        actorUserId: actor.id,
      );
      if (!mounted) return;
      await HapticFeedback.lightImpact();
      final actorLabel = _actorUiLabel(actor);
      final actionLabel = action == 'ready' ? 'Готова/выдать' : 'Принять';
      final orderNo = kitchenOrderDisplayNumber(order);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            orderNo.isNotEmpty
                ? 'Заказ $orderNo: $actorLabel · $actionLabel'
                : '$actorLabel · $actionLabel',
          ),
        ),
      );
      // Подтверждение приходит по WS (stationPatches) — без тяжёлого GET.
    } catch (e) {
      if (!mounted) return;
      await HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(content: Text(formatNetworkErrorMessage(e))),
      );
      _scheduleReload(silent: true);
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
    return Color.lerp(acceptColor, Colors.black, 0.18) ??
        const Color(0xFF2E7D32);
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

  Future<void> _openWaitingOthersSheet() async {
    if (!mounted) return;
    final l10n = context.appL10n;
    final orders = _snapshot.waitingOthers;
    final columns = _uiScale.orderColumns;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: _kToneWaiting),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.kitchenSectionWaitingOthers,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (orders.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${orders.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: orders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.kitchenEmptyWaiting,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _KitchenOrderCardsLayout(
                              columns: columns,
                              orders: orders,
                              cardBuilder: (order) => _KitchenWaitingPanel(
                                order: order,
                                tone: _kToneWaiting,
                                l10n: l10n,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestLogoutWithConfirm() async {
    if (!mounted) return;
    final role = context.read<AuthBloc>().state.user?.role ?? '';
    final ok = await confirmLogoutWithShiftChecks(context, role: role);
    if (!ok || !mounted) return;
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
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stationName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.format_size_rounded),
                title: const Text('Настройки экрана'),
                subtitle: Text(
                  'Кнопки ${(_uiScale.buttonScale * 100).round()}% · '
                  'текст ${(_uiScale.buttonTextScale * 100).round()}% · '
                  'блюда ${(_uiScale.itemTextScale * 100).round()}%',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_openKitchenUiSettings());
                },
              ),
              const SizedBox(height: 8),
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
                            Text(
                              'Время: ${_formatDurationShort(_todayStats.spentSeconds)}',
                            ),
                            if (_statsError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _statsError!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
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
              _syncWarning != null
                  ? '$stationType · нет связи · переподключение…'
                  : _realtimeConnected
                  ? '$stationType · онлайн · ${_snapshot.preparing.length} в работе'
                  : '$stationType · обновление… · ${_snapshot.preparing.length} в работе',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _syncWarning != null
                    ? theme.colorScheme.error
                    : _realtimeConnected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.kitchenSectionWaitingOthers,
            onPressed: _loading ? null : _openWaitingOthersSheet,
            icon: Badge(
              isLabelVisible: _snapshot.waitingOthers.isNotEmpty,
              label: Text('${_snapshot.waitingOthers.length}'),
              child: const Icon(Icons.hourglass_top_rounded),
            ),
          ),
          if (!PosQueueLayout.isPhone(context)) ...[
            IconButton(
              tooltip: 'Настройки экрана',
              onPressed: _openKitchenUiSettings,
              icon: const Icon(Icons.format_size_rounded),
            ),
            const PosThemeToggleIconButton(),
            IconButton(
              tooltip: l10n.queueBoardTooltipOpen,
              onPressed: () => context.router.push(const QueueBoardRoute()),
              icon: const Icon(Icons.display_settings_rounded),
            ),
          ],
          IconButton(
            tooltip: l10n.actionRefreshMenu,
            onPressed: _loading ? null : () => _reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (PosQueueLayout.isPhone(context))
            PopupMenuButton<String>(
              tooltip: l10n.tooltipAppMenu,
              onSelected: (value) {
                switch (value) {
                  case 'settings':
                    _openKitchenUiSettings();
                  case 'queue':
                    context.router.push(const QueueBoardRoute());
                  case 'logout':
                    _requestLogoutWithConfirm();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.format_size_rounded),
                    title: Text('Настройки экрана'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'queue',
                  child: ListTile(
                    leading: const Icon(Icons.display_settings_rounded),
                    title: Text(l10n.queueBoardTooltipOpen),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded),
                    title: Text('Выход'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: _saving ? null : _requestLogoutWithConfirm,
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.actionExit),
            ),
          if (PosQueueLayout.isPhone(context)) const PosThemeToggleIconButton(),
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
                _snapshot.waitingOthers.isEmpty &&
                _snapshot.readyForPickup.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loading ? null : () => _reload(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: EdgeInsets.all(
                    PosQueueLayout.listPadding(context, embedded: false),
                  ),
                  children: [
                    if (_syncWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _syncWarning!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_loading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _KitchenSectionRow(
                      label: PosQueueSectionLabel(
                        label: l10n.kitchenSectionCooking,
                        tone: _kToneCooking,
                      ),
                      count: _snapshot.preparing.length,
                    ),
                    const SizedBox(height: 10),
                    if (_snapshot.preparing.isEmpty)
                      _KitchenEmptyPanel(text: l10n.kitchenEmptyCooking)
                    else
                      _KitchenOrderCardsLayout(
                        columns: _uiScale.orderColumns,
                        orders: _snapshot.preparing,
                        cardBuilder: (order) => RepaintBoundary(
                          child: KitchenActiveOrderCard(
                            key: ValueKey(order.id),
                            order: order,
                            tone: _kToneCooking,
                            busy: false,
                            l10n: l10n,
                            actors: _kitchenActors,
                            acceptColorOf: _actorAcceptColor,
                            readyColorOf: _actorReadyColor,
                            onColorOf: _buttonOnColor,
                            uiScale: _uiScale,
                            followUpSettings: _followUpSettings,
                            onOrderAction:
                                ({required actor, required action}) =>
                                    _kitchenAction(
                                      order: order,
                                      actor: actor,
                                      action: action,
                                    ),
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

List<LocalKitchenQueueItem> _kitchenOrderActiveItems(
  List<LocalKitchenQueueItem> items,
) {
  final active = items
      .where((e) {
        final st = e.kitchenLineStatus.toLowerCase();
        return st == 'pending' || st == 'accepted';
      })
      .toList(growable: false);
  active.sort((a, b) {
    final aPending = a.kitchenLineStatus.toLowerCase() == 'pending' ? 0 : 1;
    final bPending = b.kitchenLineStatus.toLowerCase() == 'pending' ? 0 : 1;
    return aPending.compareTo(bPending);
  });
  return active;
}

String _kitchenActiveItemsSummaryRu(
  List<LocalKitchenQueueItem> items, {
  int maxParts = 4,
}) {
  final active = _kitchenOrderActiveItems(items);
  if (active.isEmpty) return '';
  final parts = active
      .map((e) => e.quantity > 1 ? '${e.quantity}× ${e.name}' : e.name)
      .toList(growable: false);
  if (parts.length <= maxParts) return parts.join(', ');
  final head = parts.take(maxParts).join(', ');
  return '$head и ещё ${parts.length - maxParts}';
}

class _KitchenOrderCardsLayout extends StatelessWidget {
  const _KitchenOrderCardsLayout({
    required this.columns,
    required this.orders,
    required this.cardBuilder,
  });

  final int columns;
  final List<LocalKitchenQueueOrder> orders;
  final Widget Function(LocalKitchenQueueOrder order) cardBuilder;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final cols = PosQueueLayout.kitchenGridColumns(context);
    final effectiveCols = columns.clamp(1, cols).clamp(1, 3);
    if (effectiveCols <= 1) {
      return Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            cardBuilder(orders[i]),
          ],
        ],
      );
    }

    final pad = PosQueueLayout.listPadding(context, embedded: false);
    final width = MediaQuery.sizeOf(context).width;
    const gap = 12.0;
    final cardWidth =
        (width - pad * 2 - gap * (effectiveCols - 1)) / effectiveCols;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final order in orders)
          SizedBox(width: cardWidth, child: cardBuilder(order)),
      ],
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitchenOrderNumberBadge(
            displayNumber: kitchenOrderDisplayNumber(order),
            tone: tone,
            orderTypeLabel: kitchenOrderTypeHeadlineRu(order),
            tableHeadline: kitchenTableHeadlineRu(order),
          ),
          SizedBox(
            height: PosQueueLayout.shortestSide(context) < 600 ? 10 : 12,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: PosQueueLayout.kitchenStatusIcon(context),
              ),
              SizedBox(
                width: PosQueueLayout.shortestSide(context) < 600 ? 8 : 10,
              ),
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
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${order.items.length} поз.',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            const SizedBox(height: 6),
            if (order.items.length > kKitchenLargeOrderItemThreshold)
              SizedBox(
                height: 180,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    primary: false,
                    itemCount: order.items.length,
                    itemBuilder: (context, index) {
                      final e = order.items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          e.assemblyTitleWithStation(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              ...order.items.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e.assemblyTitleWithStation(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
