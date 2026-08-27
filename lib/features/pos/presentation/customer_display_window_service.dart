import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_pos_actions.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_sync_state.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_retriever/screen_retriever.dart';

enum CustomerDisplayOpenResult { opened, alreadyOpen, failed }

/// Мгновенно отправить актуальную корзину на экран клиента.
void scheduleCustomerDisplayCartSync(BuildContext context, {CartState? cart}) {
  final svc = CustomerDisplayWindowService.instance;
  if (!svc.isOpen) return;
  final liveCart = cart ?? context.read<CartBloc>().state;
  if (svc.isMenuMode) {
    unawaited(
      svc.pushMenuAndCartSync(
        menu: context.read<MenuBloc>().state,
        cart: liveCart,
      ),
    );
  } else {
    unawaited(svc.syncCart(liveCart));
  }
}

class CustomerDisplayWindowService {
  CustomerDisplayWindowService._();

  static final CustomerDisplayWindowService instance =
      CustomerDisplayWindowService._();

  WindowController? _window;
  bool _singleDisplayPreviewMode = false;

  /// Синхронизация с файлом / вторым окном только после явного «Экран для клиента».
  bool _sessionActive = false;
  final ValueNotifier<bool> openNotifier = ValueNotifier(false);
  CustomerDisplayViewMode _viewMode = CustomerDisplayViewMode.idle;
  CustomerDisplayMenuSnapshot? _menuSnapshot;
  CustomerDisplayThemeSnapshot _themeSnapshot =
      const CustomerDisplayThemeSnapshot();

  bool get isOpen => _sessionActive && _window != null;
  CustomerDisplayViewMode get viewMode => _viewMode;
  bool get isMenuMode => _viewMode == CustomerDisplayViewMode.menu;
  CustomerDisplayThemeSnapshot get themeSnapshot => _themeSnapshot;
  CustomerDisplayContentConfig? _displayContentConfig;
  CustomerDisplayContentConfig? get displayContentConfig =>
      _displayContentConfig;
  CartState? _lastCartForPulse;
  int _cartAddSeq = 0;
  Timer? _actionPollTimer;
  int _lastConsumedActionSeq = 0;
  Future<void> Function()? _onDiscountFromCustomer;
  Future<void> Function()? _onCheckoutFromCustomer;
  Future<void> Function(List<int> pathIds)? _onSetMenuPathFromCustomer;
  Future<void> Function()? _onMenuBackFromCustomer;
  Future<void> Function(String productId)? _onAddItemFromCustomer;
  Future<void> Function(int orderTypeIndex)? _onSetOrderTypeFromCustomer;
  CartState _lastSyncedCart = const CartState();
  List<int> _lastMenuPathIds = const [];
  double _catalogScrollOffset = 0;
  double _catalogScrollProgress = 0;
  int _catalogScrollIndex = 0;
  double _categoryScrollProgress = 0;
  Timer? _scrollSaveDebounce;
  Timer? _categoryScrollSaveDebounce;
  int _syncRevision = 0;
  Future<void> _persistChain = Future<void>.value();
  bool _flushScheduled = false;
  Future<void>? _scheduledFlushFuture;
  CartState? _pendingCart;
  CustomerDisplayMenuSnapshot? _pendingMenuSnapshot;
  CustomerDisplayViewMode? _pendingViewMode;

