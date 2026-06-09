import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'package:dk_pos/core/cache/pos_menu_image_prefetch.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_sync_state.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';
import 'package:dk_pos/theme/app_theme.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

class CustomerDisplayWindowApp extends StatefulWidget {
  const CustomerDisplayWindowApp({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  final WindowController windowController;
  final Map<String, dynamic> arguments;

  @override
  State<CustomerDisplayWindowApp> createState() =>
      _CustomerDisplayWindowAppState();
}

class _CustomerDisplayWindowAppState extends State<CustomerDisplayWindowApp> {
  late CustomerDisplayThemeSnapshot _themeSnapshot;

  @override
  void initState() {
    super.initState();
    final rawTheme = widget.arguments['theme'];
    _themeSnapshot = rawTheme is Map
        ? CustomerDisplayThemeSnapshot.fromJson(
            Map<String, dynamic>.from(rawTheme),
          )
        : const CustomerDisplayThemeSnapshot();
  }

  void _onThemeChanged(CustomerDisplayThemeSnapshot next) {
    if (_themeSnapshot.mode == next.mode &&
        _themeSnapshot.accentColor.toARGB32() == next.accentColor.toARGB32()) {
      return;
    }
    setState(() => _themeSnapshot = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = buildPosWorkspaceTheme(
      buildAppTheme(),
      _themeSnapshot.mode,
      _themeSnapshot.accentColor,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: CustomerDisplayWindowScreen(
        windowController: widget.windowController,
        arguments: widget.arguments,
        onThemeChanged: _onThemeChanged,
      ),
    );
  }
}

class CustomerDisplayWindowScreen extends StatefulWidget {
  const CustomerDisplayWindowScreen({
    super.key,
    required this.windowController,
    required this.arguments,
    this.onThemeChanged,
  });

  final WindowController windowController;
  final Map<String, dynamic> arguments;
  final ValueChanged<CustomerDisplayThemeSnapshot>? onThemeChanged;

  @override
  State<CustomerDisplayWindowScreen> createState() =>
      _CustomerDisplayWindowScreenState();
}

class _CustomerDisplayWindowScreenState
    extends State<CustomerDisplayWindowScreen> {
  CustomerDisplayCartData _cart = const CustomerDisplayCartData();
  CustomerDisplayContentConfig? _idleContentConfig;
  CustomerDisplayViewMode _viewMode = CustomerDisplayViewMode.idle;
  CustomerDisplayMenuSnapshot? _menu;
  CustomerDisplayCartAddPulse? _cartAddPulse;
  Timer? _pollTimer;
  StreamSubscription<FileSystemEvent>? _fileWatchSub;
  int? _lastUpdatedAt;
  int _lastSyncRevision = 0;
  bool _isFullscreen = false;
  bool _windowConfigured = false;

  String? get _syncFilePath => widget.arguments['syncFilePath']?.toString();
  bool get _fullscreenMode => widget.arguments['fullscreen'] == true;

  Rect? _secondaryBoundsFromArgs() {
    final raw = widget.arguments['bounds'];
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final x = (m['x'] as num?)?.toDouble();
    final y = (m['y'] as num?)?.toDouble();
    final w = (m['width'] as num?)?.toDouble();
    final h = (m['height'] as num?)?.toDouble();
    if (x == null || y == null || w == null || h == null) return null;
    if (w <= 1 || h <= 1) return null;
    return Rect.fromLTWH(x, y, w, h);
  }

  @override
  void initState() {
    super.initState();
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) {
      return _handleWindowCall(call);
    });
    Future.microtask(_bootstrapCustomerDisplayWindow);
  }

  Future<void> _bootstrapCustomerDisplayWindow() async {
    _applyApiOriginFromLaunchArgs();
    await _configureWindow();
    if (!mounted) return;
    setState(() => _isFullscreen = _fullscreenMode);
    await _loadCartFromFile();
    _startFileWatch();
    _startPolling();
  }

  void _applyApiOriginFromLaunchArgs() {
    final fromArgs = widget.arguments['apiOrigin']?.toString().trim();
    if (fromArgs != null && fromArgs.isNotEmpty) {
      AppConfig.setApiOriginOverride(fromArgs);
    }
  }

  void _applyApiOriginFromSync(Map<String, dynamic> decoded) {
    final origin = decoded['apiOrigin']?.toString().trim();
    if (origin == null || origin.isEmpty) return;
    AppConfig.setApiOriginOverride(origin);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_fileWatchSub?.cancel());
    _fileWatchSub = null;
    super.dispose();
  }

  void _startFileWatch() {
    final path = _syncFilePath;
    if (path == null || path.isEmpty) return;
    try {
      _fileWatchSub?.cancel();
      _fileWatchSub = File(path).watch().listen((event) {
        if (event.type == FileSystemEvent.modify ||
            event.type == FileSystemEvent.create) {
          unawaited(_loadCartFromFile());
        }
      });
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowScreen._startFileWatch: $e\n$stack');
    }
  }

