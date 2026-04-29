import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';

class CustomerDisplayWindowApp extends StatelessWidget {
  const CustomerDisplayWindowApp({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  final WindowController windowController;
  final Map<String, dynamic> arguments;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE4002B),
          onPrimary: Colors.white,
          secondary: Color(0xFFFFD166),
          onSecondary: Color(0xFF2C1600),
          surface: Color(0xFF111318),
          onSurface: Colors.white,
        ),
      ),
      home: CustomerDisplayWindowScreen(
        windowController: windowController,
        arguments: arguments,
      ),
    );
  }
}

class CustomerDisplayWindowScreen extends StatefulWidget {
  const CustomerDisplayWindowScreen({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  final WindowController windowController;
  final Map<String, dynamic> arguments;

  @override
  State<CustomerDisplayWindowScreen> createState() =>
      _CustomerDisplayWindowScreenState();
}

class _CustomerDisplayWindowScreenState
    extends State<CustomerDisplayWindowScreen> {
  CustomerDisplayCartData _cart = const CustomerDisplayCartData();
  CustomerDisplayContentConfig? _idleContentConfig;
  Timer? _pollTimer;
  int? _lastUpdatedAt;
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
    await _configureWindow();
    if (!mounted) return;
    setState(() => _isFullscreen = _fullscreenMode);
    await _loadCartFromFile();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<dynamic> _handleWindowCall(MethodCall call) async {
    if (call.method == 'window.close') {
      await widget.windowController.close();
      return true;
    }
    return null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _loadCartFromFile();
    });
  }

  Future<void> _loadCartFromFile() async {
    final path = _syncFilePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final updatedAt = (decoded['updatedAt'] as num?)?.toInt() ?? 0;
      if (_lastUpdatedAt == updatedAt) return;
      final cartJson = decoded['cart'];
      if (cartJson is! Map<String, dynamic>) return;
      final displayConfigJson = decoded['displayConfig'];
      if (!mounted) return;
      setState(() {
        _lastUpdatedAt = updatedAt;
        _cart = CustomerDisplayCartData.fromJson(cartJson);
        _idleContentConfig = displayConfigJson is Map<String, dynamic>
            ? CustomerDisplayContentConfig.fromJson(displayConfigJson)
            : null;
      });
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
