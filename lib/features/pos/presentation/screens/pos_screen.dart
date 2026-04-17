import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/app/locale/locale_state.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/core/cache/pos_local_cache_cleanup.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/formatting/money_format.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/core/locale/api_locale.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/auth/bloc/auth_state.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/features/menu/data/menu_repository.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/expeditor/presentation/widgets/expeditor_queue_panel.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_realtime.dart';
import 'package:dk_pos/features/pos/bloc/pos_hall_orders_cubit.dart';
import 'package:dk_pos/features/pos/data/open_table_bill_from_server.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_window_service.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/shared/shared.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

import '../widgets/pos_cart_panel.dart';
import '../widgets/pos_cart_sheet.dart';
import '../widgets/pos_catalog_body.dart';
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
    default:
      return status;
  }
}

String _cashierItemsPreview(List<LocalKitchenQueueItem> items) {
  if (items.isEmpty) return '—';
  final parts = <String>[];
  for (var i = 0; i < items.length && i < 4; i++) {
    final it = items[i];
    parts.add('${it.assemblyTitleWithStation()} ${it.assemblyStatusShortRu}');
  }
  final more = items.length > 4 ? ' +${items.length - 4}' : '';
  return '${parts.join(' · ')}$more';
}

bool _isWaiterOrderLabel(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v.contains('официант') || v.contains('waiter');
}

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
  final _customerDisplayWindow = CustomerDisplayWindowService.instance;
  Timer? _customerDisplayConfigTimer;
  Timer? _expeditorQueueTimer;
  Timer? _openTableBillsTimer;
  final LocalOrdersRealtime _posOrdersRealtime = LocalOrdersRealtime();
  StreamSubscription<LocalOrdersRealtimeEvent>? _posOrdersRealtimeSub;
  int _expeditorBundlingCount = 0;
  int _expeditorPickupCount = 0;
  List<LocalCashierBoardOrder> _incomingBoard = const [];
  List<LocalCashierBoardOrder> _activeBoard = const [];

  final AudioPlayer _cashierAlertPlayer = AudioPlayer();
  bool _cashierAlertInitialized = false;
  final Set<String> _knownIncomingOrderIds = <String>{};
  final Set<String> _knownOpenTableBillIds = <String>{};

  static const String _branchId = 'branch_1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final user = context.read<AuthBloc>().state.user;
      if (user?.role == 'cashier') {
        if (AppConfig.isCustomerDisplayWindowDisabled) {
          _customerDisplayConfigTimer?.cancel();
          await _customerDisplayWindow.close();
        } else {
          await _refreshCustomerDisplayConfig();
          _customerDisplayConfigTimer?.cancel();
          _customerDisplayConfigTimer = Timer.periodic(
            const Duration(seconds: 20),
            (_) => _refreshCustomerDisplayConfig(),
          );
        }
      } else {
        _customerDisplayConfigTimer?.cancel();
        await _customerDisplayWindow.close();
      }
      _syncExpeditorPollingForCashier();
      _startCashierSessionSync();
    });
  }

  void _startCashierSessionSync() {
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') {
      _openTableBillsTimer?.cancel();
      _openTableBillsTimer = null;
      _posOrdersRealtimeSub?.cancel();
      _posOrdersRealtimeSub = null;
      unawaited(_posOrdersRealtime.disconnect());
      _cashierAlertInitialized = false;
      _knownIncomingOrderIds.clear();
      _knownOpenTableBillIds.clear();
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
      const Duration(seconds: 22),
      (_) => unawaited(_refreshCashierSessionData()),
    );
    unawaited(_refreshCashierSessionData());
    unawaited(_ensurePosOrdersRealtime());
  }

  Future<void> _ensurePosOrdersRealtime() async {
    await _posOrdersRealtime.disconnect();
    await _posOrdersRealtimeSub?.cancel();
    _posOrdersRealtimeSub = null;
    try {
      await _posOrdersRealtime.connect(branchId: _branchId, clientType: 'pos');
    } catch (_) {
      return;
    }
    _posOrdersRealtimeSub = _posOrdersRealtime.events.listen((e) {
      final t = e.type;
      if (t == 'order.created' ||
          t == 'order.updated' ||
          t == 'payment.accepted' ||
          t == 'order.status_changed') {
        unawaited(_refreshCashierSessionData());
      }
    });
  }

  Future<void> _refreshCashierSessionData() async {
    final newTableBill = await _refreshOpenTableBills(sessionBatch: true);
    final newIncoming = await _refreshCashierBoard(sessionBatch: true);
    if (!mounted) return;
    if (!_cashierAlertInitialized) {
      _cashierAlertInitialized = true;
      return;
    }
    if (newTableBill || newIncoming) {
      unawaited(_playCashierNewOrderSound());
    }
  }

  /// Новые счета на столах (по данным сервера). `true` — появился id, которого не было в прошлом опросе.
  Future<bool> _refreshOpenTableBills({bool sessionBatch = false}) async {
    if (!mounted) return false;
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return false;
    try {
      final dtos = await context.read<LocalOrdersRepository>().fetchOpenTableBills(
            branchId: _branchId,
          );
      if (!mounted) return false;
      final serverIds = dtos.map((d) => d.id).where((id) => id.isNotEmpty).toSet();
      final hasNew = _cashierAlertInitialized &&
          serverIds.difference(_knownOpenTableBillIds).isNotEmpty;
      _knownOpenTableBillIds
        ..clear()
        ..addAll(serverIds);

      final bills = dtos
          .where((d) => d.id.isNotEmpty)
          .map(posTableBillFromServerDto)
          .toList(growable: false);
      context.read<PosHallOrdersCubit>().mergeHydrateFromServer(bills);
      if (hasNew && !sessionBatch) {
        unawaited(_playCashierNewOrderSound());
      }
      return hasNew;
    } catch (_) {
      return false;
    }
  }

  /// Онлайн-входящие на кассу. `true` — новый заказ в списке «принять».
  Future<bool> _refreshCashierBoard({bool sessionBatch = false}) async {
    if (!mounted) return false;
    final role = context.read<AuthBloc>().state.user?.role;
    if (role != 'cashier' && role != 'admin') return false;
    try {
      final repo = context.read<LocalOrdersRepository>();
      final incoming = await repo.fetchCashierIncomingOrders(branchId: _branchId);
      final active = await repo.fetchCashierActiveOrders(branchId: _branchId);
      if (!mounted) return false;
      final ids = incoming.map((e) => e.order.id).where((id) => id.isNotEmpty).toSet();
      final hasNew =
          _cashierAlertInitialized && ids.difference(_knownIncomingOrderIds).isNotEmpty;
      _knownIncomingOrderIds
        ..clear()
        ..addAll(ids);

      setState(() {
        _incomingBoard = incoming;
        _activeBoard = active;
      });
      if (hasNew && !sessionBatch) {
        unawaited(_playCashierNewOrderSound());
      }
      return hasNew;
    } catch (_) {
      return false;
    }
  }

  Future<void> _playCashierNewOrderSound() async {
    if (!mounted) return;
    try {
      final settings = await context.read<LocalAudioSettingsRepository>().fetch(
            branchId: _branchId,
          );
      final kitchen = (settings.kitchenSoundPath ?? '').trim();
      final ready = (settings.readySoundPath ?? '').trim();
      final path = kitchen.isNotEmpty ? kitchen : ready;
      if (path.isEmpty) return;
      final url = AppConfig.mediaUrl(path);
      if (url.isEmpty) return;
      await _cashierAlertPlayer.stop();
      await _cashierAlertPlayer.play(UrlSource(url));
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
      await _refreshCashierBoard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Заказ №${row.order.number} принят на кассе'),
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
    if (user?.role != 'cashier') {
      if (mounted) {
        setState(() {
          _expeditorBundlingCount = 0;
          _expeditorPickupCount = 0;
        });
      }
      return;
    }
    _expeditorQueueTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshExpeditorQueueCounts(),
    );
    _refreshExpeditorQueueCounts();
  }

  Future<void> _refreshExpeditorQueueCounts() async {
    if (!mounted) return;
    if (context.read<AuthBloc>().state.user?.role != 'cashier') return;
    try {
      final snap = await context.read<LocalOrdersRepository>().fetchExpeditorQueue();
      if (!mounted) return;
      setState(() {
        _expeditorBundlingCount = snap.bundling.length;
        _expeditorPickupCount = snap.pickup.length;
      });
    } catch (_) {
      // сеть/API — не блокируем кассу
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
    _customerDisplayConfigTimer?.cancel();
    _expeditorQueueTimer?.cancel();
    _openTableBillsTimer?.cancel();
    _posOrdersRealtimeSub?.cancel();
    unawaited(_posOrdersRealtime.dispose());
    _cashierAlertPlayer.dispose();
    _customerDisplayWindow.close();
    super.dispose();
  }

  Future<void> _refreshCustomerDisplayConfig() async {
    final user = context.read<AuthBloc>().state.user;
    if (user?.role != 'cashier') return;
    try {
      final screens = await context.read<ScreensAdminRepository>().fetchScreens(
        activeOnly: true,
      );
      screens.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.id.compareTo(b.id);
      });
      final customerScreens = screens
          .where((s) => s.type == 'customer_display')
          .toList(growable: false);
      final screen = customerScreens.isEmpty ? null : customerScreens.first;
      final config = screen == null
          ? null
          : CustomerDisplayContentConfig.fromScreenConfig(screen.config);
      if (!mounted) return;
      await _customerDisplayWindow.setDisplayContentConfig(
        config,
        context.read<CartBloc>().state,
      );
    } catch (_) {
      // Не блокируем POS, если конструктор клиентского экрана недоступен.
    }
  }

  void _logout(BuildContext context) {
    unawaited(clearPosLocalCaches());
    context.read<CartBloc>().add(const CartResetAll());
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  Future<void> _showOrdersDialog() async {
    await _refreshCashierBoard();
    if (!mounted) return;
    final showHandoffTab = context.read<AuthBloc>().state.user?.role == 'cashier';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _PosOrdersDialog(
        showHandoffTab: showHandoffTab,
        orders: List<LocalCashierBoardOrder>.unmodifiable(_activeBoard),
      ),
    ).then((_) => _refreshExpeditorQueueCounts());
  }

  Future<void> _showOnlineOrdersDialog() async {
    await _refreshCashierBoard();
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _OnlineOrdersDialog(
        orders: List<LocalCashierBoardOrder>.unmodifiable(_incomingBoard),
        onAccept: (order) async {
          Navigator.of(dialogContext).pop();
          await _onAcceptIncoming(order);
          if (mounted) await _showOnlineOrdersDialog();
        },
      ),
    );
  }

  Future<void> _showSettingsDialog() {
    final localeBloc = context.read<LocaleBloc>();
    var selectedLocaleCode = localeBloc.state.locale.languageCode;

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
                width: 420,
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
                    BlocBuilder<PosThemeCubit, PosScreenTheme>(
                      builder: (context, posTheme) {
                        return Row(
                          children: [
                            Expanded(
                              child: _SettingsChoiceChip(
                                label: 'Светлая',
                                selected: posTheme == PosScreenTheme.light,
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
                                selected: posTheme == PosScreenTheme.dark,
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
                  ],
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
        BlocListener<CartBloc, CartState>(
          listener: (context, cart) {
            final user = context.read<AuthBloc>().state.user;
            if (user?.role == 'cashier') {
              _customerDisplayWindow.syncCart(cart);
            } else {
              _customerDisplayWindow.close();
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (prev, curr) => prev.user?.role != curr.user?.role,
          listener: (context, state) => _syncExpeditorPollingForCashier(),
        ),
      ],
      child: BlocBuilder<MenuBloc, MenuState>(
        builder: (context, menu) {
          return BlocBuilder<CartBloc, CartState>(
            builder: (context, cart) {
              final narrowBar = MediaQuery.sizeOf(context).width < 420;
              final dockedCart = WindowLayout.of(context).dockPosCart;
              final canOpenCustomerDisplay = user?.role == 'cashier';

              return Scaffold(
                  appBar: AppBar(
                    toolbarHeight: 84,
                    titleSpacing: 16,
                    bottom: const PosAppBarCheckTabs(),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doner Kebab',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Кассовое рабочее место • Быстрая сборка заказа',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
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
                            _PosCompactMenu(
                              menu: menu,
                              user: user,
                              onOpenOrders: _showOrdersDialog,
                              onOpenOnlineOrders: _showOnlineOrdersDialog,
                              onOpenTableBills: () =>
                                  showOpenTableBillsDialog(context),
                              onOpenSettings: _showSettingsDialog,
                              onOpenCustomerDisplay: canOpenCustomerDisplay
                                  ? () => _customerDisplayWindow
                                      .openCustomerDisplay(cart)
                                  : null,
                              onLogout: () => _logout(context),
                            ),
                          ]
                        : [
                            if (user != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Center(
                                  child: Chip(
                                    avatar: const Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                    ),
                                    label: Text(user.roleLabel(l10n)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Center(
                                child: _TopInfoBadge(
                                  icon: Icons.wifi_rounded,
                                  label: 'Online',
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Center(
                                child: _TopInfoBadge(
                                  icon: Icons.receipt_long_rounded,
                                  label: '${cart.itemCount} поз.',
                                ),
                              ),
                            ),
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
                            if (canOpenCustomerDisplay)
                              IconButton(
                                icon: const Icon(Icons.tv_rounded),
                                tooltip: 'Экран для клиента',
                                onPressed: () => _customerDisplayWindow
                                    .openCustomerDisplay(cart),
                              ),
                            TextButton.icon(
                              onPressed: () => _logout(context),
                              icon: const Icon(Icons.logout_rounded),
                              label: Text(l10n.actionExit),
                            ),
                            const SizedBox(width: 8),
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
                              final catalog = PosCatalogBody(
                                menu: menu,
                                catalogPaneWidth: WindowLayout(
                                  width: constraints.maxWidth,
                                ).posCatalogPaneWidth,
                              );
                              return BlocBuilder<PosHallOrdersCubit,
                                  PosHallOrdersState>(
                                builder: (context, hall) {
                                  final openBillsCount = hall.openBills.length;
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
                                                urgent: user?.role == 'cashier' &&
                                                    (_expeditorBundlingCount > 0 ||
                                                        _expeditorPickupCount > 0),
                                                onTap: _showOrdersDialog,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _WorkspaceActionCard(
                                                icon:
                                                    Icons.phone_in_talk_rounded,
                                                label: 'Онлайн заказы',
                                                value:
                                                    '${_incomingBoard.length} новых',
                                                tone: theme.brightness ==
                                                        Brightness.dark
                                                    ? scheme.secondary
                                                    : const Color(0xFFB26A00),
                                                urgent:
                                                    _incomingBoard.isNotEmpty,
                                                onTap: _showOnlineOrdersDialog,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _WorkspaceActionCard(
                                                icon: Icons
                                                    .table_restaurant_rounded,
                                                label: 'Счета на столах',
                                                value:
                                                    '$openBillsCount открытых',
                                                tone: const Color(0xFF5B8DEF),
                                                urgent: openBillsCount > 0,
                                                onTap: () =>
                                                    showOpenTableBillsDialog(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                  final showWorkspaceCards = !narrowBar;

                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
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
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: scheme.outlineVariant,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x66000000),
                                            blurRadius: 28,
                                            offset: Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(28),
                                        child: dockedCart
                                            ? Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(
                                                    child: Column(
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
                                                        Expanded(
                                                          child: catalog,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VerticalDivider(
                                                    width: 1,
                                                    thickness: 1,
                                                    color: scheme.outlineVariant,
                                                  ),
                                                  SizedBox(
                                                    width: WindowLayout
                                                        .posCartPanelWidth,
                                                    child: ColoredBox(
                                                      color: scheme
                                                          .surfaceContainerLow,
                                                      child:
                                                          const PosCartPanel(),
                                                    ),
                                                  ),
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

class _PosCompactMenu extends StatelessWidget {
  const _PosCompactMenu({
    required this.menu,
    required this.user,
    required this.onOpenOrders,
    required this.onOpenOnlineOrders,
    required this.onOpenTableBills,
    required this.onOpenSettings,
    this.onOpenCustomerDisplay,
    required this.onLogout,
  });

  final MenuState menu;
  final UserModel? user;
  final Future<void> Function() onOpenOrders;
  final Future<void> Function() onOpenOnlineOrders;
  final Future<void> Function() onOpenTableBills;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenCustomerDisplay;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;

    return PopupMenuButton<String>(
      tooltip: l10n.tooltipAppMenu,
      icon: const Icon(Icons.menu_rounded),
      onSelected: (value) {
        if (value == 'refresh') {
          if (!menu.loading) {
            context.read<MenuBloc>().add(
              MenuLoadRequested(
                lang: menuApiLanguageCode(context.appUiLocale.languageCode),
              ),
            );
          }
          return;
        }
        if (value == 'settings') {
          onOpenSettings();
          return;
        }
        if (value == 'orders') {
          onOpenOrders();
          return;
        }
        if (value == 'online_orders') {
          onOpenOnlineOrders();
          return;
        }
        if (value == 'table_bills') {
          onOpenTableBills();
          return;
        }
        if (value == 'customer_display') {
          onOpenCustomerDisplay?.call();
          return;
        }
        if (value == 'exit') {
          onLogout();
        }
      },
      itemBuilder: (ctx) {
        final isCashierOrAdmin = user?.role == 'cashier' || user?.role == 'admin';
        return [
          PopupMenuItem(
            value: 'refresh',
            enabled: !menu.loading,
            child: Text(l10n.actionRefreshMenu),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'orders', child: Text('Заказы')),
          const PopupMenuItem(
            value: 'table_bills',
            child: Text('Счета на столах'),
          ),
          if (isCashierOrAdmin)
            const PopupMenuItem(
              value: 'online_orders',
              child: Text('Онлайн заказы'),
            ),
          if (user?.role == 'cashier' && onOpenCustomerDisplay != null)
            const PopupMenuItem(
              value: 'customer_display',
              child: Text('Экран для клиента'),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'settings', child: const Text('Настройки')),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'exit', child: Text(l10n.actionExit)),
        ];
      },
    );
  }
}

class _TopInfoBadge extends StatelessWidget {
  const _TopInfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.20)),
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
    this.urgent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final VoidCallback onTap;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
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
          ),
          if (urgent)
            const Positioned(right: -4, top: -6, child: _UrgentOrderBadge()),
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

class _UrgentOrderBadge extends StatefulWidget {
  const _UrgentOrderBadge();

  @override
  State<_UrgentOrderBadge> createState() => _UrgentOrderBadgeState();
}

class _UrgentOrderBadgeState extends State<_UrgentOrderBadge>
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

    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFE4002B),
          shape: BoxShape.circle,
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
          '!',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
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
  });

  final List<LocalCashierBoardOrder> orders;
  final bool showHandoffTab;

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
        backgroundColor: scheme.surfaceContainerLow,
        title: Text(l10n.posOrdersDialogTitle, style: titleStyle),
        content: SizedBox(
          width: 720,
          child: _HallOrdersList(orders: orders),
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
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          width: 760,
          height: 560,
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
                      _HallOrdersList(orders: orders),
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

class _HallOrdersList extends StatelessWidget {
  const _HallOrdersList({required this.orders});

  final List<LocalCashierBoardOrder> orders;

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.posOrdersActiveEmpty),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < orders.length; i++) ...[
          _OrderListTile(order: orders[i]),
          if (i != orders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OnlineOrdersDialog extends StatelessWidget {
  const _OnlineOrdersDialog({required this.orders, required this.onAccept});

  final List<LocalCashierBoardOrder> orders;
  final Future<void> Function(LocalCashierBoardOrder) onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surfaceContainerLow,
      title: Text(
        'Онлайн заказы',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 760,
        child: orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Новых онлайн-заказов нет'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < orders.length; i++) ...[
                    _OnlineOrderTile(
                      order: orders[i],
                      onAccept: () => onAccept(orders[i]),
                    ),
                    if (i != orders.length - 1) const SizedBox(height: 10),
                  ],
                ],
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

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order});

  final LocalCashierBoardOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = order.order;
    final typeLine =
        order.orderType?.trim().isNotEmpty == true ? order.orderType!.trim() : 'Заказ';
    final waiterOrder = _isWaiterOrderLabel(typeLine);
    final tableExtra = order.tableLabel?.trim().isNotEmpty == true
        ? ' · ${order.tableLabel!.trim()}'
        : '';

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
                  '№ ${o.number}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$typeLine$tableExtra',
                  style: theme.textTheme.bodyMedium,
                ),
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
                const SizedBox(height: 4),
                Text(
                  _cashierItemsPreview(o.items),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatSomoni(o.totalPrice),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineOrderTile extends StatelessWidget {
  const _OnlineOrderTile({required this.order, required this.onAccept});

  final LocalCashierBoardOrder order;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final o = order.order;
    final typeLine =
        order.orderType?.trim().isNotEmpty == true ? order.orderType!.trim() : 'Заказ';
    final waiterOrder = _isWaiterOrderLabel(typeLine);

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
                  '№ ${o.number}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(typeLine),
                if (waiterOrder) ...[
                  const SizedBox(height: 6),
                  _WaiterSourceChip(compact: true),
                ],
                const SizedBox(height: 4),
                Text(
                  _cashierItemsPreview(o.items),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatSomoni(o.totalPrice),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () => onAccept(),
                child: const Text('Принять'),
              ),
              if (order.requiresPayment) ...[
                const SizedBox(height: 8),
                Text(
                  'Нужна оплата',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