  /// Чек открытого счёта (режим оплаты без активной корзины кассы).
  CustomerDisplayCartData? _explicitCartSnapshot;
  final File _syncFile = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}dk_pos_customer_display${Platform.pathSeparator}cart.json',
  );

  String get syncFilePath => _syncFile.path;

  bool get _isSupported => Platform.isWindows;
  bool get isSupportedPlatform => _isSupported;

  Future<bool> hasSecondaryDisplay() async {
    if (!_isSupported) return false;
    try {
      final displays = await screenRetriever.getAllDisplays();
      return displays.length > 1;
    } catch (e, stack) {
      debugPrint(
        'CustomerDisplayWindowService.hasSecondaryDisplay: $e\n$stack',
      );
      return false;
    }
  }

  Future<void> _ensureSyncDirectory() async {
    await _syncFile.parent.create(recursive: true);
  }

  void registerPosActionHandlers({
    Future<void> Function()? onDiscount,
    Future<void> Function()? onCheckout,
    Future<void> Function(List<int> pathIds)? onSetMenuPath,
    Future<void> Function()? onMenuBack,
    Future<void> Function(String productId)? onAddItem,
    Future<void> Function(int orderTypeIndex)? onSetOrderType,
  }) {
    _onDiscountFromCustomer = onDiscount;
    _onCheckoutFromCustomer = onCheckout;
    _onSetMenuPathFromCustomer = onSetMenuPath;
    _onMenuBackFromCustomer = onMenuBack;
    _onAddItemFromCustomer = onAddItem;
    _onSetOrderTypeFromCustomer = onSetOrderType;
  }

  void noteCatalogScrollOffset(double offset) {
    noteCatalogScroll(
      offset: offset,
      progress: _catalogScrollProgress,
      firstVisibleIndex: _catalogScrollIndex,
    );
  }

  /// Скролл каталога кассы → экран клиента (прогресс + индекс, не сырые пиксели).
  void noteCatalogScroll({
    required double offset,
    required double progress,
    required int firstVisibleIndex,
  }) {
    if (!_sessionActive || _viewMode != CustomerDisplayViewMode.menu) return;
    final nextProgress = progress.clamp(0.0, 1.0);
    final nextIndex = firstVisibleIndex < 0 ? 0 : firstVisibleIndex;
    final offsetChanged = (offset - _catalogScrollOffset).abs() >= 4;
    final progressChanged =
        (nextProgress - _catalogScrollProgress).abs() >= 0.008;
    final indexChanged = nextIndex != _catalogScrollIndex;
    if (!offsetChanged && !progressChanged && !indexChanged) return;
    _catalogScrollOffset = offset;
    _catalogScrollProgress = nextProgress;
    _catalogScrollIndex = nextIndex;
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(
      const Duration(milliseconds: 50),
      () => unawaited(_persistCatalogScroll()),
    );
  }

  Future<void> _persistCatalogScroll() async {
    if (!_sessionActive || _menuSnapshot == null) return;
    final menu = _menuSnapshot!.copyWith(
      catalogScrollOffset: _catalogScrollOffset,
      catalogScrollProgress: _catalogScrollProgress,
      catalogScrollIndex: _catalogScrollIndex,
    );
    _menuSnapshot = menu;
    await _schedulePersist(
      cart: _lastSyncedCart,
      menuSnapshot: menu,
      viewMode: _viewMode,
    );
  }

  /// Категории могут иметь другую высоту на кассе и у клиента, поэтому
  /// передаём нормализованную позицию, а не количество пикселей.
  void noteCategoryScroll({required double progress}) {
    if (!_sessionActive || _viewMode != CustomerDisplayViewMode.menu) return;
    final nextProgress = progress.clamp(0.0, 1.0);
    if ((nextProgress - _categoryScrollProgress).abs() < 0.012) return;
    _categoryScrollProgress = nextProgress;
    _categoryScrollSaveDebounce?.cancel();
    _categoryScrollSaveDebounce = Timer(
      const Duration(milliseconds: 70),
      () => unawaited(_persistCategoryScroll()),
    );
  }

  Future<void> _persistCategoryScroll() async {
    if (!_sessionActive || _menuSnapshot == null) return;
    final menu = _menuSnapshot!.copyWith(
      categoryScrollProgress: _categoryScrollProgress,
    );
    _menuSnapshot = menu;
    await _schedulePersist(
      cart: _lastSyncedCart,
      menuSnapshot: menu,
      viewMode: _viewMode,
    );
  }

  void _startActionPolling() {
    _actionPollTimer?.cancel();
    _actionPollTimer = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) => unawaited(_consumeCustomerDisplayActions()),
    );
  }

  void _stopActionPolling() {
    _actionPollTimer?.cancel();
    _actionPollTimer = null;
    _lastConsumedActionSeq = 0;
  }

  Future<void> _consumeCustomerDisplayActions() async {
    if (!_sessionActive) return;
    final file = customerDisplayActionsFile(_syncFile.path);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final request = CustomerDisplayPosActionRequest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (request == null || request.seq <= _lastConsumedActionSeq) return;
      _lastConsumedActionSeq = request.seq;
      switch (request.action) {
        case CustomerDisplayPosAction.discount:
          await _onDiscountFromCustomer?.call();
        case CustomerDisplayPosAction.checkout:
          await _onCheckoutFromCustomer?.call();
        case CustomerDisplayPosAction.setMenuPath:
          final path = request.pathIds;
          if (path != null && path.isNotEmpty) {
            await _onSetMenuPathFromCustomer?.call(path);
          }
        case CustomerDisplayPosAction.menuBack:
          await _onMenuBackFromCustomer?.call();
        case CustomerDisplayPosAction.addItem:
          final productId = request.productId?.trim();
          if (productId != null && productId.isNotEmpty) {
            await _onAddItemFromCustomer?.call(productId);
          }
        case CustomerDisplayPosAction.setOrderType:
          final idx = request.orderTypeIndex;
          if (idx != null && idx >= 0 && idx <= 2) {
            await _onSetOrderTypeFromCustomer?.call(idx);
          }
      }
    } catch (e, stack) {
      debugPrint(
        'CustomerDisplayWindowService._consumeCustomerDisplayActions: $e\n$stack',
      );
    }
  }

  Future<bool> ensureOpened({bool allowSingleDisplayPreview = false}) async {
    if (!_isSupported) return false;
    if (AppConfig.isCustomerDisplayWindowDisabled) {
      await close();
      return false;
    }
    try {
      await _ensureSyncDirectory();
      for (var attempt = 0; attempt < 3; attempt++) {
        List<dynamic> displays;
        dynamic primaryDisplay;
        try {
          displays = await screenRetriever.getAllDisplays();
          primaryDisplay = await screenRetriever.getPrimaryDisplay();
        } catch (e, stack) {
          debugPrint(
            'CustomerDisplayWindowService screen_retriever: $e\n$stack',
          );
          displays = const [];
          primaryDisplay = null;
        }
        if (displays.length < 2) {
          if (!allowSingleDisplayPreview) {
            if (_singleDisplayPreviewMode && _window != null) {
              if (!await _tryShowExistingWindow()) {
                continue;
              }
              return true;
            }
            await close();
            return false;
          }
          if (_window != null) {
            _singleDisplayPreviewMode = true;
            if (!await _tryShowExistingWindow()) {
              continue;
            }
            return true;
          }
          final payload = {
            'type': 'customer_display',
            'syncFilePath': _syncFile.path,
            'fullscreen': false,
            'apiOrigin': AppConfig.apiOrigin,
            'theme': _themePayload(),
          };
          _window = await DesktopMultiWindow.createWindow(jsonEncode(payload));
          _singleDisplayPreviewMode = true;
          await _window!.setTitle('Customer Display Preview');
          await _window!.center();
          await _window!.show();
          return true;
        }

        // Два и более монитора: полноэкранно на не-основном.
        if (_window != null && _singleDisplayPreviewMode) {
          await close();
          await Future<void>.delayed(const Duration(milliseconds: 160));
          continue;
        }
        if (_window != null) {
          _singleDisplayPreviewMode = false;
          await _applySecondaryMonitorFrame(_window!, displays, primaryDisplay);
          await _window!.setTitle('Customer Display');
          if (!await _tryShowExistingWindow()) {
            continue;
          }
          return true;
        }

        final targetDisplay = _resolveSecondaryDisplay(
          displays,
          primaryDisplay,
        );
        final visiblePosition = targetDisplay.visiblePosition as Offset?;
        final visibleSize =
            (targetDisplay.visibleSize ?? targetDisplay.size) as Size;

        final payload = {
          'type': 'customer_display',
          'syncFilePath': _syncFile.path,
          'fullscreen': true,
          'apiOrigin': AppConfig.apiOrigin,
          'theme': _themePayload(),
          if (visiblePosition != null)
            'bounds': {
              'x': visiblePosition.dx,
              'y': visiblePosition.dy,
              'width': visibleSize.width,
              'height': visibleSize.height,
            },
        };

        _window = await DesktopMultiWindow.createWindow(jsonEncode(payload));
        _singleDisplayPreviewMode = false;
        await _window!.setTitle('Customer Display');
        if (visiblePosition != null) {
          try {
            await _window!.setFrame(
              Rect.fromLTWH(
                visiblePosition.dx,
                visiblePosition.dy,
                visibleSize.width,
                visibleSize.height,
              ),
            );
          } catch (e, stack) {
            debugPrint('CustomerDisplayWindowService.setFrame: $e\n$stack');
            await _window!.center();
          }
        } else {
          await _window!.center();
        }
        await _window!.show();
        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowService.ensureOpened: $e\n$stack');
      await close();
      return false;
    }
  }

  static dynamic _resolveSecondaryDisplay(
    List<dynamic> displays,
    dynamic primaryDisplay,
  ) {
    try {
      if (primaryDisplay != null) {
        return displays.cast<dynamic>().firstWhere(
          (display) => display.id != primaryDisplay.id,
          orElse: () => displays.length > 1 ? displays[1] : displays[0],
        );
      }
      return displays.length > 1 ? displays[1] : displays[0];
    } catch (e, stack) {
      debugPrint(
        'CustomerDisplayWindowService._resolveSecondaryDisplay: $e\n$stack',
      );
      return displays.length > 1 ? displays[1] : displays[0];
    }
  }

  Future<void> _applySecondaryMonitorFrame(
    WindowController w,
    List<dynamic> displays,
    dynamic primaryDisplay,
  ) async {
    final targetDisplay = _resolveSecondaryDisplay(displays, primaryDisplay);
    final visiblePosition = targetDisplay.visiblePosition as Offset?;
    final visibleSize =
        (targetDisplay.visibleSize ?? targetDisplay.size) as Size;
    if (visiblePosition != null) {
      try {
        await w.setFrame(
          Rect.fromLTWH(
            visiblePosition.dx,
            visiblePosition.dy,
            visibleSize.width,
            visibleSize.height,
          ),
        );
      } catch (e, stack) {
        debugPrint('CustomerDisplayWindowService.setFrame: $e\n$stack');
        await w.center();
      }
    } else {
      await w.center();
    }
  }

  Future<bool> _tryShowExistingWindow() async {
    final window = _window;
    if (window == null) return false;
    try {
      await window.show();
      return true;
    } catch (e, stack) {
      debugPrint(
        'CustomerDisplayWindowService._tryShowExistingWindow: $e\n$stack',
      );
      _window = null;
      _sessionActive = false;
      openNotifier.value = false;
      return false;
    }
  }

  void _markOpen() {
    _sessionActive = true;
    openNotifier.value = true;
    _startActionPolling();
  }

  void _markClosed() {
    _sessionActive = false;
    openNotifier.value = false;
    _stopActionPolling();
  }

  /// Открыть экран клиента в едином режиме меню (приветствие → каталог → чек).
  Future<CustomerDisplayOpenResult> openCustomerDisplay({
    required CartState cart,
    required MenuState menu,
    CustomerDisplayContentConfig? config,
  }) => showMenuMode(cart: cart, menu: menu, config: config);

  /// Обновить корзину на уже открытом экране клиента (не открывает окно само).
  Future<void> syncCart(CartState cart) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    if (_window == null) return;
    await _saveCartToFile(cart);
  }

  /// Мгновенная синхронизация каталога и корзины (до срабатывания BlocListener).
  Future<void> pushMenuAndCartSync({
    required MenuState menu,
    required CartState cart,
    List<int>? pathIds,
  }) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive || _viewMode != CustomerDisplayViewMode.menu) return;
    if (menu.loading) return;

    final effectivePath = pathIds ?? menu.pathIds;
    final effectiveMenu = pathIds != null
        ? menu.copyWith(pathIds: pathIds)
        : menu;
    final pathChanged = !_listEquals(_lastMenuPathIds, effectivePath);
    if (pathChanged) {
      _catalogScrollOffset = 0;
      _catalogScrollProgress = 0;
      _catalogScrollIndex = 0;
      _categoryScrollProgress = 0;
      _lastMenuPathIds = List<int>.from(effectivePath);
      _scrollSaveDebounce?.cancel();
      _scrollSaveDebounce = null;
    }
    final snapshot = CustomerDisplayMenuSnapshot.fromMenuState(
      effectiveMenu,
      catalogScrollOffset: _catalogScrollOffset,
      catalogScrollProgress: _catalogScrollProgress,
      catalogScrollIndex: _catalogScrollIndex,
      categoryScrollProgress: _categoryScrollProgress,
    );
    _menuSnapshot = snapshot;
    _lastSyncedCart = cart;
    await _schedulePersist(
      cart: cart,
      menuSnapshot: snapshot,
      viewMode: _viewMode,
    );
  }

  /// Синхронизировать каталог при режиме «меню» (категории + товары как на кассе).
  Future<void> syncMenu(MenuState menu, CartState cart) async {
    await pushMenuAndCartSync(menu: menu, cart: cart);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Режим «Показать меню»: каталог + корзина на экране клиента.
  Future<CustomerDisplayOpenResult> showMenuMode({
    required CartState cart,
    required MenuState menu,
    CustomerDisplayContentConfig? config,
  }) async {
    _viewMode = CustomerDisplayViewMode.menu;
    _catalogScrollOffset = 0;
    _catalogScrollProgress = 0;
    _catalogScrollIndex = 0;
    _categoryScrollProgress = 0;
    _lastMenuPathIds = List<int>.from(menu.pathIds);
    _menuSnapshot = CustomerDisplayMenuSnapshot.fromMenuState(menu);
    if (config != null) _displayContentConfig = config;
    return _openOrUpdate(cart);
  }

  /// Режим оплаты: чек + QR банка (при «Оформить и оплатить сейчас»).
  Future<void> showPaymentMode(CartState cart) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    _explicitCartSnapshot = null;
    _viewMode = CustomerDisplayViewMode.payment;
    await _saveCartToFile(cart);
  }

  /// Режим оплаты по открытому счёту из «Счета на оплату».
  Future<void> showPaymentModeForBillData(
    CustomerDisplayCartData cartData,
  ) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    _explicitCartSnapshot = cartData;
    _viewMode = CustomerDisplayViewMode.payment;
    await _saveCartToFile(_lastSyncedCart);
  }

  /// После оформления: снова меню с приветствием (без отдельного idle-режима).
  Future<void> returnToMenuMode({
    required MenuState menu,
    CartState cart = const CartState(),
  }) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    _explicitCartSnapshot = null;
    _viewMode = CustomerDisplayViewMode.menu;
    _catalogScrollOffset = 0;
    _catalogScrollProgress = 0;
    _catalogScrollIndex = 0;
    _categoryScrollProgress = 0;
    _lastMenuPathIds = List<int>.from(menu.pathIds);
    _menuSnapshot = CustomerDisplayMenuSnapshot.fromMenuState(menu);
    await _saveCartToFile(cart);
  }

  Future<CustomerDisplayOpenResult> _openOrUpdate(CartState cart) async {
    if (!_isSupported) return CustomerDisplayOpenResult.failed;
    if (AppConfig.isCustomerDisplayWindowDisabled) {
      return CustomerDisplayOpenResult.failed;
    }
    if (isOpen) {
      await _saveCartToFile(cart);
      await ensureOpened(allowSingleDisplayPreview: true);
      return CustomerDisplayOpenResult.alreadyOpen;
    }
    await _saveCartToFile(cart);
    final opened = await ensureOpened(allowSingleDisplayPreview: true);
    if (!opened) return CustomerDisplayOpenResult.failed;
    _markOpen();
    await _saveCartToFile(cart);
    return CustomerDisplayOpenResult.opened;
  }

  /// Синхронизировать тему кассы с экраном клиента.
  void syncPosTheme(PosThemeSettings settings) {
    _themeSnapshot = CustomerDisplayThemeSnapshot.fromPosTheme(settings);
  }

  Map<String, dynamic> _themePayload() => _themeSnapshot.toJson();

  Future<void> setDisplayContentConfig(
    CustomerDisplayContentConfig? config,
    CartState cart,
  ) async {
    _displayContentConfig = config;
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    if (_window == null) return;
    await _saveCartToFile(cart);
  }

  Future<void> close() async {
    _markClosed();
    _viewMode = CustomerDisplayViewMode.menu;
    _explicitCartSnapshot = null;
    _menuSnapshot = null;
    _lastCartForPulse = null;
    _cartAddSeq = 0;
    _catalogScrollOffset = 0;
    _catalogScrollProgress = 0;
    _catalogScrollIndex = 0;
    _categoryScrollProgress = 0;
    _lastMenuPathIds = const [];
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = null;
    _categoryScrollSaveDebounce?.cancel();
    _categoryScrollSaveDebounce = null;
    final window = _window;
    _window = null;
    _singleDisplayPreviewMode = false;
    if (window == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(window.windowId, 'window.close');
    } catch (_) {
      // Второе окно может уже быть закрыто вручную.
    }
  }

  /// Удаляет json синхронизации с экраном клиента (%TEMP%/dk_pos_customer_display/ на Windows).
  Future<void> clearSyncFile() async {
    try {
      if (await _syncFile.exists()) {
        await _syncFile.delete();
      }
    } catch (_) {}
  }

  CustomerDisplayCartData _snapshotFromCart(CartState cart) {
    final adjustment = cart.paymentAdjustment;
    return CustomerDisplayCartData(
      itemCount: cart.itemCount,
      total: cart.total,
      payableTotal: cart.payableTotal,
      discountTotal: adjustment?.totalDiscount ?? 0,
      hasDiscount: adjustment?.hasDiscount ?? false,
      orderTypeSelected: cart.activeOrderTypeIndex >= 0,
      activeOrderTypeIndex: cart.activeOrderTypeIndex,
      lines: cart.sortedLines
          .map(
            (line) => CustomerDisplayLineData(
              lineKey: line.lineKey,
              name: line.displayName,
              quantity: line.quantity,
              lineTotal: line.lineTotal,
            ),
          )
          .toList(growable: false),
    );
  }

  CustomerDisplayCartAddPulse? _detectCartAddPulse(CartState cart) {
    final prev = _lastCartForPulse;
    _lastCartForPulse = cart;
    if (prev == null) return null;

    for (final line in cart.sortedLines) {
      final prevLine = prev.lines[line.lineKey];
      if (prevLine == null || line.quantity > prevLine.quantity) {
        return CustomerDisplayCartAddPulse(
          seq: ++_cartAddSeq,
          name: line.displayName,
          imagePath: line.item.imagePath,
        );
      }
    }
    return null;
  }

  Future<void> _notifyCustomerDisplaySync() async {
    final window = _window;
    if (window == null || !_sessionActive) return;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await DesktopMultiWindow.invokeMethod(
          window.windowId,
          'customer_display.reload',
        );
        return;
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
        }
      }
    }
  }

  Future<void> _schedulePersist({
    required CartState cart,
    required CustomerDisplayMenuSnapshot? menuSnapshot,
    required CustomerDisplayViewMode viewMode,
  }) {
    _pendingCart = cart;
    if (menuSnapshot != null) {
      _menuSnapshot = menuSnapshot;
      _pendingMenuSnapshot = menuSnapshot;
    } else {
      _pendingMenuSnapshot = _menuSnapshot;
    }
    _pendingViewMode = viewMode;
    if (_flushScheduled) {
      return _scheduledFlushFuture ?? Future<void>.value();
    }
    _flushScheduled = true;
    final completer = Completer<void>();
    _scheduledFlushFuture = completer.future;
    scheduleMicrotask(() async {
      _flushScheduled = false;
      final pendingCart = _pendingCart;
      final pendingMenu = _pendingMenuSnapshot;
      final pendingMode = _pendingViewMode;
      _pendingCart = null;
      _pendingMenuSnapshot = null;
      _pendingViewMode = null;
      if (pendingCart == null || pendingMode == null) {
        completer.complete();
        _scheduledFlushFuture = null;
        return;
      }
      try {
        await _enqueuePersist(
          cart: pendingCart,
          menuSnapshot: pendingMenu,
          viewMode: pendingMode,
        );
        completer.complete();
      } catch (e, stack) {
        debugPrint('CustomerDisplayWindowService._schedulePersist: $e\n$stack');
        completer.completeError(e, stack);
      } finally {
        _scheduledFlushFuture = null;
      }
    });
    return completer.future;
  }

  Future<void> _enqueuePersist({
    required CartState cart,
    required CustomerDisplayMenuSnapshot? menuSnapshot,
    required CustomerDisplayViewMode viewMode,
  }) {
    final next = _persistChain.then(
      (_) => _writeSyncPayload(
        cart: cart,
        menuSnapshot: menuSnapshot,
        viewMode: viewMode,
      ),
    );
    _persistChain = next.catchError((Object e, StackTrace stack) {
      debugPrint('CustomerDisplayWindowService._enqueuePersist: $e\n$stack');
    });
    return next;
  }

  Future<void> _saveCartToFile(CartState cart) async {
    _lastSyncedCart = cart;
    await _schedulePersist(
      cart: cart,
      menuSnapshot: _menuSnapshot,
      viewMode: _viewMode,
    );
  }

  Future<void> _writeSyncPayload({
    required CartState cart,
    required CustomerDisplayMenuSnapshot? menuSnapshot,
    required CustomerDisplayViewMode viewMode,
  }) async {
    try {
      _lastSyncedCart = cart;
      await _ensureSyncDirectory();
      final cartAddPulse = _detectCartAddPulse(cart);
      final revision = ++_syncRevision;
      final payload = {
        'syncRevision': revision,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'apiOrigin': AppConfig.apiOrigin,
        'viewMode': viewMode.name,
        'theme': _themePayload(),
        'cart': (_explicitCartSnapshot ?? _snapshotFromCart(cart)).toJson(),
        'menu': menuSnapshot?.toJson(),
        'displayConfig': _displayContentConfig?.toJson(),
        if (cartAddPulse != null) 'cartAddPulse': cartAddPulse.toJson(),
      };
      final encoded = jsonEncode(payload);
      final tempPath =
          '${_syncFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp';
      final tempFile = File(tempPath);
      try {
        await tempFile.writeAsString(encoded, flush: true);
        if (await _syncFile.exists()) {
          await _syncFile.delete();
        }
        await tempFile.rename(_syncFile.path);
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }
      if (revision == _syncRevision) {
        await _notifyCustomerDisplaySync();
      }
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowService._writeSyncPayload: $e\n$stack');
    }
  }
}