  Future<dynamic> _handleWindowCall(MethodCall call) async {
    if (call.method == 'window.close') {
      await widget.windowController.close();
      return true;
    }
    if (call.method == 'customer_display.reload') {
      await _loadCartFromFile(force: true);
      return true;
    }
    return null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _loadCartFromFile();
    });
  }

  Future<void> _loadCartFromFile({bool force = false}) async {
    final path = _syncFilePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _applyApiOriginFromSync(decoded);
      final updatedAt = (decoded['updatedAt'] as num?)?.toInt() ?? 0;
      final syncRevision = (decoded['syncRevision'] as num?)?.toInt() ?? 0;
      if (!force &&
          syncRevision > 0 &&
          syncRevision <= _lastSyncRevision) {
        return;
      }
      if (!force &&
          syncRevision <= 0 &&
          _lastUpdatedAt == updatedAt) {
        return;
      }
      final cartJson = decoded['cart'];
      final cart = cartJson is Map<String, dynamic>
          ? CustomerDisplayCartData.fromJson(cartJson)
          : (cartJson is Map
              ? CustomerDisplayCartData.fromJson(
                  Map<String, dynamic>.from(cartJson),
                )
              : const CustomerDisplayCartData());
      final displayConfigJson = decoded['displayConfig'];
      final menuJson = decoded['menu'];
      final themeJson = decoded['theme'];
      if (!mounted) return;
      if (themeJson is Map) {
        widget.onThemeChanged?.call(
          CustomerDisplayThemeSnapshot.fromJson(
            Map<String, dynamic>.from(themeJson),
          ),
        );
      }
      final pulseJson = decoded['cartAddPulse'];
      final nextPulse = pulseJson is Map<String, dynamic>
          ? CustomerDisplayCartAddPulse.fromJson(pulseJson)
          : (pulseJson is Map
              ? CustomerDisplayCartAddPulse.fromJson(
                  Map<String, dynamic>.from(pulseJson),
                )
              : null);

      final nextMenu = menuJson is Map<String, dynamic>
          ? CustomerDisplayMenuSnapshot.fromJson(menuJson)
          : (menuJson is Map
              ? CustomerDisplayMenuSnapshot.fromJson(
                  Map<String, dynamic>.from(menuJson),
                )
              : null);
      setState(() {
        _lastUpdatedAt = updatedAt;
        if (syncRevision > 0) {
          _lastSyncRevision = syncRevision;
        }
        _cart = cart;
        _viewMode = parseCustomerDisplayViewMode(decoded['viewMode']?.toString());
        _menu = nextMenu;
        _idleContentConfig = displayConfigJson is Map<String, dynamic>
            ? CustomerDisplayContentConfig.fromJson(displayConfigJson)
            : null;
        if (nextPulse != null && nextPulse.seq > 0) {
          _cartAddPulse = nextPulse;
        }
      });
      if (nextMenu != null && nextMenu.products.isNotEmpty) {
        unawaited(prefetchCustomerDisplayProducts(nextMenu.products));
      }
    } catch (_) {
      // Игнорируем частично записанный файл и пробуем снова на следующем тике.
    }
  }

  Future<void> _configureWindow() async {
    try {
      await windowManager.ensureInitialized();
      final secondaryBounds = _secondaryBoundsFromArgs();
      final options = WindowOptions(
        title: 'Customer Display',
        backgroundColor: Colors.black,
        titleBarStyle: TitleBarStyle.hidden,
        skipTaskbar: true,
        fullScreen: _fullscreenMode,
        alwaysOnTop: false,
      );
      await windowManager.waitUntilReadyToShow(options, () async {
        if (secondaryBounds != null) {
          try {
            await windowManager.setBounds(secondaryBounds);
          } catch (e, stack) {
            debugPrint(
              'CustomerDisplayWindowScreen.setBounds(secondary): $e\n$stack',
            );
          }
        }
        await windowManager.show();
        await windowManager.setResizable(!_fullscreenMode);
        if (_fullscreenMode) {
          await windowManager.setFullScreen(true);
        } else {
          await windowManager.focus();
        }
      });
      _windowConfigured = true;
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowScreen._configureWindow: $e\n$stack');
      _windowConfigured = true;
    }
  }

  Future<void> _enterFullscreen() async {
    await windowManager.setResizable(false);
    await windowManager.setFullScreen(true);
    if (!mounted) return;
    setState(() => _isFullscreen = true);
  }

  Future<void> _exitFullscreen() async {
    await windowManager.setFullScreen(false);
    await windowManager.setResizable(true);
    await windowManager.focus();
    if (!mounted) return;
    setState(() => _isFullscreen = false);
  }

  @override
  Widget build(BuildContext context) {
    final canDragWindow = _windowConfigured && !_isFullscreen;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PosCustomerDisplayPanel(
              cart: _cart,
              idleContentConfig: _idleContentConfig,
              viewMode: _viewMode,
              menu: _menu,
              cartAddPulse: _cartAddPulse,
              syncFilePath: _syncFilePath,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              child: _CustomerDisplayWindowToolbar(
                isFullscreen: _isFullscreen,
                canDragWindow: canDragWindow,
                onEnterFullscreen: _enterFullscreen,
                onExitFullscreen: _exitFullscreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDisplayWindowToolbar extends StatelessWidget {
  const _CustomerDisplayWindowToolbar({
    required this.isFullscreen,
    required this.canDragWindow,
    required this.onEnterFullscreen,
    required this.onExitFullscreen,
  });

  final bool isFullscreen;
  final bool canDragWindow;
  final Future<void> Function() onEnterFullscreen;
  final Future<void> Function() onExitFullscreen;

  @override
  Widget build(BuildContext context) {
    Widget leftArea = const SizedBox(
      height: 56,
      child: DecoratedBox(decoration: BoxDecoration(color: Colors.transparent)),
    );

    if (canDragWindow) {
      leftArea = DragToMoveArea(child: leftArea);
    }

    return Row(
      children: [
        Expanded(child: leftArea),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: isFullscreen ? onExitFullscreen : onEnterFullscreen,
          child: Container(width: 170, height: 56, color: Colors.transparent),
        ),
      ],
    );
  }
}

Map<String, dynamic> parseCustomerDisplayArguments(String raw) {
  if (raw.trim().isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return const {};
}
