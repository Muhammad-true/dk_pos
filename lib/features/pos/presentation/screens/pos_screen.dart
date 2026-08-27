import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/app/locale/locale_state.dart';
import 'package:dk_pos/app/pos_board_layout/pos_board_layout_cubit.dart';
import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_cubit.dart';
import 'package:dk_pos/app/pos_cashier_board/pos_cashier_board_settings.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/core/utils/order_assembly_items.dart';
import 'package:dk_pos/core/locale/api_locale.dart';
import 'package:dk_pos/features/auth/presentation/cashier_password_gate_dialog.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_state.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/features/cash/presentation/pos_cash_flow.dart';
import 'package:dk_pos/features/shifts/presentation/shift_close_guard.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/features/menu/data/menu_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/inventory/presentation/admin_inventory_receive_screen.dart';
import 'package:dk_pos/features/kitchen_board/audio/kitchen_order_alert.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_catalog_grid_settings_editor.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_cashier_board_settings_editor.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_cart_panel_settings_editor.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_server_endpoint_editor.dart';
import 'package:dk_pos/features/pos/presentation/utils/cashier_table_headline.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_modifier_sheet.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_variable_qty_sheet.dart';
import 'package:dk_pos/features/expeditor/presentation/widgets/expeditor_queue_panel.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/orders/data/local_cashier_board_ws_patch.dart';
import 'package:dk_pos/features/payments/data/local_payments_repository.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/shared/shared.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

import '../widgets/pos_cart_panel.dart';
import '../utils/website_order_delivery_meta.dart';
import '../widgets/pos_catalog_body.dart';
import '../widgets/pos_board_layout_settings_editor.dart';
import '../widgets/pos_cashier_order_visual_style.dart';
import '../widgets/pos_online_ordering_badge.dart';
import '../widgets/pos_change_order_table.dart';
import '../widgets/pos_change_order_type.dart';
import '../widgets/pos_checkout_flow.dart';
import '../widgets/pos_numeric_keypad.dart';
import '../widgets/pos_online_order_edit_flow.dart';
import '../widgets/pos_order_history_dialog.dart';
import '../widgets/pos_sold_out_today_dialog.dart';
import '../widgets/pos_table_bills_dialog.dart';

String _cashierOrderStatusRu(String status) {
  switch (status.toLowerCase()) {
    case 'new':
      return 'Новый';
    case 'cooking':
      return 'Готовится';
    case 'awaiting_expeditor':
      return 'У сборщика';
    case 'ready':
      return 'Готов к выдаче';
    case 'done':
      return 'Выдан';
    case 'cancelled':
      return 'Отменен';
    default:
      return status;
  }
}

Color _cashierItemStatusColor(BuildContext context, String status) {
  final s = status.trim().toLowerCase();
  final scheme = Theme.of(context).colorScheme;
  if (s == 'ready') return const Color(0xFF2E7D32);
  if (s == 'accepted') return const Color(0xFF1565C0);
  if (s == 'pending') return const Color(0xFFE65100);
  return scheme.onSurfaceVariant;
}

String? _cashierKitchenActorHint(LocalKitchenQueueOrder order) {
  final status = order.status.toLowerCase();
  final acceptedNames = <String>{};
  final readyNames = <String>{};
  for (final item in order.items) {
    final acceptedBy = (item.kitchenAcceptedByUsername ?? '').trim();
    if (acceptedBy.isNotEmpty) acceptedNames.add(acceptedBy);
    final readyBy = (item.kitchenReadyByUsername ?? '').trim();
    if (readyBy.isNotEmpty) readyNames.add(readyBy);
  }
  if (status == 'cooking' && acceptedNames.isNotEmpty) {
    return 'Принял: ${acceptedNames.join(', ')}';
  }
  if ((status == 'ready' || status == 'awaiting_expeditor' || status == 'done') &&
      readyNames.isNotEmpty) {
    return 'Готовил: ${readyNames.join(', ')}';
  }
  return null;
}

/// Иконка и подпись: автовыдача по таймеру или ручная выдача (статус «Выдан»).
class _CashierHandOutSourceRow extends StatelessWidget {
  const _CashierHandOutSourceRow({required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final norm = source?.trim().toLowerCase();
    late final IconData icon;
    late final String label;
    late final String tip;
    if (norm == 'kitchen') {
      icon = Icons.restaurant_rounded;
      label = 'Кухня · Готово';
      tip = 'Выдано автоматически при нажатии «Готово» на кухне.';
    } else if (norm == 'auto') {
      icon = Icons.schedule_rounded;
      label = 'Автовыдача';
      tip = 'Переведено в «Выдан» автоматически через заданный интервал.';
    } else if (norm == 'manual') {
      icon = Icons.touch_app_rounded;
      label = 'Ручная выдача';
      tip = 'Закрыто кассой или экспедитором вручную.';
    } else {
      icon = Icons.help_outline_rounded;
      label = 'Выдача';
      tip = 'Способ выдачи не записан (заказ до обновления).';
    }
    return Tooltip(
      message: tip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isWaiterOrderLabel(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v.contains('официант') || v.contains('waiter');
}

String _cashierBoardOrderTypeRu(String? orderTypeRaw) {
  final v = (orderTypeRaw ?? '').trim();
  if (v.isEmpty) return 'Заказ';
  final low = v.toLowerCase();
  if (low == 'delivery') return 'Доставка';
  if (low == 'pickup') return 'Самовывоз';
  if (low == 'parking') return 'Парковка';
  return v;
}

String _cashierOrderDisplayNumber({
  required String number,
  required String? orderTypeRaw,
}) {
  final cleanNumber = number.trim();
  if (cleanNumber.isEmpty) return cleanNumber;
  final low = (orderTypeRaw ?? '').trim().toLowerCase();
  if (low.contains('доставк') || low == 'delivery') {
    return 'Д-$cleanNumber';
  }
  if (low.contains('самовывоз') ||
      low.contains('с собой') ||
      low == 'pickup' ||
      low == 'takeaway' ||
      low == 'take_away' ||
      low == 'to_go') {
    return 'С-$cleanNumber';
  }
  return cleanNumber;
}

String _paymentHistoryTableFallback(LocalPaymentHistoryEntry e) {
  final ot = (e.orderType ?? '').trim().toLowerCase();
  if (ot.contains('собой') ||
      ot == 'takeaway' ||
      ot.contains('takeaway') ||
      ot.contains('take_away')) {
    return 'С собой';
  }
  if (ot.contains('доставк') || ot == 'delivery') {
    return 'Доставка';
  }
  return 'Без стола';
}

String _posReceiptPrintedShortRu(bool? printed) {
  if (printed == true) return 'Чек напечатан';
  if (printed == false) return 'Чек не напечатан';
  return 'Чек: нет данных';
}

String _posHardwarePrinterShortLabel(HardwareStatusSnapshot? s) {
  if (s == null) return 'Печать…';
  switch (s.receiptPrinterStatusCode) {
    case 'mock':
      return 'Печать: тест';
    case 'not_configured':
      return 'Печать: нет имени';
    case 'offline_or_missing':
      return 'Печать: офлайн';
    case 'online':
      return 'Печать: ОК';
    case 'probe_windows_only':
      return 'Печать: проверка…';
    case 'probe_failed':
      return 'Печать: ошибка';
    default:
      return 'Печать';
  }
}

String _posHardwarePrinterTooltip(HardwareStatusSnapshot s) {
  final buf = StringBuffer(_posHardwarePrinterShortLabel(s));
  final name = s.receiptPrinterName?.trim();
  if (name != null && name.isNotEmpty) {
    buf.writeln();
    buf.write('Принтер: $name');
  }
  if (s.driverPrinterStatus != null) {
    buf.writeln();
    buf.write('Драйвер: ${s.driverPrinterStatus}');
  }
  final err = s.probeError?.trim();
  if (err != null && err.isNotEmpty) {
    buf.writeln();
    buf.write(err);
  }
  return buf.toString();
}

bool _canUseCashierBoard(String? role) =>
    role == 'cashier' || role == 'admin' || role == 'waiter';

bool _canManageOnlineOrders(String? role) =>
    role == 'cashier' || role == 'admin';

@RoutePage()
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uiLang = context.appUiLocale.languageCode;
    final apiLang = menuApiLanguageCode(uiLang);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              MenuBloc(context.read<MenuRepository>())
                ..add(MenuLoadRequested(lang: apiLang)),
        ),
        BlocProvider(create: (_) => PosHallOrdersCubit()),
      ],
      child: const _PosView(),
    );
  }
}

class _PosView extends StatefulWidget {
  const _PosView();

  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView> {
  Timer? _expeditorQueueTimer;
  Timer? _openTableBillsTimer;
  Timer? _tableSessionPruneTimer;
  Timer? _cashierSessionRefreshDebounce;
  final LocalOrdersRealtime _posOrdersRealtime = LocalOrdersRealtime.instance;
  bool _posRealtimeAcquired = false;
  StreamSubscription<LocalOrdersRealtimeEvent>? _posOrdersRealtimeSub;
  int _expeditorBundlingCount = 0;
  int _expeditorPickupCount = 0;
  List<LocalCashierBoardOrder> _incomingBoard = const [];
  List<LocalCashierBoardOrder> _activeBoard = const [];
  bool _cashierSessionRefreshInFlight = false;
  DateTime? _lastCashierSessionRefreshAt;
  bool _expeditorRefreshInFlight = false;

  final AudioPlayer _cashierAlertPlayer = AudioPlayer();
  bool _cashierAlertInitialized = false;
  bool _expeditorPickupSoundPrimed = false;
  final Set<String> _knownIncomingOrderIds = <String>{};
  final Set<String> _knownOpenTableBillIds = <String>{};
  final GlobalKey<ScaffoldState> _posScaffoldKey = GlobalKey<ScaffoldState>();

  /// Локальный код точки: `AppConfig.storeBranchId` (franchise id из лицензии).
  String get _branchId => AppConfig.storeBranchId;

  /// Заказы с сайта (`order_source=website`) — только раздел «Онлайн заказы».
  List<LocalCashierBoardOrder> get _incomingWebsiteOrders => _incomingBoard
      .where((o) => (o.orderSource ?? 'pos').toLowerCase() == 'website')
      .toList(growable: false);

  /// Прочие входящие без стола — показываем в общем списке «Заказы».
  List<LocalCashierBoardOrder> get _incomingNonWebsiteOrders => _incomingBoard
      .where((o) => (o.orderSource ?? 'pos').toLowerCase() != 'website')
      .toList(growable: false);

  /// Входящие сайт + активные сайт без дублей по id (входящие первыми).
  List<LocalCashierBoardOrder> get _allWebsiteCashierOrders {
    final inc = _incomingWebsiteOrders;
    final incIds = inc.map((e) => e.order.id).toSet();
    final act =
        _activeBoard.where((o) => (o.orderSource ?? 'pos').toLowerCase() == 'website' && !incIds.contains(o.order.id));
    return [...inc, ...act];
  }

  bool get _customerDisplaySupported =>
      CustomerDisplayWindowService.instance.isSupportedPlatform;
  bool get _customerDisplayEnabledByConfig =>
      !AppConfig.isCustomerDisplayWindowDisabled;
  bool get _canUseCustomerDisplay =>
      _customerDisplaySupported && _customerDisplayEnabledByConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _syncExpeditorPollingForCashier();
      _startCashierSessionSync();
      final role = context.read<AuthBloc>().state.user?.role;
      if (role == 'cashier' || role == 'admin') {
        await ensureCashShiftOpen(context);
        if (_canUseCustomerDisplay && mounted) {
          await _autoOpenCustomerDisplay(silent: true);
        }
      }
    });
  }

  void _startCashierSessionSync() {
    final role = context.read<AuthBloc>().state.user?.role;
    if (!_canUseCashierBoard(role)) {
      _openTableBillsTimer?.cancel();
      _openTableBillsTimer = null;
      _tableSessionPruneTimer?.cancel();
      _tableSessionPruneTimer = null;
      _cashierSessionRefreshDebounce?.cancel();
      _cashierSessionRefreshDebounce = null;
      _posOrdersRealtimeSub?.cancel();
      _posOrdersRealtimeSub = null;
      if (_posRealtimeAcquired) {
        _posRealtimeAcquired = false;
        unawaited(_posOrdersRealtime.release());
      }
      _cashierSessionRefreshInFlight = false;
      _lastCashierSessionRefreshAt = null;
      _cashierAlertInitialized = false;
      _expeditorPickupSoundPrimed = false;
      _knownIncomingOrderIds.clear();
      _knownOpenTableBillIds.clear();
      unawaited(CustomerDisplayWindowService.instance.close());
      if (mounted) {
        setState(() {
          _incomingBoard = const [];
          _activeBoard = const [];
        });
      }
      return;
    }
    _openTableBillsTimer?.cancel();
    _openTableBillsTimer = Timer.periodic(
      Duration(seconds: AppConfig.cashierRefreshIntervalSec),
      (_) => _requestCashierSessionRefresh(),
    );
    _tableSessionPruneTimer?.cancel();
    _tableSessionPruneTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      try {
        context.read<PosHallOrdersCubit>().pruneExpiredTableSessions();
      } catch (_) {}
    });
    _requestCashierSessionRefresh(immediate: true);
    unawaited(_ensurePosOrdersRealtime());
  }

  Future<void> _ensurePosOrdersRealtime() async {
    await _posOrdersRealtimeSub?.cancel();
    _posOrdersRealtimeSub = null;
    try {
      if (!_posRealtimeAcquired) {
        await _posOrdersRealtime.acquire(branchId: _branchId, clientType: 'pos');
        _posRealtimeAcquired = true;
      } else {
        await _posOrdersRealtime.connect(branchId: _branchId, clientType: 'pos');
      }
    } catch (_) {
      return;
    }
    _posOrdersRealtimeSub = _posOrdersRealtime.events.listen((e) {
      final t = e.type;
      if (t == 'cashier.board_changed') {
        final patches = parseCashierBoardPatches(e.payload['patches']);
        if (patches.isNotEmpty) {
          final cubit = context.read<PosHallOrdersCubit>();
          final nextBills = applyCashierOpenTableBillPatches(
            cubit.state.bills,
            patches,
          );
          // Патч уже полный снимок затронутых id — без merge «оплаченных навсегда».
          cubit.replaceBillsFromPatchedList(nextBills);
          cubit.pruneExpiredTableSessions();

          setState(() {
            _incomingBoard = applyCashierIncomingPatches(_incomingBoard, patches);
            _activeBoard = applyCashierActivePatches(_activeBoard, patches);
          });
          return;
        }
        // Патчей нет (старый сервер / сбой сборки) — редкий full refresh с minGap.
        _requestCashierSessionRefresh();
        return;
      }
      if (t == 'order.created' ||
          t == 'order.updated' ||
          t == 'payment.accepted' ||
          t == 'order.status_changed') {
        // Источник правды — cashier.board_changed с патчами.
        // Full refresh оставляем таймеру и случаю, когда патчей нет (старый сервер).
        return;
      }
    });
  }

  void _requestCashierSessionRefresh({bool immediate = false}) {
    if (!mounted) return;
    final role = context.read<AuthBloc>().state.user?.role;
    if (!_canUseCashierBoard(role)) return;
    if (_cashierSessionRefreshInFlight) return;

    final now = DateTime.now();
    final minGap = Duration(milliseconds: AppConfig.cashierRealtimeMinGapMs);
    final last = _lastCashierSessionRefreshAt;
    final canRunNow =
        immediate || last == null || now.difference(last) >= minGap;

    if (canRunNow) {
      unawaited(_runCashierSessionRefresh());
      return;
    }

    final wait = minGap - now.difference(last);
    _cashierSessionRefreshDebounce?.cancel();
    _cashierSessionRefreshDebounce = Timer(wait, () {
      _requestCashierSessionRefresh(immediate: true);
    });
  }

  Future<void> _runCashierSessionRefresh() async {
    if (_cashierSessionRefreshInFlight) return;
    _cashierSessionRefreshInFlight = true;
    try {
      await _refreshCashierSessionData();
      _lastCashierSessionRefreshAt = DateTime.now();
    } finally {
      _cashierSessionRefreshInFlight = false;
    }
  }

  Future<void> _refreshCashierSessionData() async {
    final newTableBill = await _refreshOpenTableBills(sessionBatch: true);
    final incoming = await _refreshCashierBoard(sessionBatch: true);
    if (!mounted) return;
    if (!_cashierAlertInitialized) {
      _cashierAlertInitialized = true;
      return;
    }
    unawaited(
      _playCashierSessionSounds(
        newBill: newTableBill,
        newWebsite: incoming.newWebsite,
        newOther: incoming.newOther,
      ),
    );
  }

  /// Новые счета на оплату (по данным сервера). `true` — появился id, которого не было в прошлом опросе.
  Future<bool> _refreshOpenTableBills({bool sessionBatch = false}) async {
    if (!mounted) return false;
    final role = context.read<AuthBloc>().state.user?.role;
    if (!_canUseCashierBoard(role)) return false;
    try {
      final dtos = await context.read<LocalOrdersRepository>().fetchOpenTableBills(
            branchId: _branchId,
          );
      if (!mounted) return false;
      // Алерт только по неоплаченным (оплаченная сессия стола — не «новый счёт»).
      final unpaidIds = dtos
          .where((d) => d.id.isNotEmpty && !d.isPaid)
          .map((d) => d.id)
          .toSet();
      final hasNew = _cashierAlertInitialized &&
          unpaidIds.difference(_knownOpenTableBillIds).isNotEmpty;
      _knownOpenTableBillIds
        ..clear()
        ..addAll(unpaidIds);

      final bills = dtos
          .where(
            (d) =>
                d.id.isNotEmpty &&
                d.status.trim().toLowerCase() != 'cancelled',
          )
          .map(posTableBillFromServerDto)
          .toList(growable: false);
      context.read<PosHallOrdersCubit>().mergeHydrateFromServer(bills);
      if (hasNew && !sessionBatch) {
        unawaited(
          _playCashierSessionSounds(newBill: true, newWebsite: false, newOther: false),
        );
      }
      return hasNew;
    } catch (_) {
      return false;
    }
  }

  /// Входящие на кассу: новые id в «принять».
  Future<({bool newWebsite, bool newOther})> _refreshCashierBoard({
    bool sessionBatch = false,
  }) async {
    if (!mounted) return (newWebsite: false, newOther: false);
    final role = context.read<AuthBloc>().state.user?.role;
    if (!_canUseCashierBoard(role)) return (newWebsite: false, newOther: false);
    try {
      final repo = context.read<LocalOrdersRepository>();
      final pair = await Future.wait<List<LocalCashierBoardOrder>>([
        repo.fetchCashierIncomingOrders(branchId: _branchId),
        repo.fetchCashierActiveOrders(branchId: _branchId),
      ]);
      final incoming = pair[0];
      final active = pair[1];
      if (!mounted) return (newWebsite: false, newOther: false);
      final ids = incoming.map((e) => e.order.id).where((id) => id.isNotEmpty).toSet();
      final previousKnown = Set<String>.from(_knownIncomingOrderIds);

      var newWebsite = false;
      var newOther = false;
      if (_cashierAlertInitialized) {
        final newIds = ids.difference(previousKnown);
        final byId = {for (final o in incoming) o.order.id: o};
        for (final id in newIds) {
          final row = byId[id];
          if (row == null) continue;
          if ((row.orderSource ?? 'pos').toLowerCase() == 'website') {
            newWebsite = true;
          } else {
            newOther = true;
          }
        }
      }

      _knownIncomingOrderIds
        ..clear()
        ..addAll(ids);

      setState(() {
        _incomingBoard = incoming;
        _activeBoard = active;
      });
      if (!sessionBatch && (newWebsite || newOther)) {
        unawaited(
          _playCashierSessionSounds(
            newBill: false,
            newWebsite: newWebsite,
            newOther: newOther,
          ),
        );
      }
      return (newWebsite: newWebsite, newOther: newOther);
    } catch (_) {
      return (newWebsite: false, newOther: false);
    }
  }

  String? _firstNonEmptySoundPath(Iterable<String?> paths) {
    for (final p in paths) {
      final t = (p ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  Future<void> _playCashierAlertPath(String path) async {
    if (!mounted) return;
    final url = AppConfig.mediaUrl(path);
    if (url.isEmpty) return;
    try {
      await _cashierAlertPlayer.stop();
      await _cashierAlertPlayer.play(UrlSource(url));
    } catch (_) {
      // не мешаем кассе
    }
  }

  /// Кастом из админки → WAV из assets → системный alert (как на кухне).
  Future<void> _playCashierAlertWithFallback(String? uploadPath) async {
    if (!mounted) return;
    final custom = (uploadPath ?? '').trim();
    if (custom.isNotEmpty) {
      await _playCashierAlertPath(custom);
      return;
    }
    try {
      await KitchenOrderAlert.play(_cashierAlertPlayer);
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Касса: онлайн отдельно, затем новый счёт / прочие входящие — свой звук из админки.
  Future<void> _playCashierSessionSounds({
    required bool newBill,
    required bool newWebsite,
    required bool newOther,
  }) async {
    if (!newBill && !newWebsite && !newOther) return;
    if (!mounted) return;
    try {
      final settings = await context.read<LocalAudioSettingsRepository>().fetch(
            branchId: _branchId,
          );
      if (newWebsite) {
        final path = _firstNonEmptySoundPath([
          settings.websiteOrderSoundPath,
          settings.readySoundPath,
          settings.kitchenSoundPath,
        ]);
        await _playCashierAlertWithFallback(path);
        await Future<void>.delayed(const Duration(milliseconds: 320));
        if (!mounted) return;
      }
      if (newBill || newOther) {
        final path = _firstNonEmptySoundPath([
          settings.readySoundPath,
          settings.kitchenSoundPath,
        ]);
        await _playCashierAlertWithFallback(path);
      }
    } catch (_) {
      // не мешаем кассе
    }
  }

  Future<void> _playCashierReadySound() async {
    if (!mounted) return;
    try {
      final settings = await context.read<LocalAudioSettingsRepository>().fetch(
            branchId: _branchId,
          );
      final path = _firstNonEmptySoundPath([
        settings.readySoundPath,
        settings.kitchenSoundPath,
      ]);
      await _playCashierAlertWithFallback(path);
    } catch (_) {
      // не мешаем кассе
    }
  }

  Future<void> _onAcceptIncoming(LocalCashierBoardOrder row) async {
    if (!mounted) return;
    try {
      await context.read<LocalOrdersRepository>().acknowledgeCashierIncomingOrder(
            orderId: row.order.id,
            branchId: _branchId,
          );
      if (!mounted) return;
      // Оптимистично убираем из входящих; полный снимок придёт по cashier.board_changed.
      setState(() {
        _incomingBoard = _incomingBoard
            .where((e) => e.order.id != row.order.id)
            .toList(growable: false);
      });
      // Без double HTTP: WS-патч обновит board/счета. Fallback — только если WS мёртв.
      if (!LocalOrdersRealtime.instance.isConnected) {
        _requestCashierSessionRefresh();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Заказ №${_cashierOrderDisplayNumber(number: row.order.number, orderTypeRaw: row.orderType)} принят на кассе',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _syncExpeditorPollingForCashier() {
    final user = context.read<AuthBloc>().state.user;
    _expeditorQueueTimer?.cancel();
    _expeditorQueueTimer = null;
    if (!AppConfig.posEnableExpeditor) {
      _expeditorRefreshInFlight = false;
      _expeditorPickupSoundPrimed = false;
      if (mounted) {
        setState(() {
          _expeditorBundlingCount = 0;
          _expeditorPickupCount = 0;
        });
      }
      return;
    }
    if (user?.role != 'cashier') {
      _expeditorRefreshInFlight = false;
      _expeditorPickupSoundPrimed = false;
      if (mounted) {
        setState(() {
          _expeditorBundlingCount = 0;
          _expeditorPickupCount = 0;
        });
      }
      return;
    }
    _expeditorQueueTimer = Timer.periodic(
      Duration(seconds: AppConfig.expeditorRefreshIntervalSec),
      (_) {
        // При живом shared WS бейдж обновляется из panel/событий реже — HTTP как fallback.
        if (!LocalOrdersRealtime.instance.isConnected) {
          _refreshExpeditorQueueCounts();
        }
      },
    );
    unawaited(_refreshExpeditorQueueCounts());
  }

  Future<void> _refreshExpeditorQueueCounts() async {
    if (!mounted) return;
    if (context.read<AuthBloc>().state.user?.role != 'cashier') return;
    if (_expeditorRefreshInFlight) return;
    _expeditorRefreshInFlight = true;
    final prevPickup = _expeditorPickupCount;
    try {
      final snap = await context.read<LocalOrdersRepository>().fetchExpeditorQueue();
      if (!mounted) return;
      final pickupUp = snap.pickup.length > prevPickup;
      setState(() {
        _expeditorBundlingCount = snap.bundling.length;
        _expeditorPickupCount = snap.pickup.length;
      });
      if (AppConfig.posEnableExpeditor &&
          _expeditorPickupSoundPrimed &&
          pickupUp) {
        unawaited(_playCashierReadySound());
      }
      _expeditorPickupSoundPrimed = true;
    } catch (_) {
      // сеть/API — не блокируем кассу
    } finally {
      _expeditorRefreshInFlight = false;
    }
  }

  String _ordersWorkspaceValue(AppLocalizations l10n) {
    if (context.read<AuthBloc>().state.user?.role != 'cashier') {
      return l10n.posOrdersWorkspaceValueHint;
    }
    return l10n.posOrdersTileSummary(
      _expeditorBundlingCount,
      _expeditorPickupCount,
    );
  }

  @override
  void dispose() {
    _expeditorQueueTimer?.cancel();
    _openTableBillsTimer?.cancel();
    _tableSessionPruneTimer?.cancel();
    _cashierSessionRefreshDebounce?.cancel();
    _posOrdersRealtimeSub?.cancel();
    if (_posRealtimeAcquired) {
      _posRealtimeAcquired = false;
      unawaited(_posOrdersRealtime.release());
    }
    _cashierAlertPlayer.dispose();
    super.dispose();
  }

  void _logout(BuildContext context) async {
    await performPosSessionLogout(context);
  }

  Future<void> _handleCatalogItemAdd(
    PosMenuItem item,
    Rect sourceGlobalRect,
  ) async {
    if (item.allowCustomPrice) {
      final customPrice = await _showCustomPriceDialog(context, item);
      if (!mounted || customPrice == null) return;
      context.read<CartBloc>().add(CartItemAdded(item, unitPrice: customPrice));
      return;
    }
    if (item.variableSaleQtyEnabled) {
      if (item.hasModifiers) {
        await showPosModifierSheet(context, item: item, withVariableQty: true);
      } else {
        await showPosVariableQtySheet(context, item: item);
      }
      return;
    }
    if (item.hasModifiers) {
      await showPosModifierSheet(context, item: item);
      return;
    }
    context.read<CartBloc>().add(CartItemAdded(item));
  }

  Future<void> _changeOrderTable(LocalCashierBoardOrder row) async {
    final result = await changePosOrderTable(
      context,
      orderId: row.order.id,
      currentTableLabel: row.tableLabel,
      orderType: row.orderType,
    );
    if (!mounted || result == null) return;
    setState(() {
      LocalCashierBoardOrder patch(LocalCashierBoardOrder o) {
        if (o.order.id != row.order.id) return o;
        return o.copyWith(
          tableLabel: result.cleared ? '' : result.tableLabel,
          orderType: result.orderTypeLabel ?? o.orderType,
          clearTableLabel: result.cleared,
        );
      }

      _activeBoard = [for (final o in _activeBoard) patch(o)];
      _incomingBoard = [for (final o in _incomingBoard) patch(o)];
    });
  }

  Future<void> _changeOrderType(LocalCashierBoardOrder row) async {
    final result = await changePosOrderType(
      context,
      orderId: row.order.id,
      currentOrderType: row.orderType,
      currentTableLabel: row.tableLabel,
    );
    if (!mounted || result == null) return;
    setState(() {
      LocalCashierBoardOrder patch(LocalCashierBoardOrder o) {
        if (o.order.id != row.order.id) return o;
        return o.copyWith(
          orderType: result.orderTypeLabel,
          tableLabel: result.tableLabel,
          clearTableLabel: result.tableCleared,
        );
      }

      _activeBoard = [for (final o in _activeBoard) patch(o)];
      _incomingBoard = [for (final o in _incomingBoard) patch(o)];
    });
  }

  Future<void> _freeOrderTable(LocalCashierBoardOrder row) async {
    final result = await clearPosOrderTable(context, orderId: row.order.id);
    if (!mounted || result == null) return;
    setState(() {
      LocalCashierBoardOrder patch(LocalCashierBoardOrder o) {
        if (o.order.id != row.order.id) return o;
        return o.copyWith(tableLabel: '', clearTableLabel: true);
      }

      _activeBoard = [for (final o in _activeBoard) patch(o)];
      _incomingBoard = [for (final o in _incomingBoard) patch(o)];
    });
  }

  Future<void> _showOrdersDialog() async {
    await _refreshCashierBoard();
    if (!mounted) return;
    final showHandoffTab = context.read<AuthBloc>().state.user?.role == 'cashier' &&
        AppConfig.posEnableExpeditor;
    final mergedOrders = <LocalCashierBoardOrder>[
      ..._incomingNonWebsiteOrders,
      ..._activeBoard.where((o) => (o.orderSource ?? 'pos').toLowerCase() != 'website'),
    ];
    final canManageOnline = _canManageOnlineOrders(
      context.read<AuthBloc>().state.user?.role,
    );
    final canHandoff = context.read<AuthBloc>().state.user?.role != 'waiter';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _PosOrdersDialog(
        showHandoffTab: showHandoffTab,
        canManageOnlineOrders: canManageOnline,
        canHandoffOrders: canHandoff,
        orders: List<LocalCashierBoardOrder>.unmodifiable(mergedOrders),
        onCashierAck: (order) async {
          Navigator.of(dialogContext).pop();
          await _onAcceptIncoming(order);
          if (mounted) await _showOrdersDialog();
        },
        onCloseOrder: (order) async {
          Navigator.of(dialogContext).pop();
          await _closeActiveOrder(order);
          if (mounted) await _showOrdersDialog();
        },
        onCancelOrder: (order) async {
          Navigator.of(dialogContext).pop();
          await _cancelActiveOrder(order);
          if (mounted) await _showOrdersDialog();
        },
        onCallCustomer: (order) {
          final label = order.tableLabel?.trim() ?? '';
          final meta = parseWebsiteOrderDeliveryMeta(label);
          callWebsiteOrderCustomer(context, meta.phone);
        },
        onChangeTable: (order) async {
          await _changeOrderTable(order);
          if (mounted) {
            Navigator.of(dialogContext).pop();
            await _showOrdersDialog();
          }
        },
        onChangeOrderType: (order) async {
          await _changeOrderType(order);
          if (mounted) {
            Navigator.of(dialogContext).pop();
            await _showOrdersDialog();
          }
        },
        onFreeTable: (order) async {
          await _freeOrderTable(order);
          if (mounted) {
            Navigator.of(dialogContext).pop();
            await _showOrdersDialog();
          }
        },
      ),
    ).then((_) => _refreshExpeditorQueueCounts());
  }

  Future<void> _showOnlineOrdersDialog() async {
    if (!_canManageOnlineOrders(context.read<AuthBloc>().state.user?.role)) {
      return;
    }
    await _refreshCashierBoard();
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _OnlineOrdersDialog(
        orders: List<LocalCashierBoardOrder>.unmodifiable(_allWebsiteCashierOrders),
        onCashierAck: (order) async {
          Navigator.of(dialogContext).pop();
          await _onAcceptIncoming(order);
          if (mounted) await _showOnlineOrdersDialog();
        },
        onCloseOrder: (order) async {
          Navigator.of(dialogContext).pop();
          await _closeActiveOrder(order);
          if (mounted) await _showOnlineOrdersDialog();
        },
        onCancelOrder: (order) async {
          Navigator.of(dialogContext).pop();
          await _cancelActiveOrder(order);
          if (mounted) await _showOnlineOrdersDialog();
        },
        onEditOrder: (order) async {
          Navigator.of(dialogContext).pop();
          await startOnlineOrderEditWithCustomerConsent(
            context,
            row: order,
            onAcknowledgeIncoming: () => _onAcceptIncoming(order),
          );
        },
        onCallCustomer: (order) {
          final label = order.tableLabel?.trim() ?? '';
          final meta = parseWebsiteOrderDeliveryMeta(label);
          callWebsiteOrderCustomer(context, meta.phone);
        },
      ),
    );
  }

  Future<void> _showTodayPaymentsHistoryDialog() async {
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return;
    if (!mounted) return;
    final allowed = await showCashierPasswordGate(
      context,
      title: 'Оплаты за сегодня',
      subtitle: role == 'admin'
          ? 'Введите пароль администратора'
          : 'Введите пароль кассира для просмотра чеков',
      withKeypad: true,
    );
    if (!allowed || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _TodayPaymentsDialogLoader(
        branchId: _branchId,
        lang: context.appUiLocale.languageCode,
        showTotals: role == 'admin',
      ),
    );
  }

  Future<void> _closeActiveOrder(LocalCashierBoardOrder row) async {
    if (!mounted) return;
    final ordersRepo = context.read<LocalOrdersRepository>();
    final o = row.order;
    final messenger = ScaffoldMessenger.of(context);
    var status = o.status.toLowerCase();
    if (status == 'awaiting_expeditor' && !AppConfig.posEnableExpeditor) {
      try {
        await ordersRepo.handoffOrder(
              orderId: o.id,
              action: 'confirm_ready',
            );
        status = 'ready';
      } catch (_) {
        // Если перевести в ready не удалось, оставим ручное подтверждение ниже.
      }
    }
    final notReady = status != 'ready';
    final needsPayment = row.requiresPayment;
    final isWebsite = (row.orderSource ?? 'pos').toLowerCase() == 'website';
    final isDelivery = (row.orderType ?? '').trim().toLowerCase() == 'delivery';
    if (notReady || needsPayment) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Закрыть заказ?'),
            content: Text(
              [
                if (notReady)
                  'Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} ещё не в статусе «Готов».',
                if (needsPayment)
                  'Оплата ещё не проведена — после выдачи примите её в «Счета на оплату».',
                'Подтвердите ручное закрытие/выдачу.',
              ].join('\n'),
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
      if (ok != true || !mounted) return;
    }
    try {
      if (isWebsite && isDelivery) {
        final rawLabel = row.tableLabel?.trim() ?? '';
        final meta = parseWebsiteOrderDeliveryMeta(rawLabel);
        final fallbackAddress =
            rawLabel.isNotEmpty && meta.label != rawLabel ? rawLabel : null;
        final deliveryAddress = meta.address ?? fallbackAddress;
        try {
          await context.read<LocalHardwareRepository>().printReceipt(
                orderId: o.id,
                totalAmount: o.totalPrice,
                paymentMethod: 'courier_delivery',
                receiptTitle: 'ЧЕК ДЛЯ КУРЬЕРА',
                customerName: meta.contact,
                customerPhone: meta.phone,
                deliveryAddress: deliveryAddress,
                deliveryNote: meta.comment,
              );
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Печать чека курьеру не удалась: $e')),
            );
          }
        }
      }
      await ordersRepo.handoffOrder(
            orderId: o.id,
            action: 'hand_out',
          );
      await _refreshCashierBoard();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            needsPayment
                ? 'Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} выдан. Оплату проведите в «Счета на оплату».'
                : 'Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} выдан',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancelActiveOrder(LocalCashierBoardOrder row) async {
    if (!mounted) return;
    final o = row.order;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _pickCancelReason(context);
    if (reason == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Отменить заказ?'),
          content: Text(
            [
              'Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} будет переведен в статус «Отменен».',
              if (row.requiresPayment)
                'По заказу стоит отметка «нужна оплата». Проверьте с гостем перед отменой.',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Нет'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Отменить'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<LocalOrdersRepository>().cancelOrder(
            orderId: o.id,
            reason: reason,
            branchId: _branchId,
          );
      await _refreshCashierBoard();
      await _refreshOpenTableBills();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} отменен',
          ),
        ),
      );
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('оплачен')) {
        final doRefund = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Заказ уже оплачен'),
            content: const Text(
              'Для отмены нужен возврат.\nСделать возврат сейчас и распечатать чек возврата?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Нет'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Сделать возврат'),
              ),
            ],
          ),
        );
        if (doRefund == true && mounted) {
          try {
            final refund = await context.read<LocalPaymentsRepository>().refundOrderPayment(
                  orderId: o.id,
                  reason: 'cancel:$reason',
                  cancelOrder: true,
                  branchId: _branchId,
                );
            await _refreshCashierBoard();
            if (!mounted) return;
            final hardwareHint = refund.hardware?.buildHint();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  hardwareHint == null || hardwareHint.isEmpty
                      ? 'Возврат выполнен. Заказ №${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: row.orderType)} отменен'
                      : 'Возврат выполнен. $hardwareHint',
                ),
              ),
            );
            return;
          } on ApiException catch (refundError) {
            if (!mounted) return;
            messenger.showSnackBar(SnackBar(content: Text(refundError.message)));
            return;
          } catch (refundError) {
            if (!mounted) return;
            messenger.showSnackBar(SnackBar(content: Text(refundError.toString())));
            return;
          }
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String?> _pickCancelReason(BuildContext context) async {
    // value → текст для клиента (уходит в cancel_reason).
    const predefined = <({String id, String label})>[
      (id: 'ошибка_кассира', label: 'Ошибка кассира'),
      (id: 'гость_отказался', label: 'Гость отказался'),
      (id: 'нет_товара', label: 'Нет товара'),
      (id: 'другое', label: 'Другое'),
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final customCtrl = TextEditingController();
        var selected = predefined.first.id;
        return StatefulBuilder(
          builder: (context, setState) {
            final needsCustom = selected == 'другое';
            final custom = customCtrl.text.trim();
            final canSubmit = !needsCustom || custom.isNotEmpty;
            return AlertDialog(
              title: const Text('Причина отмены'),
              content: SizedBox(
                width: _dialogWidth(ctx, 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final reason in predefined)
                          ChoiceChip(
                            label: Text(reason.label),
                            selected: selected == reason.id,
                            onSelected: (_) =>
                                setState(() => selected = reason.id),
                          ),
                      ],
                    ),
                    if (needsCustom) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Укажите причину',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: canSubmit
                      ? () {
                          if (needsCustom) {
                            Navigator.of(ctx).pop(customCtrl.text.trim());
                            return;
                          }
                          final label = predefined
                              .firstWhere((r) => r.id == selected)
                              .label;
                          Navigator.of(ctx).pop(label);
                        }
                      : null,
                  child: const Text('Далее'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _autoOpenCustomerDisplay({bool silent = false}) async {
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return;
    if (!_canUseCustomerDisplay) return;
    await _openCustomerDisplayInternal(
      showAlreadyOpenMessage: false,
      showSuccessMessage: !silent,
      showFailureMessage: !silent,
    );
  }

  Future<void> _openCustomerDisplayByClick() async {
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return;
    await _openCustomerDisplayInternal(
      showAlreadyOpenMessage: true,
      showSuccessMessage: true,
      showFailureMessage: true,
    );
  }

  Future<void> _closeCustomerDisplayByClick() async {
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return;
    if (!CustomerDisplayWindowService.instance.isOpen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экран клиента не открыт')),
      );
      return;
    }
    await CustomerDisplayWindowService.instance.close();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Экран клиента закрыт')),
    );
  }

  Future<void> _openCustomerDisplayInternal({
    required bool showAlreadyOpenMessage,
    required bool showSuccessMessage,
    required bool showFailureMessage,
  }) async {
    if (!_customerDisplaySupported) {
      if (!mounted || !showFailureMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Экран клиента доступен только на Windows-версии POS'),
        ),
      );
      return;
    }
    if (AppConfig.isCustomerDisplayWindowDisabled) {
      if (!mounted || !showFailureMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Экран клиента отключен в .env (POS_DISABLE_CUSTOMER_DISPLAY=true)',
          ),
        ),
      );
      return;
    }
    try {
      final cartState = context.read<CartBloc>().state;
      final menuState = context.read<MenuBloc>().state;
      final config = await _loadCustomerDisplayConfig();
      final result =
          await CustomerDisplayWindowService.instance.openCustomerDisplay(
        cart: cartState,
        menu: menuState,
        config: config,
      );
      if (result != CustomerDisplayOpenResult.failed) {
        await CustomerDisplayWindowService.instance.setDisplayContentConfig(
          config,
          cartState,
        );
      }
      if (!mounted) return;
      switch (result) {
        case CustomerDisplayOpenResult.alreadyOpen:
          if (showAlreadyOpenMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Окно клиента уже открыто')),
            );
          }
        case CustomerDisplayOpenResult.opened:
          if (showSuccessMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Экран клиента открыт: чек и QR активны'),
              ),
            );
          }
        case CustomerDisplayOpenResult.failed:
          if (showFailureMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Не удалось открыть экран клиента. Проверьте второй монитор и настройки Windows.',
                ),
              ),
            );
          }
      }
    } catch (e) {
      if (!mounted || !showFailureMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть экран клиента: $e')),
      );
    }
  }

  Widget _customerDisplayToolbarActions() {
    return ValueListenableBuilder<bool>(
      valueListenable: CustomerDisplayWindowService.instance.openNotifier,
      builder: (context, isOpen, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isOpen ? Icons.tv_rounded : Icons.tv_outlined),
              tooltip: isOpen ? 'Экран клиента (открыт)' : 'Открыть экран клиента',
              onPressed: _openCustomerDisplayByClick,
            ),
            if (isOpen)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Закрыть экран клиента',
                onPressed: _closeCustomerDisplayByClick,
              ),
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Обновить экран клиента',
              onPressed: _refreshCustomerDisplayConfigByClick,
            ),
          ],
        );
      },
    );
  }

  Future<CustomerDisplayContentConfig?> _loadCustomerDisplayConfig() async {
    try {
      final screens = await context.read<ScreensAdminRepository>().fetchScreens(
            activeOnly: true,
          );
      final customerScreens = screens
          .where((s) => s.type == 'customer_display' && s.isActive)
          .toList(growable: false);
      if (customerScreens.isEmpty) return null;
      customerScreens.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return CustomerDisplayContentConfig.fromScreenConfig(
        customerScreens.first.config,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshCustomerDisplayConfigByClick() async {
    if (!mounted) return;
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return;
    if (!_customerDisplaySupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Экран клиента доступен только на Windows-версии POS'),
        ),
      );
      return;
    }
    if (AppConfig.isCustomerDisplayWindowDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Экран клиента отключен в .env (POS_DISABLE_CUSTOMER_DISPLAY=true)',
          ),
        ),
      );
      return;
    }
    try {
      final cartState = context.read<CartBloc>().state;
      final config = await _loadCustomerDisplayConfig();
      await CustomerDisplayWindowService.instance.setDisplayContentConfig(
        config,
        cartState,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экран клиента обновлен из админки')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить экран клиента: $e')),
      );
    }
  }

  Future<void> _showSettingsDialog() {
    final screenContext = context;
    final localeBloc = context.read<LocaleBloc>();
    var selectedLocaleCode = localeBloc.state.locale.languageCode;
    final role = context.read<AuthBloc>().state.user?.role;
    final isAdmin = role == 'admin';
    final http = context.read<HttpClient>();
    final dioClient = http is DioHttpClient ? http : null;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;

            return AlertDialog(
              backgroundColor: scheme.surfaceContainerLow,
              title: Text(
                'Настройки POS',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: _dialogWidth(dialogContext, 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      'Язык',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SettingsChoiceChip(
                          label: 'Русский',
                          selected: selectedLocaleCode == 'ru',
                          onTap: () {
                            setModalState(() => selectedLocaleCode = 'ru');
                            localeBloc.add(const LocaleChanged(Locale('ru')));
                          },
                        ),
                        _SettingsChoiceChip(
                          label: 'English',
                          selected: selectedLocaleCode == 'en',
                          onTap: () {
                            setModalState(() => selectedLocaleCode = 'en');
                            localeBloc.add(const LocaleChanged(Locale('en')));
                          },
                        ),
                        _SettingsChoiceChip(
                          label: 'Тоҷикӣ',
                          selected: selectedLocaleCode == 'tg',
                          onTap: () {
                            setModalState(() => selectedLocaleCode = 'tg');
                            localeBloc.add(const LocaleChanged(Locale('tg')));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Тема',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    BlocBuilder<PosThemeCubit, PosThemeSettings>(
                      builder: (context, posTheme) {
                        return Row(
                          children: [
                            Expanded(
                              child: _SettingsChoiceChip(
                                label: 'Светлая',
                                selected: posTheme.mode == PosScreenTheme.light,
                                icon: Icons.light_mode_rounded,
                                onTap: () => context
                                    .read<PosThemeCubit>()
                                    .setTheme(PosScreenTheme.light),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SettingsChoiceChip(
                                label: 'Темная',
                                selected: posTheme.mode == PosScreenTheme.dark,
                                icon: Icons.dark_mode_rounded,
                                onTap: () => context
                                    .read<PosThemeCubit>()
                                    .setTheme(PosScreenTheme.dark),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Divider(),
                    const SizedBox(height: 16),
                    PosServerEndpointEditor(
                      compact: true,
                      allowSaveOnServer: isAdmin,
                      httpClient: dioClient,
                    ),
                    if (role == 'cashier') ...[
                      const SizedBox(height: 18),
                      const Divider(),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(screenContext).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminInventoryReceiveScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Принять накладную со склада'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    const PosBoardLayoutSettingsEditor(),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    const PosCashierBoardSettingsEditor(),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    const PosCartPanelSettingsEditor(),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 16),
                    const PosCatalogGridSettingsEditor(),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final user = context.watch<AuthBloc>().state.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<LocaleBloc, LocaleState>(
          listenWhen: (p, c) => p.locale != c.locale,
          listener: (context, localeState) {
            context.read<MenuBloc>().add(
              MenuLoadRequested(
                lang: menuApiLanguageCode(localeState.locale.languageCode),
              ),
            );
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) => prev.user?.role != curr.user?.role,
          listener: (context, state) => _syncExpeditorPollingForCashier(),
        ),
        BlocListener<CartBloc, CartState>(
          listenWhen: (prev, curr) =>
              prev.itemCount != curr.itemCount || prev.total != curr.total,
          listener: (context, cart) {
            unawaited(CustomerDisplayWindowService.instance.syncCart(cart));
          },
        ),
      ],
      child: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, menu) {
          return BlocBuilder<CartBloc, CartState>(
            builder: (context, cart) {
              final narrowBar = MediaQuery.sizeOf(context).width < 420;
              final dockedCart = WindowLayout.of(context).dockPosCart;
              final appendFullscreenMode = dockedCart &&
                  context.watch<PosHallOrdersCubit>().state.openBillAppendDraft !=
                      null;
              final rootContext = context;

              return Scaffold(
                  key: _posScaffoldKey,
                  drawer: narrowBar
                      ? _PosMobileDrawer(
                          menu: menu,
                          user: user,
                          l10n: l10n,
                          canUseCustomerDisplay: _canUseCustomerDisplay,
                          onRefreshMenu: () {
                            if (!menu.loading) {
                              rootContext.read<MenuBloc>().add(
                                    MenuLoadRequested(
                                      lang: menuApiLanguageCode(
                                        rootContext.appUiLocale.languageCode,
                                      ),
                                    ),
                                  );
                            }
                          },
                          onOpenOrders: _showOrdersDialog,
                          onOpenOnlineOrders: _showOnlineOrdersDialog,
                          onOpenPaymentsToday: _showTodayPaymentsHistoryDialog,
                          onOpenCustomerDisplay: _openCustomerDisplayByClick,
                          onRefreshCustomerDisplay:
                              _refreshCustomerDisplayConfigByClick,
                          onOpenTableBills: () =>
                              showOpenTableBillsDialog(rootContext),
                          onOpenSoldOutToday: () =>
                              showPosSoldOutTodayDialog(rootContext),
                          onOpenSettings: _showSettingsDialog,
                          onOpenCash: () =>
                              showPosCashManagementDialog(rootContext),
                          onLogout: () => _logout(rootContext),
                        )
                      : null,
                  appBar: (dockedCart && !narrowBar)
                      ? null
                      : AppBar(
                    automaticallyImplyLeading: false,
                    toolbarHeight: 84,
                    titleSpacing: 16,
                    bottom: PosAppBarCheckTabs(
                      openCartSheetWhenCheckSelected:
                          narrowBar && !dockedCart,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (narrowBar)
                          Text(
                            'Doner Kebab',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text(
                                  'Doner Kebab',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (user != null) ...[
                                  const SizedBox(width: 8),
                                  Chip(
                                    avatar: const Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                    ),
                                    label: Text(user.roleLabel(l10n)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                _TopInfoBadge(
                                  icon: Icons.receipt_long_rounded,
                                  label: '${cart.itemCount} поз.',
                                  iconOnly: true,
                                ),
                                const SizedBox(width: 8),
                                const _TopInfoBadge(
                                  icon: Icons.wifi_rounded,
                                  label: 'Online',
                                  iconOnly: true,
                                ),
                                if (user?.role == 'cashier' ||
                                    user?.role == 'admin') ...[
                                  const SizedBox(width: 4),
                                  const PosOnlineOrderingBadge(),
                                ],
                                if (user?.role == 'cashier' ||
                                    user?.role == 'admin') ...[
                                  const SizedBox(width: 8),
                                  const _PrinterStatusBadge(iconOnly: true),
                                ],
                              ],
                            ),
                          ),
                        if (!narrowBar) const SizedBox(height: 2),
                        if (!narrowBar && appendFullscreenMode) ...[
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.settings_rounded),
                                  tooltip: 'Настройки',
                                  onPressed: _showSettingsDialog,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded),
                                  tooltip: l10n.actionRefreshMenu,
                                  onPressed: menu.loading
                                      ? null
                                      : () => context.read<MenuBloc>().add(
                                            MenuLoadRequested(
                                              lang: menuApiLanguageCode(
                                                context.appUiLocale.languageCode,
                                              ),
                                            ),
                                          ),
                                ),
                                if (user?.role == 'cashier' ||
                                    user?.role == 'admin')
                                  _customerDisplayToolbarActions(),
                                if (user?.role == 'cashier' || user?.role == 'admin')
                                  IconButton(
                                    icon: const Icon(Icons.payments_rounded),
                                    tooltip: 'Оплаты за сегодня',
                                    onPressed: _showTodayPaymentsHistoryDialog,
                                  ),
                                if (user?.role == 'cashier' || user?.role == 'admin')
                                  IconButton(
                                    icon: const Icon(Icons.block_rounded),
                                    tooltip: 'Закончилось сегодня',
                                    onPressed: () =>
                                        showPosSoldOutTodayDialog(context),
                                  ),
                                if (user?.role == 'cashier' || user?.role == 'admin')
                                  IconButton(
                                    icon: const Icon(Icons.account_balance_wallet_outlined),
                                    tooltip: 'Касса: смена, инкассация',
                                    onPressed: () => showPosCashManagementDialog(context),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _logout(context),
                                  icon: const Icon(Icons.logout_rounded),
                                  label: Text(l10n.actionExit),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    actions: narrowBar
                        ? [
                            if (!dockedCart)
                              IconButton(
                                tooltip: l10n.cartOrder,
                                onPressed: cart.isEmpty
                                    ? null
                                    : () => showPosCartSheet(context),
                                icon: Badge(
                                  isLabelVisible: !cart.isEmpty,
                                  label: Text('${cart.itemCount}'),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                  ),
                                ),
                              ),
                            IconButton(
                              tooltip: l10n.tooltipAppMenu,
                              onPressed: () =>
                                  _posScaffoldKey.currentState?.openDrawer(),
                              icon: const Icon(Icons.menu_rounded),
                            ),
                            if (user?.role == 'cashier' || user?.role == 'admin') ...[
                              IconButton(
                                icon: const Icon(Icons.block_rounded),
                                tooltip: 'Закончилось сегодня',
                                onPressed: () =>
                                    showPosSoldOutTodayDialog(context),
                              ),
                              IconButton(
                                icon: const Icon(Icons.account_balance_wallet_outlined),
                                tooltip: 'Касса: смена, инкассация',
                                onPressed: () => showPosCashManagementDialog(context),
                              ),
                              IconButton(
                                tooltip: l10n.actionExit,
                                onPressed: () => _logout(context),
                                icon: const Icon(Icons.logout_rounded),
                              ),
                            ],
                          ]
                        : [
                            if (!appendFullscreenMode) ...[
                              IconButton(
                                icon: const Icon(Icons.settings_rounded),
                                tooltip: 'Настройки',
                                onPressed: _showSettingsDialog,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                tooltip: l10n.actionRefreshMenu,
                                onPressed: menu.loading
                                    ? null
                                    : () => context.read<MenuBloc>().add(
                                          MenuLoadRequested(
                                            lang: menuApiLanguageCode(
                                              context.appUiLocale.languageCode,
                                            ),
                                          ),
                                        ),
                              ),
                              if (user?.role == 'cashier' ||
                                  user?.role == 'admin')
                                _customerDisplayToolbarActions(),
                              if (user?.role == 'cashier' || user?.role == 'admin')
                                IconButton(
                                  icon: const Icon(Icons.payments_rounded),
                                  tooltip: 'Оплаты за сегодня',
                                  onPressed: _showTodayPaymentsHistoryDialog,
                                ),
                              if (user?.role == 'cashier' || user?.role == 'admin')
                                IconButton(
                                  icon: const Icon(Icons.block_rounded),
                                  tooltip: 'Закончилось сегодня',
                                  onPressed: () =>
                                      showPosSoldOutTodayDialog(context),
                                ),
                              if (user?.role == 'cashier' || user?.role == 'admin')
                                IconButton(
                                  icon: const Icon(Icons.account_balance_wallet_outlined),
                                  tooltip: 'Касса: смена, инкассация',
                                  onPressed: () => showPosCashManagementDialog(context),
                                ),
                              TextButton.icon(
                                onPressed: () => _logout(context),
                                icon: const Icon(Icons.logout_rounded),
                                label: Text(l10n.actionExit),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                  ),
                  floatingActionButton:
                      WindowLayout.of(context).dockPosCart || cart.isEmpty
                      ? null
                      : FloatingActionButton.extended(
                          onPressed: () => showPosCartSheet(context),
                          icon: Badge(
                            label: Text('${cart.itemCount}'),
                            child: const Icon(
                              Icons.shopping_cart_checkout_rounded,
                            ),
                          ),
                          label: Text(formatSomoni(cart.total)),
                        ),
                  body: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: posWorkspaceBodyGradient(theme),
                      ),
                    ),
                    child: menu.loading
                        ? const Center(child: CircularProgressIndicator())
                        : menu.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    menu.error!,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () =>
                                        context.read<MenuBloc>().add(
                                          MenuLoadRequested(
                                            lang: menuApiLanguageCode(
                                              context.appUiLocale.languageCode,
                                            ),
                                          ),
                                        ),
                                    child: Text(l10n.actionRetry),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : menu.categoryRoots.isEmpty
                        ? Center(child: Text(l10n.menuEmpty))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return BlocBuilder<PosHallOrdersCubit,
                                  PosHallOrdersState>(
                                builder: (context, hall) {
                                  final appendMode =
                                      hall.openBillAppendDraft != null;
                                  final cartPanelWidth = dockedCart
                                      ? (appendMode
                                          ? (constraints.maxWidth * 0.40).clamp(
                                              320.0,
                                              480.0,
                                            )
                                          : WindowLayout.posCartPanelWidth)
                                      : 0.0;
                                  final catalogPaneWidth = dockedCart
                                      ? WindowLayout(
                                          width: constraints.maxWidth,
                                        ).posCatalogPaneWidthBesideCart(
                                          constraints.maxWidth,
                                          cartPanelWidth,
                                        )
                                      : WindowLayout(
                                          width: constraints.maxWidth,
                                        ).posCatalogPaneWidth;
                                  final catalog = PosCatalogBody(
                                    menu: menu,
                                    catalogPaneWidth: catalogPaneWidth,
                                    orderAppendMode: appendMode,
                                    onAddItem: _handleCatalogItemAdd,
                                  );
                                  final openBillsCount = hall.openBills.length;
                                  final incomingWebsiteCount =
                                      _incomingWebsiteOrders.length;
                                  final ordersToHandOutCount =
                                      user?.role == 'cashier'
                                          ? _expeditorBundlingCount +
                                              _expeditorPickupCount
                                          : 0;
                                  final metrics = narrowBar
                                      ? const SizedBox.shrink()
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: _WorkspaceMetricCard(
                                                icon: Icons
                                                    .local_fire_department_rounded,
                                                label: 'Хиты меню',
                                                value:
                                                    '${menu.currentItems.length}',
                                                tone: const Color(0xFFE4002B),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _WorkspaceActionCard(
                                                icon: Icons.receipt_long_rounded,
                                                label: 'Заказы',
                                                value: _ordersWorkspaceValue(l10n),
                                                tone: const Color(0xFF24B47E),
                                                badgeCount: ordersToHandOutCount,
                                                onTap: _showOrdersDialog,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (_canManageOnlineOrders(user?.role))
                                              Expanded(
                                                child: _WorkspaceActionCard(
                                                  icon:
                                                      Icons.phone_in_talk_rounded,
                                                  label: 'Онлайн заказы',
                                                  value: incomingWebsiteCount > 0
                                                      ? '$incomingWebsiteCount новых'
                                                      : 'нет новых',
                                                  tone: incomingWebsiteCount > 0
                                                      ? const Color(0xFFE4002B)
                                                      : (theme.brightness ==
                                                              Brightness.dark
                                                          ? scheme.secondary
                                                          : const Color(
                                                              0xFFB26A00,
                                                            )),
                                                  badgeCount: incomingWebsiteCount,
                                                  onTap: _showOnlineOrdersDialog,
                                                ),
                                              ),
                                            if (_canManageOnlineOrders(user?.role))
                                              const SizedBox(width: 10),
                                            Expanded(
                                              child: _WorkspaceActionCard(
                                                icon: Icons
                                                    .table_restaurant_rounded,
                                                label: 'Счета на оплату',
                                                value: openBillsCount > 0
                                                    ? '$openBillsCount не оплачено'
                                                    : 'все оплачены',
                                                tone: const Color(0xFF5B8DEF),
                                                badgeCount: openBillsCount,
                                                onTap: () =>
                                                    showOpenTableBillsDialog(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                  final showWorkspaceCards =
                                      !narrowBar && !appendMode;
                                  final cartPane = SizedBox(
                                    width: cartPanelWidth,
                                    child: ColoredBox(
                                      color: scheme.surfaceContainerLow,
                                      child: const PosCartPanel(),
                                    ),
                                  );
                                  final catalogPane = Expanded(
                                    child: Column(
                                      children: [
                                        if (dockedCart && !narrowBar)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              10,
                                              16,
                                              6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.surface,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: scheme.outlineVariant,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        'Doner Kebab',
                                                        style: theme
                                                            .textTheme
                                                            .titleLarge
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight.w800,
                                                            ),
                                                      ),
                                                      if (user != null) ...[
                                                        const SizedBox(width: 8),
                                                        Chip(
                                                          avatar: const Icon(
                                                            Icons.badge_outlined,
                                                            size: 18,
                                                          ),
                                                          label: Text(
                                                            user.roleLabel(l10n),
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                      ],
                                                      const SizedBox(width: 8),
                                                      _TopInfoBadge(
                                                        icon: Icons
                                                            .receipt_long_rounded,
                                                        label:
                                                            '${cart.itemCount} поз.',
                                                        iconOnly: true,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const _TopInfoBadge(
                                                        icon: Icons.wifi_rounded,
                                                        label: 'Online',
                                                        iconOnly: true,
                                                      ),
                                                      if (user?.role ==
                                                              'cashier' ||
                                                          user?.role ==
                                                              'admin') ...[
                                                        const SizedBox(width: 8),
                                                        const _PrinterStatusBadge(
                                                          iconOnly: true,
                                                        ),
                                                      ],
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.settings_rounded,
                                                        ),
                                                        tooltip: 'Настройки',
                                                        onPressed:
                                                            _showSettingsDialog,
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.refresh_rounded,
                                                        ),
                                                        tooltip:
                                                            l10n.actionRefreshMenu,
                                                        onPressed: menu.loading
                                                            ? null
                                                            : () => context
                                                                    .read<MenuBloc>()
                                                                    .add(
                                                                      MenuLoadRequested(
                                                                        lang:
                                                                            menuApiLanguageCode(
                                                                          context
                                                                              .appUiLocale
                                                                              .languageCode,
                                                                        ),
                                                                      ),
                                                                    ),
                                                      ),
                                                      if (user?.role ==
                                                              'cashier' ||
                                                          user?.role == 'admin')
                                                        _customerDisplayToolbarActions(),
                                                      if (user?.role ==
                                                              'cashier' ||
                                                          user?.role == 'admin')
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .payments_rounded,
                                                          ),
                                                          tooltip:
                                                              'Оплаты за сегодня',
                                                          onPressed:
                                                              _showTodayPaymentsHistoryDialog,
                                                        ),
                                                      if (user?.role ==
                                                              'cashier' ||
                                                          user?.role == 'admin')
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.block_rounded,
                                                          ),
                                                          tooltip:
                                                              'Закончилось сегодня',
                                                          onPressed: () =>
                                                              showPosSoldOutTodayDialog(
                                                            context,
                                                          ),
                                                        ),
                                                      if (user?.role ==
                                                              'cashier' ||
                                                          user?.role == 'admin')
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .account_balance_wallet_outlined,
                                                          ),
                                                          tooltip:
                                                              'Касса: смена, инкассация',
                                                          onPressed: () =>
                                                              showPosCashManagementDialog(
                                                                context,
                                                              ),
                                                        ),
                                                      IconButton(
                                                        tooltip: l10n.actionExit,
                                                        onPressed: () =>
                                                            _logout(context),
                                                        icon: const Icon(
                                                          Icons.logout_rounded,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                const PosAppBarCheckTabs(
                                                  openCartSheetWhenCheckSelected:
                                                      false,
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (showWorkspaceCards)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              12,
                                              16,
                                              8,
                                            ),
                                            child: metrics,
                                          ),
                                        Expanded(
                                          child: catalog,
                                        ),
                                      ],
                                    ),
                                  );

                                  final immersiveDockedMode = dockedCart;

                                  return Padding(
                                    padding: immersiveDockedMode
                                        ? EdgeInsets.zero
                                        : const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            14,
                                            14,
                                          ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: scheme.surface.withValues(
                                          alpha: 0.94,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          immersiveDockedMode ? 0 : 28,
                                        ),
                                        border: immersiveDockedMode
                                            ? null
                                            : Border.all(
                                                color: scheme.outlineVariant,
                                              ),
                                        boxShadow: immersiveDockedMode
                                            ? null
                                            : const [
                                                BoxShadow(
                                                  color: Color(0x66000000),
                                                  blurRadius: 28,
                                                  offset: Offset(0, 12),
                                                ),
                                              ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          immersiveDockedMode ? 0 : 28,
                                        ),
                                        child: dockedCart
                                            ? Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  catalogPane,
                                                  VerticalDivider(
                                                    width: 2,
                                                    thickness: 2,
                                                    color: scheme.outline.withValues(
                                                      alpha: 0.45,
                                                    ),
                                                  ),
                                                  cartPane,
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  if (showWorkspaceCards)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets
                                                              .fromLTRB(
                                                        16,
                                                        12,
                                                        16,
                                                        8,
                                                      ),
                                                      child: metrics,
                                                    ),
                                                  Expanded(child: catalog),
                                                ],
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<double?> _showCustomPriceDialog(BuildContext context, PosMenuItem item) {
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final menuPrice = item.price.round().clamp(0, 999999999).toInt();
      final input = PosIntegerInputController(initial: menuPrice);
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final intPrice = input.value;
          final canSubmit = intPrice > 0;

          return AlertDialog(
            title: Text('Цена для "${item.name}"'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
              ),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Цена',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        input.display,
                        textAlign: TextAlign.right,
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PosNumericKeypad(
                      showDot: false,
                      onDigit: (d) => setModal(() => input.appendDigit(d)),
                      onBackspace: () => setModal(() => input.backspace()),
                      onClear: () => setModal(() => input.clear()),
                      onPreset: menuPrice > 0
                          ? () => setModal(() => input.setValue(menuPrice))
                          : null,
                      presetLabel: 'Из меню',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.of(ctx).pop(intPrice.toDouble())
                    : null,
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Узкий экран: пункты меню в [Drawer] — на Android надёжнее, чем [PopupMenuButton] в AppBar.
class _PosMobileDrawer extends StatelessWidget {
  const _PosMobileDrawer({
    required this.menu,
    required this.user,
    required this.l10n,
    required this.canUseCustomerDisplay,
    required this.onRefreshMenu,
    required this.onOpenOrders,
    required this.onOpenOnlineOrders,
    required this.onOpenPaymentsToday,
    required this.onOpenCustomerDisplay,
    required this.onRefreshCustomerDisplay,
    required this.onOpenTableBills,
    required this.onOpenSoldOutToday,
    required this.onOpenSettings,
    required this.onOpenCash,
    required this.onLogout,
  });

  final MenuState menu;
  final UserModel? user;
  final AppLocalizations l10n;
  final bool canUseCustomerDisplay;
  final VoidCallback onRefreshMenu;
  final Future<void> Function() onOpenOrders;
  final Future<void> Function() onOpenOnlineOrders;
  final Future<void> Function() onOpenPaymentsToday;
  final Future<void> Function() onOpenCustomerDisplay;
  final Future<void> Function() onRefreshCustomerDisplay;
  final VoidCallback onOpenTableBills;
  final VoidCallback onOpenSoldOutToday;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenCash;
  final VoidCallback onLogout;

  Future<void> _closeThen(
    BuildContext drawerContext,
    Future<void> Function() action,
  ) async {
    Navigator.of(drawerContext).pop();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCashierOrAdmin =
        user?.role == 'cashier' || user?.role == 'admin';

    return Drawer(
      backgroundColor: scheme.surfaceContainerLow,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doner Kebab POS',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user?.username ?? ''} • ${user?.roleLabelRu ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.actionRefreshMenu),
              enabled: !menu.loading,
              onTap: () {
                Navigator.pop(context);
                onRefreshMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Заказы'),
              onTap: () => _closeThen(context, onOpenOrders),
            ),
            ListTile(
              leading: const Icon(Icons.table_restaurant_rounded),
              title: const Text('Счета на оплату'),
              subtitle: isCashierOrAdmin
                  ? null
                  : const Text('Оплата только на кассе'),
              onTap: () {
                Navigator.pop(context);
                onOpenTableBills();
              },
            ),
            if (isCashierOrAdmin)
              ListTile(
                leading: Icon(Icons.block_rounded, color: scheme.error),
                title: const Text('Закончилось сегодня'),
                subtitle: const Text('Блюда, которых нет в наличии'),
                onTap: () {
                  Navigator.pop(context);
                  onOpenSoldOutToday();
                },
              ),
            if (isCashierOrAdmin)
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Онлайн заказы'),
                onTap: () => _closeThen(context, onOpenOnlineOrders),
              ),
            if (isCashierOrAdmin)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Оплаты сегодня'),
                onTap: () => _closeThen(context, onOpenPaymentsToday),
              ),
            if (isCashierOrAdmin && canUseCustomerDisplay)
              ListTile(
                leading: const Icon(Icons.tv_rounded),
                title: const Text('Экран клиента'),
                onTap: () => _closeThen(context, onOpenCustomerDisplay),
              ),
            if (isCashierOrAdmin && canUseCustomerDisplay)
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Обновить экран клиента'),
                onTap: () => _closeThen(context, onRefreshCustomerDisplay),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Настройки'),
              onTap: () {
                Navigator.pop(context);
                onOpenSettings();
              },
            ),
            if (isCashierOrAdmin)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Касса (смена)'),
                subtitle: const Text('Открыть / закрыть смену'),
                onTap: () {
                  Navigator.pop(context);
                  onOpenCash();
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text(
                l10n.actionExit,
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrinterStatusBadge extends StatefulWidget {
  const _PrinterStatusBadge({this.iconOnly = false});

  final bool iconOnly;

  @override
  State<_PrinterStatusBadge> createState() => _PrinterStatusBadgeState();
}

class _PrinterStatusBadgeState extends State<_PrinterStatusBadge> {
  HardwareStatusSnapshot? _snap;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final s =
          await context.read<LocalHardwareRepository>().fetchHardwareStatus();
      if (!mounted) return;
      setState(() => _snap = s);
    } catch (_) {
      if (!mounted) return;
      setState(() => _snap = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snap = _snap;
    final code = snap?.receiptPrinterStatusCode ?? '';
    final ok = snap?.receiptPrinterReachable == true &&
        (code == 'online' || code == 'mock');
    final warnConfigured =
        snap != null && snap.receiptPrinterConfigured && !ok && code != 'mock';
    final icon = ok ? Icons.print_rounded : Icons.print_disabled_outlined;
    final fg = ok
        ? scheme.primary
        : (warnConfigured ? scheme.error : scheme.onSurfaceVariant);
    final bg = ok
        ? scheme.primary.withValues(alpha: 0.08)
        : (warnConfigured
            ? scheme.error.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.9));

    return Tooltip(
      message: snap == null
          ? 'Статус принтера недоступен (нет связи с сервером)'
          : _posHardwarePrinterTooltip(snap),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _refresh,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              if (!widget.iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  _posHardwarePrinterShortLabel(snap),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopInfoBadge extends StatelessWidget {
  const _TopInfoBadge({
    required this.icon,
    required this.label,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Tooltip(
      message: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: iconOnly ? 9 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            if (!iconOnly) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMetricCard extends StatelessWidget {
  const _WorkspaceMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: emphasized ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone.withValues(alpha: emphasized ? 0.55 : 0.20),
          width: emphasized ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tone.withValues(alpha: 0.90),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tone,
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

class _WorkspaceActionCard extends StatelessWidget {
  const _WorkspaceActionCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final VoidCallback onTap;
  /// Сколько заказов/счетов требует внимания (показываем число вместо «!»).
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _WorkspaceMetricCard(
            icon: icon,
            label: label,
            value: value,
            tone: tone,
            emphasized: showBadge,
          ),
          if (showBadge)
            Positioned(
              right: -4,
              top: -6,
              child: _UrgentCountBadge(count: badgeCount),
            ),
        ],
      ),
    );
  }
}

class _SettingsChoiceChip extends StatelessWidget {
  const _SettingsChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentCountBadge extends StatefulWidget {
  const _UrgentCountBadge({required this.count});

  final int count;

  @override
  State<_UrgentCountBadge> createState() => _UrgentCountBadgeState();
}

class _UrgentCountBadgeState extends State<_UrgentCountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.12,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.count > 99 ? '99+' : '${widget.count}';
    final wide = label.length > 1;

    return ScaleTransition(
      scale: _scale,
      child: Container(
        constraints: BoxConstraints(
          minWidth: wide ? 32 : 28,
          minHeight: 28,
        ),
        padding: EdgeInsets.symmetric(horizontal: wide ? 6 : 0),
        decoration: BoxDecoration(
          color: const Color(0xFFE4002B),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66E4002B),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: (wide
                  ? theme.textTheme.labelLarge
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PosOrdersDialog extends StatelessWidget {
  const _PosOrdersDialog({
    required this.orders,
    required this.showHandoffTab,
    required this.canManageOnlineOrders,
    required this.canHandoffOrders,
    required this.onCashierAck,
    required this.onCloseOrder,
    required this.onCancelOrder,
    required this.onCallCustomer,
    required this.onChangeTable,
    required this.onChangeOrderType,
    required this.onFreeTable,
  });

  final List<LocalCashierBoardOrder> orders;
  final bool showHandoffTab;
  final bool canManageOnlineOrders;
  final bool canHandoffOrders;
  final Future<void> Function(LocalCashierBoardOrder) onCashierAck;
  final Future<void> Function(LocalCashierBoardOrder) onCloseOrder;
  final Future<void> Function(LocalCashierBoardOrder) onCancelOrder;
  final void Function(LocalCashierBoardOrder) onCallCustomer;
  final Future<void> Function(LocalCashierBoardOrder) onChangeTable;
  final Future<void> Function(LocalCashierBoardOrder) onChangeOrderType;
  final Future<void> Function(LocalCashierBoardOrder) onFreeTable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );

    if (!showHandoffTab) {
      return AlertDialog(
        insetPadding: _dialogInsetPadding(context),
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(l10n.posOrdersDialogTitle, style: titleStyle),
        content: SizedBox(
          width: _dialogWidth(context, 1360),
          height: _dialogHeight(context, 880),
          child: _HallOrdersList(
            orders: orders,
            canManageOnlineOrders: canManageOnlineOrders,
            canHandoffOrders: canHandoffOrders,
            onCashierAck: onCashierAck,
            onCloseOrder: onCloseOrder,
            onCancelOrder: onCancelOrder,
            onCallCustomer: onCallCustomer,
            onChangeTable: onChangeTable,
            onChangeOrderType: onChangeOrderType,
            onFreeTable: onFreeTable,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }

    return Dialog(
      insetPadding: _dialogInsetPadding(context),
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          width: _dialogWidth(context, 1400),
          height: _dialogHeight(context, 880),
          child: Material(
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(l10n.posOrdersDialogTitle, style: titleStyle),
                ),
                TabBar(
                  tabs: [
                    Tab(text: l10n.posOrdersTabActive),
                    Tab(text: l10n.posOpenExpeditor),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _HallOrdersList(
                        orders: orders,
                        canManageOnlineOrders: canManageOnlineOrders,
                        canHandoffOrders: canHandoffOrders,
                        onCashierAck: onCashierAck,
                        onCloseOrder: onCloseOrder,
                        onCancelOrder: onCancelOrder,
                        onCallCustomer: onCallCustomer,
                        onChangeTable: onChangeTable,
                        onChangeOrderType: onChangeOrderType,
                        onFreeTable: onFreeTable,
                      ),
                      const ExpeditorQueuePanel(embedded: true),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OrdersZoneFilter { all, hall, veranda, none }

enum _OrdersStatusFilter {
  all,
  newOrder,
  cooking,
  ready,
  awaitingExpeditor,
  done,
  cancelled,
}

enum _OrdersPaymentFilter { all, needPayment, noPaymentNeeded }

class _HallOrdersList extends StatefulWidget {
  const _HallOrdersList({
    required this.orders,
    required this.canManageOnlineOrders,
    required this.canHandoffOrders,
    required this.onCashierAck,
    required this.onCloseOrder,
    required this.onCancelOrder,
    required this.onCallCustomer,
    required this.onChangeTable,
    required this.onChangeOrderType,
    required this.onFreeTable,
  });

  final List<LocalCashierBoardOrder> orders;
  final bool canManageOnlineOrders;
  final bool canHandoffOrders;
  final Future<void> Function(LocalCashierBoardOrder) onCashierAck;
  final Future<void> Function(LocalCashierBoardOrder) onCloseOrder;
  final Future<void> Function(LocalCashierBoardOrder) onCancelOrder;
  final void Function(LocalCashierBoardOrder) onCallCustomer;
  final Future<void> Function(LocalCashierBoardOrder) onChangeTable;
  final Future<void> Function(LocalCashierBoardOrder) onChangeOrderType;
  final Future<void> Function(LocalCashierBoardOrder) onFreeTable;

  @override
  State<_HallOrdersList> createState() => _HallOrdersListState();
}

class _HallOrdersListState extends State<_HallOrdersList> {
  _OrdersZoneFilter _zoneFilter = _OrdersZoneFilter.all;
  _OrdersStatusFilter _statusFilter = _OrdersStatusFilter.all;
  _OrdersPaymentFilter _paymentFilter = _OrdersPaymentFilter.all;

  bool _matchesZone(LocalCashierBoardOrder order) {
    if (_zoneFilter == _OrdersZoneFilter.all) return true;
    final table = (order.tableLabel ?? '').toLowerCase();
    final hasTable = table.trim().isNotEmpty;
    switch (_zoneFilter) {
      case _OrdersZoneFilter.hall:
        return table.contains('зал');
      case _OrdersZoneFilter.veranda:
        return table.contains('веранд');
      case _OrdersZoneFilter.none:
        return !hasTable;
      case _OrdersZoneFilter.all:
        return true;
    }
  }

  bool _matchesStatus(LocalCashierBoardOrder order) {
    if (_statusFilter == _OrdersStatusFilter.all) return true;
    final status = order.order.status.toLowerCase();
    switch (_statusFilter) {
      case _OrdersStatusFilter.newOrder:
        return status == 'new';
      case _OrdersStatusFilter.cooking:
        return status == 'cooking';
      case _OrdersStatusFilter.ready:
        return status == 'ready';
      case _OrdersStatusFilter.awaitingExpeditor:
        return status == 'awaiting_expeditor';
      case _OrdersStatusFilter.done:
        return status == 'done';
      case _OrdersStatusFilter.cancelled:
        return status == 'cancelled';
      case _OrdersStatusFilter.all:
        return true;
    }
  }

  bool _matchesPayment(LocalCashierBoardOrder order) {
    switch (_paymentFilter) {
      case _OrdersPaymentFilter.all:
        return true;
      case _OrdersPaymentFilter.needPayment:
        return order.requiresPayment;
      case _OrdersPaymentFilter.noPaymentNeeded:
        return !order.requiresPayment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    if (widget.orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.posOrdersActiveEmpty),
      );
    }

    final filtered = widget.orders.where((order) {
      return _matchesZone(order) &&
          _matchesStatus(order) &&
          _matchesPayment(order);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Все зоны'),
              selected: _zoneFilter == _OrdersZoneFilter.all,
              onSelected: (_) => setState(() => _zoneFilter = _OrdersZoneFilter.all),
            ),
            ChoiceChip(
              label: const Text('Зал'),
              selected: _zoneFilter == _OrdersZoneFilter.hall,
              onSelected: (_) => setState(() => _zoneFilter = _OrdersZoneFilter.hall),
            ),
            ChoiceChip(
              label: const Text('Веранда'),
              selected: _zoneFilter == _OrdersZoneFilter.veranda,
              onSelected: (_) =>
                  setState(() => _zoneFilter = _OrdersZoneFilter.veranda),
            ),
            ChoiceChip(
              label: const Text('Без стола'),
              selected: _zoneFilter == _OrdersZoneFilter.none,
              onSelected: (_) => setState(() => _zoneFilter = _OrdersZoneFilter.none),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Все статусы'),
              selected: _statusFilter == _OrdersStatusFilter.all,
              onSelected: (_) =>
                  setState(() => _statusFilter = _OrdersStatusFilter.all),
            ),
            ChoiceChip(
              label: const Text('Новый'),
              selected: _statusFilter == _OrdersStatusFilter.newOrder,
              onSelected: (_) =>
                  setState(() => _statusFilter = _OrdersStatusFilter.newOrder),
            ),
            ChoiceChip(
              label: const Text('Готовится'),
              selected: _statusFilter == _OrdersStatusFilter.cooking,
              onSelected: (_) =>
                  setState(() => _statusFilter = _OrdersStatusFilter.cooking),
            ),
            ChoiceChip(
              label: const Text('Готов'),
              selected: _statusFilter == _OrdersStatusFilter.ready,
              onSelected: (_) =>
                  setState(() => _statusFilter = _OrdersStatusFilter.ready),
            ),
            ChoiceChip(
              label: const Text('Сборка'),
              selected: _statusFilter == _OrdersStatusFilter.awaitingExpeditor,
              onSelected: (_) => setState(
                () => _statusFilter = _OrdersStatusFilter.awaitingExpeditor,
              ),
            ),
            ChoiceChip(
              label: const Text('Выдан'),
              selected: _statusFilter == _OrdersStatusFilter.done,
              onSelected: (_) => setState(() => _statusFilter = _OrdersStatusFilter.done),
            ),
            ChoiceChip(
              label: const Text('Отменен'),
              selected: _statusFilter == _OrdersStatusFilter.cancelled,
              onSelected: (_) =>
                  setState(() => _statusFilter = _OrdersStatusFilter.cancelled),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Все оплаты'),
              selected: _paymentFilter == _OrdersPaymentFilter.all,
              onSelected: (_) =>
                  setState(() => _paymentFilter = _OrdersPaymentFilter.all),
            ),
            ChoiceChip(
              label: const Text('Нужна оплата'),
              selected: _paymentFilter == _OrdersPaymentFilter.needPayment,
              onSelected: (_) => setState(
                () => _paymentFilter = _OrdersPaymentFilter.needPayment,
              ),
            ),
            ChoiceChip(
              label: const Text('Оплата не нужна'),
              selected: _paymentFilter == _OrdersPaymentFilter.noPaymentNeeded,
              onSelected: (_) => setState(
                () => _paymentFilter = _OrdersPaymentFilter.noPaymentNeeded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('По выбранным фильтрам заказов нет'),
          )
        else
          BlocBuilder<PosBoardLayoutCubit, PosBoardLayoutState>(
            buildWhen: (p, c) => p.ordersLayout != c.ordersLayout,
            builder: (context, layoutState) {
              final layout = layoutState.ordersLayout;
              if (layout == PosBoardLayout.cards) {
                return BlocBuilder<PosCashierBoardCubit, PosCashierBoardSettings>(
                  builder: (context, cardUi) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        Widget orderColumn() => Column(
                              children: [
                                for (var i = 0; i < filtered.length; i++) ...[
                                  _OrderBoardCard(
                                    order: filtered[i],
                                    canManageOnlineOrders:
                                        widget.canManageOnlineOrders,
                                    canHandoffOrders: widget.canHandoffOrders,
                                    onCashierAck: () =>
                                        widget.onCashierAck(filtered[i]),
                                    onCloseOrder: () =>
                                        widget.onCloseOrder(filtered[i]),
                                    onCancelOrder: () =>
                                        widget.onCancelOrder(filtered[i]),
                                    onCallCustomer: () =>
                                        widget.onCallCustomer(filtered[i]),
                                    onChangeTable: () =>
                                        widget.onChangeTable(filtered[i]),
                                    onChangeOrderType: () =>
                                        widget.onChangeOrderType(filtered[i]),
                                    onFreeTable: () =>
                                        widget.onFreeTable(filtered[i]),
                                  ),
                                  if (i != filtered.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            );

                        final maxW = constraints.maxWidth;
                        if (!maxW.isFinite || maxW < 80) return orderColumn();

                        final cols = WindowLayout(width: maxW)
                            .cardGridColumns(minCellWidth: 320);
                        if (cols <= 1) return orderColumn();

                        const spacing = 12.0;
                        final aspect =
                            cardUi.gridAspectRatio(columns: cols);
                        final cellW =
                            (maxW - spacing * (cols - 1)) / cols;
                        final cellH = cellW / aspect;
                        if (!cellW.isFinite ||
                            !cellH.isFinite ||
                            cellH < 140) {
                          return orderColumn();
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: aspect,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final o = filtered[i];
                            return _OrderBoardCard(
                              order: o,
                              compact: true,
                              canManageOnlineOrders:
                                  widget.canManageOnlineOrders,
                              canHandoffOrders: widget.canHandoffOrders,
                              onCashierAck: () => widget.onCashierAck(o),
                              onCloseOrder: () => widget.onCloseOrder(o),
                              onCancelOrder: () => widget.onCancelOrder(o),
                              onCallCustomer: () => widget.onCallCustomer(o),
                              onChangeTable: () => widget.onChangeTable(o),
                              onChangeOrderType: () =>
                                  widget.onChangeOrderType(o),
                              onFreeTable: () => widget.onFreeTable(o),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    _OrderListTile(
                      order: filtered[i],
                      canManageOnlineOrders: widget.canManageOnlineOrders,
                      canHandoffOrders: widget.canHandoffOrders,
                      onCashierAck: () => widget.onCashierAck(filtered[i]),
                      onCloseOrder: () => widget.onCloseOrder(filtered[i]),
                      onCancelOrder: () => widget.onCancelOrder(filtered[i]),
                      onCallCustomer: () => widget.onCallCustomer(filtered[i]),
                      onChangeTable: () => widget.onChangeTable(filtered[i]),
                      onChangeOrderType: () =>
                          widget.onChangeOrderType(filtered[i]),
                      onFreeTable: () => widget.onFreeTable(filtered[i]),
                    ),
                    if (i != filtered.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _OnlineOrdersDialog extends StatelessWidget {
  const _OnlineOrdersDialog({
    required this.orders,
    required this.onCashierAck,
    required this.onCloseOrder,
    required this.onCancelOrder,
    required this.onEditOrder,
    required this.onCallCustomer,
  });

  final List<LocalCashierBoardOrder> orders;
  final Future<void> Function(LocalCashierBoardOrder) onCashierAck;
  final Future<void> Function(LocalCashierBoardOrder) onCloseOrder;
  final Future<void> Function(LocalCashierBoardOrder) onCancelOrder;
  final Future<void> Function(LocalCashierBoardOrder) onEditOrder;
  final void Function(LocalCashierBoardOrder) onCallCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      insetPadding: _dialogInsetPadding(context),
      backgroundColor: scheme.surfaceContainerLow,
      title: Text(
        'Онлайн заказы',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: _dialogWidth(context, 1360),
        height: _dialogHeight(context, 880),
        child: orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Онлайн-заказов нет'),
              )
            : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = orders[i];
                  return _OrderListTile(
                    order: o,
                    canManageOnlineOrders: true,
                    canHandoffOrders: true,
                    onCashierAck: () => onCashierAck(o),
                    onCloseOrder: () => onCloseOrder(o),
                    onCancelOrder: () => onCancelOrder(o),
                    onCallCustomer: () => onCallCustomer(o),
                    onEditOrder: () => onEditOrder(o),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _TodayPaymentsDialogLoader extends StatefulWidget {
  const _TodayPaymentsDialogLoader({
    required this.branchId,
    required this.lang,
    required this.showTotals,
  });

  final String branchId;
  final String lang;
  final bool showTotals;

  @override
  State<_TodayPaymentsDialogLoader> createState() =>
      _TodayPaymentsDialogLoaderState();
}

class _TodayPaymentsDialogLoaderState extends State<_TodayPaymentsDialogLoader> {
  static const int _pageSize = 40;

  String get _terminalId =>
      context.read<LocalPaymentsRepository>().defaultTerminalId;

  String get _dialogTitle => 'Оплаты за сегодня · $_terminalId';

  bool _loading = true;
  bool _loadingMore = false;
  List<LocalPaymentHistoryEntry> _payments = const [];
  List<LocalRefundHistoryEntry> _refunds = const [];
  LocalPaymentsTodaySummary? _summary;
  bool _hasMorePayments = false;
  bool _hasMoreRefunds = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    try {
      final history =
          await context.read<LocalPaymentsRepository>().fetchTodayHistoryBundle(
                branchId: widget.branchId,
                terminalId: _terminalId,
                limit: _pageSize,
                paymentOffset: 0,
                refundOffset: 0,
                lang: widget.lang,
              );
      if (!mounted) return;
      setState(() {
        _payments = history.payments;
        _refunds = history.refunds;
        _summary = history.summary;
        _hasMorePayments = history.hasMorePayments;
        _hasMoreRefunds = history.hasMoreRefunds;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить историю оплат: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || (!_hasMorePayments && !_hasMoreRefunds)) return;
    setState(() => _loadingMore = true);
    try {
      final next =
          await context.read<LocalPaymentsRepository>().fetchTodayHistoryBundle(
                branchId: widget.branchId,
                terminalId: _terminalId,
                limit: _pageSize,
                paymentOffset: _payments.length,
                refundOffset: _refunds.length,
                lang: widget.lang,
              );
      if (!mounted) return;
      setState(() {
        _payments = [..._payments, ...next.payments];
        _refunds = [..._refunds, ...next.refunds];
        _hasMorePayments = next.hasMorePayments;
        _hasMoreRefunds = next.hasMoreRefunds;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось подгрузить записи: $e')),
      );
    }
  }

  Future<void> _reloadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _payments = const [];
      _refunds = const [];
      _summary = null;
      _hasMorePayments = false;
      _hasMoreRefunds = false;
      _error = null;
    });
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        );
    if (_loading) {
      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(_dialogTitle, style: titleStyle),
        content: SizedBox(
          width: math.min(400, MediaQuery.sizeOf(context).width * 0.9),
          height: 120,
          child: const Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }
    if (_error != null) {
      return AlertDialog(
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(_dialogTitle, style: titleStyle),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }
    return _TodayPaymentsDialog(
      title: _dialogTitle,
      terminalId: _terminalId,
      entries: _payments,
      refunds: _refunds,
      summary: _summary,
      hasMorePayments: _hasMorePayments,
      hasMoreRefunds: _hasMoreRefunds,
      loadingMore: _loadingMore,
      showTotals: widget.showTotals,
      onReload: _reloadAll,
      onLoadMore:
          (_hasMorePayments || _hasMoreRefunds) ? _loadMore : null,
    );
  }
}

class _TodayPaymentsDialog extends StatelessWidget {
  const _TodayPaymentsDialog({
    required this.title,
    required this.terminalId,
    required this.entries,
    required this.refunds,
    required this.hasMorePayments,
    required this.hasMoreRefunds,
    required this.loadingMore,
    required this.showTotals,
    required this.onReload,
    this.summary,
    this.onLoadMore,
  });

  final String title;
  final String terminalId;
  final List<LocalPaymentHistoryEntry> entries;
  final List<LocalRefundHistoryEntry> refunds;
  final LocalPaymentsTodaySummary? summary;
  final bool hasMorePayments;
  final bool hasMoreRefunds;
  final bool loadingMore;
  final bool showTotals;
  final Future<void> Function() onReload;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalPayments = showTotals
        ? (summary?.totalPayments ??
            entries.fold<double>(0, (sum, e) => sum + e.amount))
        : 0.0;
    final totalRefunds = showTotals
        ? (summary?.totalRefunds ??
            refunds.fold<double>(0, (sum, e) => sum + e.amount))
        : 0.0;
    final netTotal = showTotals ? (summary?.netTotal ?? (totalPayments - totalRefunds)) : 0.0;
    final todaySummary = summary;
    final methodRows = showTotals
        ? (todaySummary != null
            ? todaySummary.byMethod
                .map(
                  (row) => _PaymentMethodTotalsRow(
                    method: row.method,
                    payments: row.payments,
                    refunds: row.refunds,
                  ),
                )
                .toList(growable: false)
            : _buildMethodTotals(entries, refunds))
        : const <_PaymentMethodTotalsRow>[];
    final dialogWidth =
        math.min(820.0, MediaQuery.sizeOf(context).width * 0.94).toDouble();
    final dialogHeight =
        math.min(560.0, MediaQuery.sizeOf(context).height * 0.72).toDouble();

    Widget topMetric({
      required String title,
      required String value,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    Widget scrollBody() {
      return CustomScrollView(
        slivers: [
          if (showTotals) ...[
            SliverToBoxAdapter(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 240,
                    child: topMetric(
                      title: 'Итого оплат',
                      value: formatSomoni(totalPayments),
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: topMetric(
                      title: 'Итого возвратов',
                      value: '- ${formatSomoni(totalRefunds)}',
                      color: const Color(0xFFD32F2F),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: topMetric(
                      title: 'Чистый итог',
                      value: formatSomoni(netTotal),
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            if (todaySummary != null &&
                (todaySummary.paymentCount > entries.length ||
                    todaySummary.refundCount > refunds.length))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Итоги за сегодня по кассе $terminalId '
                    '(${todaySummary.paymentCount} оплат, ${todaySummary.refundCount} возвратов). '
                    'Другая касса в этот список не попадает.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Text(
                'Итог по способу оплаты',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  ),
                  columns: const [
                    DataColumn(label: Text('Способ')),
                    DataColumn(label: Text('Оплаты'), numeric: true),
                    DataColumn(label: Text('Возвраты'), numeric: true),
                    DataColumn(label: Text('Итого'), numeric: true),
                  ],
                  rows: methodRows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(_paymentMethodRu(row.method))),
                            DataCell(Text(formatSomoni(row.payments))),
                            DataCell(Text('- ${formatSomoni(row.refunds)}')),
                            DataCell(
                              Text(
                                formatSomoni(row.net),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
          SliverToBoxAdapter(
            child: Text(
              'Оплаты',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (entries.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Оплат пока нет'),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < entries.length - 1 ? 10 : 0,
                    ),
                    child: _PaymentHistoryTile(
                      entry: entries[index],
                      onRefund: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => _RefundPaymentDialog(
                            entry: entries[index],
                          ),
                        );
                        if (ok == true) {
                          await onReload();
                        }
                      },
                    ),
                  );
                },
                childCount: entries.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          SliverToBoxAdapter(
            child: Text(
              'Возвраты',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          if (refunds.isEmpty)
            const SliverToBoxAdapter(child: Text('Возвратов пока нет'))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < refunds.length - 1 ? 10 : 0,
                    ),
                    child: _RefundHistoryTile(entry: refunds[index]),
                  );
                },
                childCount: refunds.length,
              ),
            ),
          if (onLoadMore != null && (hasMorePayments || hasMoreRefunds))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Center(
                  child: loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(),
                        )
                      : TextButton.icon(
                          onPressed: () => onLoadMore!(),
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            summary != null
                                ? 'Показать ещё в списке'
                                : 'Показать ещё',
                          ),
                        ),
                ),
              ),
            ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: scheme.surfaceContainerLow,
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: dialogWidth,
        height: (entries.isEmpty && refunds.isEmpty) ? null : dialogHeight,
        child: (entries.isEmpty && refunds.isEmpty)
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('За сегодня оплат и возвратов пока нет'),
              )
            : scrollBody(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _PaymentMethodTotalsRow {
  const _PaymentMethodTotalsRow({
    required this.method,
    required this.payments,
    required this.refunds,
  });

  final String method;
  final double payments;
  final double refunds;

  double get net => payments - refunds;
}

double _dialogWidth(BuildContext context, double preferred) {
  final w = MediaQuery.sizeOf(context).width;
  if (WindowLayout.of(context).isCompact) return w - 8;
  return math.min(preferred, w * 0.98);
}

double _dialogHeight(BuildContext context, double preferred) {
  final h = MediaQuery.sizeOf(context).height;
  if (WindowLayout.of(context).isCompact) return h * 0.94;
  return math.min(preferred, h * 0.94);
}

EdgeInsets _dialogInsetPadding(BuildContext context) {
  if (WindowLayout.of(context).isCompact) {
    return const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  }
  return const EdgeInsets.symmetric(horizontal: 10, vertical: 10);
}

List<_PaymentMethodTotalsRow> _buildMethodTotals(
  List<LocalPaymentHistoryEntry> entries,
  List<LocalRefundHistoryEntry> refunds,
) {
  final byMethod = <String, (double payments, double refunds)>{};
  for (final e in entries) {
    final method = e.method.trim().toLowerCase();
    final current = byMethod[method] ?? (0, 0);
    byMethod[method] = (current.$1 + e.amount, current.$2);
  }
  for (final r in refunds) {
    final method = r.method.trim().toLowerCase();
    final current = byMethod[method] ?? (0, 0);
    byMethod[method] = (current.$1, current.$2 + r.amount);
  }
  final rows = byMethod.entries
      .map(
        (e) => _PaymentMethodTotalsRow(
          method: e.key,
          payments: e.value.$1,
          refunds: e.value.$2,
        ),
      )
      .toList(growable: false);
  rows.sort((a, b) => b.net.compareTo(a.net));
  return rows;
}

class _RefundHistoryTile extends StatelessWidget {
  const _RefundHistoryTile({required this.entry});

  final LocalRefundHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleNoRaw = entry.orderNumber.trim().isNotEmpty
        ? entry.orderNumber.trim()
        : entry.orderId.trim();
    final titleNo = _cashierOrderDisplayNumber(
      number: titleNoRaw,
      orderTypeRaw: entry.orderType,
    );
    final itemPreview = entry.items.isEmpty
        ? 'Состав не найден'
        : entry.items
            .map((i) => i.quantity > 1 ? '${i.quantity} x ${i.name}' : i.name)
            .join(' · ');
    final refundedAt = _formatPaidAt(entry.createdAt);
    final method = _paymentMethodRu(entry.method);
    final reason = (entry.reason ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Возврат · № $titleNo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemPreview,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Причина: $reason',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '$refundedAt · $method',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _posReceiptPrintedShortRu(entry.receiptPrinted),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: entry.receiptPrinted == true
                        ? const Color(0xFF2E7D32)
                        : entry.receiptPrinted == false
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '- ${formatSomoni(entry.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryTile extends StatelessWidget {
  const _PaymentHistoryTile({
    required this.entry,
    this.onRefund,
  });

  final LocalPaymentHistoryEntry entry;
  final Future<void> Function()? onRefund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleNo = entry.orderNumber.trim().isNotEmpty
        ? entry.orderNumber.trim()
        : entry.orderId.trim();
    final itemPreview = entry.items.isEmpty
        ? 'Состав не найден'
        : entry.items
            .map((i) => i.quantity > 1 ? '${i.quantity} x ${i.name}' : i.name)
            .join(' · ');
    final paidAt = _formatPaidAt(entry.createdAt);
    final method = _paymentMethodRu(entry.method);
    final typeLine = _cashierBoardOrderTypeRu(entry.orderType);
    final tableRaw = entry.tableLabel?.trim();
    final tableLabel = tableRaw != null && tableRaw.isNotEmpty
        ? tableRaw
        : _paymentHistoryTableFallback(entry);
    final websiteMeta = parseWebsiteOrderDeliveryMeta(tableLabel);
    final chipBag =
        typeLine == 'Доставка' || websiteMeta.address != null;

    final orderId = entry.orderId.trim();
    final canPrint = orderId.isNotEmpty;
    final canRefund = canPrint && onRefund != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '№ $titleNo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLine,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        chipBag
                            ? Icons.shopping_bag_outlined
                            : Icons.table_restaurant_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        websiteMeta.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (websiteMeta.address != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Адрес: ${websiteMeta.address}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (websiteMeta.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Тел: ${websiteMeta.phone}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (websiteMeta.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Тел: ${websiteMeta.phone}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (websiteMeta.courierHandoff != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    websiteMeta.courierHandoff!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  itemPreview,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$paidAt · $method',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _posReceiptPrintedShortRu(entry.receiptPrinted),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: entry.receiptPrinted == true
                        ? const Color(0xFF2E7D32)
                        : entry.receiptPrinted == false
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatSomoni(entry.amount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              IconButton.filledTonal(
                tooltip: 'Печать чека',
                onPressed: !canPrint
                    ? null
                    : () {
                        unawaited(
                          retryPosReceiptPrint(
                            context,
                            orderId: orderId,
                            total: entry.amount,
                            paymentMethod: entry.method.trim(),
                          ),
                        );
                      },
                icon: const Icon(Icons.print_outlined),
              ),
              if (canRefund) ...[
                const SizedBox(height: 6),
                IconButton.filledTonal(
                  tooltip: 'Возврат',
                  onPressed: () => unawaited(onRefund!()),
                  icon: const Icon(Icons.assignment_return_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RefundPaymentDialog extends StatefulWidget {
  const _RefundPaymentDialog({
    required this.entry,
  });

  final LocalPaymentHistoryEntry entry;

  @override
  State<_RefundPaymentDialog> createState() => _RefundPaymentDialogState();
}

class _RefundPaymentDialogState extends State<_RefundPaymentDialog> {
  LocalRefundablePaymentCheck? _check;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _reasonCtrl = TextEditingController();
  final _qtyByLineKey = <String, int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<LocalPaymentsRepository>();
      final check = await repo.fetchRefundablePaymentCheck(
        paymentUuid: widget.entry.paymentUuid,
      );
      if (!mounted) return;
      setState(() {
        _check = check;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить чек: $e';
        _loading = false;
      });
    }
  }

  int _selectedQty(LocalRefundablePaymentLine line) =>
      _qtyByLineKey[line.lineKey] ?? 0;

  void _setQty(LocalRefundablePaymentLine line, int qty) {
    final safe = qty.clamp(0, line.availableQty);
    setState(() {
      _error = null;
      if (safe <= 0) {
        _qtyByLineKey.remove(line.lineKey);
      } else {
        _qtyByLineKey[line.lineKey] = safe;
      }
    });
  }

  double _refundTotal(LocalRefundablePaymentCheck check) {
    var sum = 0.0;
    for (final line in check.items) {
      final qty = _qtyByLineKey[line.lineKey] ?? 0;
      if (qty > 0) sum += qty * line.unitPrice;
    }
    return sum;
  }

  bool _isFullRefund(LocalRefundablePaymentCheck check) {
    for (final line in check.items) {
      if (line.availableQty <= 0) continue;
      if ((_qtyByLineKey[line.lineKey] ?? 0) != line.availableQty) return false;
    }
    return check.items.any((l) => l.availableQty > 0);
  }

  void _selectAll(LocalRefundablePaymentCheck check) {
    setState(() {
      _error = null;
      _qtyByLineKey.clear();
      for (final line in check.items) {
        if (line.availableQty > 0) _qtyByLineKey[line.lineKey] = line.availableQty;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _error = null;
      _qtyByLineKey.clear();
    });
  }

  Future<void> _submit() async {
    final check = _check;
    if (check == null) return;
    final lines = <Map<String, dynamic>>[];
    for (final line in check.items) {
      final qty = _qtyByLineKey[line.lineKey] ?? 0;
      if (qty > 0) {
        lines.add({'lineKey': line.lineKey, 'quantity': qty});
      }
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Выберите хотя бы одну позицию');
      return;
    }
    final fullRefund = _isFullRefund(check);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalPaymentsRepository>();
      final refund = await repo.refundPaymentLines(
        orderId: check.orderId.isNotEmpty ? check.orderId : widget.entry.orderId,
        paymentUuid: check.paymentUuid,
        refundLines: lines,
        reason: _reasonCtrl.text,
        cancelOrder: fullRefund,
      );
      if (!mounted) return;
      final hint = refund.hardware?.buildHint();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hint == null || hint.isEmpty ? 'Возврат выполнен' : 'Возврат выполнен. $hint',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка возврата: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final check = _check;

    final titleNoRaw = widget.entry.orderNumber.trim().isNotEmpty
        ? widget.entry.orderNumber.trim()
        : widget.entry.orderId.trim();
    final titleNo = _cashierOrderDisplayNumber(
      number: titleNoRaw,
      orderTypeRaw: widget.entry.orderType,
    );

    return AlertDialog(
      title: Text('Возврат · № $titleNo'),
      content: SizedBox(
        width: _dialogWidth(context, 620),
        height: _dialogHeight(context, 560),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null && check == null)
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  )
                : (check == null)
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Выберите позиции для возврата. Чек возврата будет распечатан.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton(
                                onPressed: _busy ? null : () => _selectAll(check),
                                child: const Text('Вернуть всё'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _busy ? null : _clearSelection,
                                child: const Text('Сброс'),
                              ),
                              const Spacer(),
                              Text(
                                'Итого: ${formatSomoni(_refundTotal(check))}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.separated(
                              itemCount: check.items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final line = check.items[i];
                                final avail = line.availableQty;
                                final selected = _selectedQty(line);
                                final disabled = avail <= 0;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        line.name.isNotEmpty ? line.name : 'Позиция',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Доступно: $avail · Цена: ${formatSomoni(line.unitPrice)}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _busy || disabled || selected <= 0
                                                ? null
                                                : () => _setQty(line, selected - 1),
                                            icon: const Icon(Icons.remove_circle_outline),
                                          ),
                                          Text(
                                            '$selected',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _busy || disabled || selected >= avail
                                                ? null
                                                : () => _setQty(line, selected + 1),
                                            icon: const Icon(Icons.add_circle_outline),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonCtrl,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Причина (необязательно)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _busy || check == null ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сделать возврат'),
        ),
      ],
    );
  }
}

String _paymentMethodRu(String value) {
  final v = value.trim().toLowerCase();
  if (v == 'cash') return 'Наличные';
  if (v == 'card') return 'Карта';
  if (v == 'online') return 'Онлайн';
  if (v == 'ds' || v == 'dc') return 'ДС';
  return value.trim().isEmpty ? 'Оплата' : value;
}

String _formatPaidAt(DateTime? dt) {
  if (dt == null) return 'Время не указано';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

Future<void> _openDeliveryCoordsOnMap(BuildContext context, String coordsRaw) async {
  final coords = coordsRaw.trim();
  if (coords.isEmpty) return;
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(coords)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть карту')),
    );
  }
}

Future<void> _copyDeliveryCoords(BuildContext context, String coordsRaw) async {
  final coords = coordsRaw.trim();
  if (coords.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: coords));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Координаты скопированы')),
    );
  }
}

class _OrderBoardCard extends StatelessWidget {
  const _OrderBoardCard({
    required this.order,
    required this.canManageOnlineOrders,
    required this.canHandoffOrders,
    required this.onCashierAck,
    required this.onCloseOrder,
    required this.onCancelOrder,
    required this.onCallCustomer,
    required this.onChangeTable,
    required this.onChangeOrderType,
    required this.onFreeTable,
    this.compact = false,
  });

  final LocalCashierBoardOrder order;
  final bool canManageOnlineOrders;
  final bool canHandoffOrders;
  final Future<void> Function() onCashierAck;
  final Future<void> Function() onCloseOrder;
  final Future<void> Function() onCancelOrder;
  final VoidCallback onCallCustomer;
  final Future<void> Function() onChangeTable;
  final Future<void> Function() onChangeOrderType;
  final Future<void> Function() onFreeTable;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ui = context.watch<PosCashierBoardCubit>().state;
    final style = posCashierOrderVisualStyle(order, scheme);
    final o = order.order;
    final status = o.status.toLowerCase();
    final completed = status == 'done' || status == 'cancelled';
    final hasTable = order.tableLabel?.trim().isNotEmpty == true;
    final tableLabel = hasTable ? order.tableLabel?.trim() ?? '' : 'Без стола';
    final tableHeadline = cashierTableHeadline(order.tableLabel);
    final tableAssigned = cashierHasAssignedTable(order.tableLabel);
    final tableColor = cashierTableHeadlineColor(
      scheme,
      assigned: tableAssigned,
    );
    final isWebsite = (order.orderSource ?? 'pos').toLowerCase() == 'website';
    final allowActions = !completed &&
        (isWebsite ? canManageOnlineOrders : canHandoffOrders);
    final canPickTable = allowActions &&
        !posOrderLooksLikeDeliveryForTableChange(
          orderType: order.orderType,
          tableLabel: order.tableLabel ?? '',
        );
    final statusRu = switch (status) {
      'new' => 'Новый',
      'cooking' => 'Готовится',
      'ready' => 'Готов',
      'awaiting_expeditor' => 'Сборка',
      'done' => 'Выдан',
      'cancelled' => 'Отменён',
      _ => status,
    };
    final displayItems = ['ready', 'awaiting_expeditor'].contains(status)
        ? filterAssemblyRoundItems(
            o.items,
            handedOutAtIso: o.handedOutAtIso,
          )
        : o.items;
    final maxLines =
        compact ? ui.maxItemLinesCompact : ui.maxItemLinesExpanded;
    final visibleItems =
        displayItems.take(maxLines).toList(growable: false);
    final hiddenItems = displayItems.length - visibleItems.length;
    final titleBase = theme.textTheme.titleMedium?.fontSize ?? 16;
    final bodyBase = theme.textTheme.bodyMedium?.fontSize ?? 14;
    final pad = compact ? ui.cardPadding * 0.9 : ui.cardPadding;
    final gap = ui.sectionGap;

    return Material(
      color: style.surfaceTint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openActionsDialog(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: style.accent.withValues(alpha: 0.38)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: style.accent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize:
                            compact ? MainAxisSize.max : MainAxisSize.min,
                        children: [
                          if (ui.showTableOnTop) ...[
                            Text(
                              tableHeadline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize:
                                    (titleBase + 8) * ui.tableHeadlineScale,
                                height: 1.05,
                                color: tableColor,
                              ),
                            ),
                            SizedBox(height: gap * 0.7),
                          ],
                          Row(
                            children: [
                              Container(
                                width: compact ? 40 : 44,
                                height: compact ? 40 : 44,
                                decoration: BoxDecoration(
                                  color: style.accent.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: style.accent.withValues(alpha: 0.45),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  style.icon,
                                  color: style.accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: style.accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: style.accent.withValues(alpha: 0.42),
                                  ),
                                ),
                                child: Text(
                                  style.categoryLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: style.accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatSomoni(o.totalPrice),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: style.accent,
                                  fontSize: titleBase * ui.titleScale,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: gap),
                          Text(
                            '№ ${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: order.orderType)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: titleBase * ui.titleScale,
                            ),
                          ),
                          SizedBox(height: gap * 0.75),
                          Material(
                            color: scheme.surface.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: canPickTable
                                  ? () async {
                                      await onChangeTable();
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.table_restaurant_rounded,
                                      size: 18,
                                      color: canPickTable
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tableLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: bodyBase * ui.itemTextScale,
                                          color: tableAssigned
                                              ? tableColor
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (canPickTable)
                                      Text(
                                        hasTable ? 'Сменить' : 'Указать',
                                        style:
                                            theme.textTheme.labelMedium?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: gap * 0.75),
                          Text(
                            '$statusRu · ${displayItems.length} поз.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              fontSize: (bodyBase - 1) * ui.itemTextScale,
                            ),
                          ),
                          if (order.requiresPayment) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Нужна оплата',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          SizedBox(height: gap),
                          if (compact)
                            Expanded(
                              child: _boardCardItems(
                                context,
                                theme,
                                scheme,
                                visibleItems,
                                hiddenItems,
                                displayItems.isEmpty,
                                itemTextScale: ui.itemTextScale,
                              ),
                            )
                          else
                            _boardCardItems(
                              context,
                              theme,
                              scheme,
                              visibleItems,
                              hiddenItems,
                              displayItems.isEmpty,
                              itemTextScale: ui.itemTextScale,
                            ),
                          if (allowActions) ...[
                            if (!compact) SizedBox(height: gap),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Открыть заказ',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: style.accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _boardCardItems(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<LocalKitchenQueueItem> visibleItems,
    int hiddenItems,
    bool empty, {
    double itemTextScale = 1,
  }) {
    final bodyBase = theme.textTheme.bodyMedium?.fontSize ?? 14;
    if (empty) {
      return Text(
        'Позиций нет',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final it in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              '• ${it.quantity > 1 ? '${it.quantity}× ' : ''}${it.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _cashierItemStatusColor(context, it.kitchenLineStatus),
                height: 1.2,
                fontWeight: FontWeight.w600,
                fontSize: bodyBase * itemTextScale,
              ),
            ),
          ),
        if (hiddenItems > 0)
          Text(
            '+$hiddenItems ещё',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Future<void> _openActionsDialog(BuildContext context) async {
    final o = order.order;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return AlertDialog(
          insetPadding: _dialogInsetPadding(ctx),
          backgroundColor: scheme.surfaceContainerLow,
          title: Text(
            'Заказ № ${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: order.orderType)}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: _dialogWidth(ctx, 760),
            child: SingleChildScrollView(
              child: _OrderListTile(
                order: order,
                canManageOnlineOrders: canManageOnlineOrders,
                canHandoffOrders: canHandoffOrders,
                onCashierAck: () async {
                  Navigator.of(ctx).pop();
                  await onCashierAck();
                },
                onCloseOrder: () async {
                  Navigator.of(ctx).pop();
                  await onCloseOrder();
                },
                onCancelOrder: () async {
                  Navigator.of(ctx).pop();
                  await onCancelOrder();
                },
                onCallCustomer: () {
                  Navigator.of(ctx).pop();
                  onCallCustomer();
                },
                onChangeTable: () async {
                  Navigator.of(ctx).pop();
                  await onChangeTable();
                },
                onChangeOrderType: () async {
                  Navigator.of(ctx).pop();
                  await onChangeOrderType();
                },
                onFreeTable: () async {
                  Navigator.of(ctx).pop();
                  await onFreeTable();
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Назад'),
            ),
          ],
        );
      },
    );
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({
    required this.order,
    required this.canManageOnlineOrders,
    required this.canHandoffOrders,
    required this.onCashierAck,
    required this.onCloseOrder,
    required this.onCancelOrder,
    this.onCallCustomer,
    this.onEditOrder,
    this.onChangeTable,
    this.onChangeOrderType,
    this.onFreeTable,
  });

  final LocalCashierBoardOrder order;
  final bool canManageOnlineOrders;
  final bool canHandoffOrders;
  final Future<void> Function() onCashierAck;
  final Future<void> Function() onCloseOrder;
  final Future<void> Function() onCancelOrder;
  final VoidCallback? onCallCustomer;
  final Future<void> Function()? onEditOrder;
  final Future<void> Function()? onChangeTable;
  final Future<void> Function()? onChangeOrderType;
  final Future<void> Function()? onFreeTable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = order.order;
    final typeLine = _cashierBoardOrderTypeRu(order.orderType);
    final waiterOrder = _isWaiterOrderLabel(order.orderType);
    final status = o.status.toLowerCase();
    final completed = status == 'done' || status == 'cancelled';
    final tableLabel = order.tableLabel?.trim().isNotEmpty == true
        ? order.tableLabel?.trim() ?? ''
        : 'Без стола';
    final websiteMeta = parseWebsiteOrderDeliveryMeta(tableLabel);
    final actorHint = _cashierKitchenActorHint(o);
    final isWebsite =
        (order.orderSource ?? 'pos').toLowerCase() == 'website';
    final allowActions = !completed &&
        (isWebsite ? canManageOnlineOrders : canHandoffOrders);
    final stacked = WindowLayout.of(context).isCompact;
    final displayItems = ['ready', 'awaiting_expeditor'].contains(status)
        ? filterAssemblyRoundItems(
            o.items,
            handedOutAtIso: o.handedOutAtIso,
          )
        : o.items;
    final visibleItems = displayItems.take(stacked ? 3 : 5).toList(growable: false);
    final hiddenItems = displayItems.length - visibleItems.length;
    final isFollowUpDisplay = shouldShowFollowUpAssemblyLabel(
      items: o.items,
      handedOutAtIso: o.handedOutAtIso,
    );

    final actions = Column(
      crossAxisAlignment:
          stacked ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => showPosOrderHistoryDialog(
            context,
            orderId: o.id,
            orderNumber: _cashierOrderDisplayNumber(
              number: o.number,
              orderTypeRaw: order.orderType,
            ),
          ),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('История'),
        ),
        const SizedBox(height: 6),
        if (!allowActions && !completed)
          Text(
            isWebsite ? 'Только касса' : 'Только просмотр',
            textAlign: stacked ? TextAlign.center : TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          )
        else if (allowActions) ...[
          if (onCallCustomer != null && websiteMeta.phone != null) ...[
            OutlinedButton.icon(
              onPressed: onCallCustomer,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: const Text('Позвонить'),
            ),
            const SizedBox(height: 6),
          ],
          if (isWebsite && onEditOrder != null && canManageOnlineOrders) ...[
            OutlinedButton.icon(
              onPressed: () => onEditOrder!(),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Изменить'),
            ),
            const SizedBox(height: 6),
          ],
          if (onChangeOrderType != null) ...[
            OutlinedButton.icon(
              onPressed: () => onChangeOrderType!(),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Тип заказа'),
            ),
            const SizedBox(height: 6),
          ],
          if (onChangeTable != null &&
              !posOrderLooksLikeDeliveryForTableChange(
                orderType: order.orderType,
                tableLabel: tableLabel,
              )) ...[
            OutlinedButton.icon(
              onPressed: () => onChangeTable!(),
              icon: const Icon(Icons.table_restaurant_rounded, size: 18),
              label: Text(
                (order.tableLabel ?? '').trim().isEmpty ? 'Указать стол' : 'Сменить стол',
              ),
            ),
            const SizedBox(height: 6),
            if (onFreeTable != null &&
                (order.tableLabel ?? '').trim().isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => onFreeTable!(),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('Освободить стол'),
              ),
            if (onFreeTable != null &&
                (order.tableLabel ?? '').trim().isNotEmpty)
              const SizedBox(height: 6),
          ],
          if (order.needsCashierAck)
            FilledButton(
              onPressed: onCashierAck,
              child: const Text('Принять'),
            )
          else ...[
            FilledButton.tonal(
              onPressed: onCloseOrder,
              child: Text(status == 'ready' ? 'Выдать' : 'Закрыть'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: onCancelOrder, child: const Text('Отменить')),
          ],
        ] else
          Text(
            'Только просмотр',
            textAlign: stacked ? TextAlign.center : TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (order.requiresPayment) ...[
          const SizedBox(height: 6),
          Text(
            'Нужна оплата',
            textAlign: stacked ? TextAlign.center : TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );

    final orderHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cashierTableHeadline(order.tableLabel),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: cashierTableHeadlineColor(
              scheme,
              assigned: cashierHasAssignedTable(order.tableLabel),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '№ ${_cashierOrderDisplayNumber(number: o.number, orderTypeRaw: order.orderType)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          typeLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: onChangeTable == null ||
                            posOrderLooksLikeDeliveryForTableChange(
                              orderType: order.orderType,
                              tableLabel: tableLabel,
                            )
                        ? null
                        : () => onChangeTable!(),
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWebsite
                            ? Icons.shopping_bag_outlined
                            : Icons.table_restaurant_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        websiteMeta.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (onChangeTable != null &&
                          !posOrderLooksLikeDeliveryForTableChange(
                            orderType: order.orderType,
                            tableLabel: tableLabel,
                          )) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
                if (isWebsite &&
                    (websiteMeta.phone != null ||
                        websiteMeta.deliveryDate != null ||
                        websiteMeta.deliveryWhen != null)) ...[
                  const SizedBox(height: 6),
                  if (websiteMeta.phone != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Тел: ${websiteMeta.phone}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (onCallCustomer != null)
                          IconButton(
                            tooltip: 'Позвонить',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: onCallCustomer,
                            icon: Icon(
                              Icons.phone_rounded,
                              size: 20,
                              color: scheme.primary,
                            ),
                          ),
                      ],
                    ),
                  if (websiteMeta.deliveryDate != null ||
                      websiteMeta.deliveryWhen != null) ...[
                    if (websiteMeta.phone != null) const SizedBox(height: 2),
                    Text(
                      [
                        if (websiteMeta.deliveryDate != null)
                          'Дата: ${websiteMeta.deliveryDate}',
                        if (websiteMeta.deliveryWhen != null)
                          websiteMeta.deliveryWhen!
                                  .toLowerCase()
                                  .contains('скорее')
                              ? 'Время: ${websiteMeta.deliveryWhen}'
                              : 'Окно: ${websiteMeta.deliveryWhen}',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
                if (websiteMeta.address != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Адрес: ${websiteMeta.address}',
                    maxLines: stacked ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (websiteMeta.courierHandoff != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    websiteMeta.courierHandoff!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (websiteMeta.coords != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Коорд: ${websiteMeta.coords}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _copyDeliveryCoords(context, websiteMeta.coords!),
                        child: const Text('Копировать'),
                      ),
                      TextButton(
                        onPressed: () => _openDeliveryCoordsOnMap(context, websiteMeta.coords!),
                        child: const Text('На карте'),
                      ),
                    ],
                  ),
                ],
        if (waiterOrder) ...[
          const SizedBox(height: 6),
          _WaiterSourceChip(compact: true),
        ],
        const SizedBox(height: 4),
        Text(
          _cashierOrderStatusRu(o.status),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final orderDetails = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == 'done') ...[
                  const SizedBox(height: 6),
                  _CashierHandOutSourceRow(source: o.handOutSource),
                ],
                if (isFollowUpDisplay) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Дозаказ — только новые позиции',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (actorHint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    actorHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (!order.requiresPayment && o.totalPrice > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    _posReceiptPrintedShortRu(order.receiptPrinted),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: order.receiptPrinted == true
                          ? const Color(0xFF2E7D32)
                          : order.receiptPrinted == false
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final it in visibleItems)
                      Text(
                        '• ${it.quantity > 1 ? '${it.quantity}x ' : ''}${it.name} (${it.assemblyStatusShortRu})',
                        maxLines: stacked ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _cashierItemStatusColor(context, it.kitchenLineStatus),
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (hiddenItems > 0)
                      Text(
                        '+$hiddenItems позиций',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
    );

    final priceText = Text(
      formatSomoni(o.totalPrice),
      style: theme.textTheme.titleMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );

    return Container(
      padding: EdgeInsets.all(stacked ? 16 : 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                orderHeader,
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: priceText),
                    const SizedBox(width: 8),
                    Flexible(child: actions),
                  ],
                ),
                const SizedBox(height: 10),
                orderDetails,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      orderHeader,
                      const SizedBox(height: 8),
                      orderDetails,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    priceText,
                    const SizedBox(height: 10),
                    actions,
                  ],
                ),
              ],
            ),
    );
  }
}

class _WaiterSourceChip extends StatelessWidget {
  const _WaiterSourceChip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.room_service_rounded,
            size: compact ? 13 : 15,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            'Официант',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
