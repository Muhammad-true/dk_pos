import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/features/cart/bloc/cart_state.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_customer_display_panel.dart';

class CustomerDisplayWindowService {
  CustomerDisplayWindowService._();

  static final CustomerDisplayWindowService instance =
      CustomerDisplayWindowService._();

  WindowController? _window;
  bool _singleDisplayPreviewMode = false;
  /// Синхронизация с файлом / вторым окном только после явного «Экран для клиента».
  bool _sessionActive = false;
  CustomerDisplayContentConfig? _displayContentConfig;
  final File _syncFile = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}dk_pos_customer_display${Platform.pathSeparator}cart.json',
  );

  bool get _isSupported => Platform.isWindows;

  Future<bool> hasSecondaryDisplay() async {
    if (!_isSupported) return false;
    try {
      final displays = await screenRetriever.getAllDisplays();
      return displays.length > 1;
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowService.hasSecondaryDisplay: $e\n$stack');
      return false;
    }
  }

  Future<void> _ensureSyncDirectory() async {
    await _syncFile.parent.create(recursive: true);
  }

  Future<bool> ensureOpened({bool allowSingleDisplayPreview = false}) async {
    if (!_isSupported) return false;
    if (AppConfig.isCustomerDisplayWindowDisabled) {
      await close();
      return false;
    }
    try {
      await _ensureSyncDirectory();
      List<dynamic> displays;
      dynamic primaryDisplay;
      try {
        displays = await screenRetriever.getAllDisplays();
        primaryDisplay = await screenRetriever.getPrimaryDisplay();
      } catch (e, stack) {
        debugPrint('CustomerDisplayWindowService screen_retriever: $e\n$stack');
        displays = const [];
        primaryDisplay = null;
      }
      if (displays.length < 2) {
        if (!allowSingleDisplayPreview) {
          if (_singleDisplayPreviewMode && _window != null) {
            await _window!.show();
            return true;
          }
          await close();
          return false;
        }
        if (_window != null) {
          _singleDisplayPreviewMode = true;
          await _window!.show();
          return true;
        }
        final payload = {
          'type': 'customer_display',
          'syncFilePath': _syncFile.path,
          'fullscreen': false,
        };
        _window = await DesktopMultiWindow.createWindow(jsonEncode(payload));
        _singleDisplayPreviewMode = true;
        await _window!.setTitle('Customer Display Preview');
        await _window!.center();
        await _window!.show();
        return true;
      }
      if (_window != null) {
        _singleDisplayPreviewMode = false;
        await _window!.show();
        return true;
      }

      dynamic targetDisplay;
      try {
        if (primaryDisplay != null) {
          targetDisplay = displays.cast<dynamic>().firstWhere(
                (display) => display.id != primaryDisplay.id,
                orElse: () => displays[1],
              );
        } else {
          targetDisplay = displays.length > 1 ? displays[1] : displays[0];
        }
      } catch (e, stack) {
        debugPrint('CustomerDisplayWindowService pick display: $e\n$stack');
        targetDisplay = displays.length > 1 ? displays[1] : displays[0];
      }
      final visiblePosition = targetDisplay.visiblePosition as Offset?;
      final visibleSize =
          (targetDisplay.visibleSize ?? targetDisplay.size) as Size;

      final payload = {
        'type': 'customer_display',
        'syncFilePath': _syncFile.path,
        'fullscreen': true,
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
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowService.ensureOpened: $e\n$stack');
      await close();
      return false;
    }
  }

  /// Открыть окно экрана клиента (второй монитор — полноэкранно, один монитор — окно предпросмотра).
  Future<void> openCustomerDisplay(CartState cart) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    await _saveCartToFile(cart);
    final opened = await ensureOpened(allowSingleDisplayPreview: true);
    if (!opened) return;
    _sessionActive = true;
    await _saveCartToFile(cart);
  }

  /// Обновить корзину на уже открытом экране клиента (не открывает окно само).
  Future<void> syncCart(CartState cart) async {
    if (!_isSupported) return;
    if (AppConfig.isCustomerDisplayWindowDisabled) return;
    if (!_sessionActive) return;
    if (_window == null) return;
    await _saveCartToFile(cart);
  }

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
    _sessionActive = false;
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
    return CustomerDisplayCartData(
      itemCount: cart.itemCount,
      total: cart.total,
      lines: cart.sortedLines
          .map(
            (line) => CustomerDisplayLineData(
              name: line.item.name,
              quantity: line.quantity,
              lineTotal: line.lineTotal,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _saveCartToFile(CartState cart) async {
    try {
      await _ensureSyncDirectory();
      final payload = {
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'cart': _snapshotFromCart(cart).toJson(),
        'displayConfig': _displayContentConfig?.toJson(),
      };
      await _syncFile.writeAsString(jsonEncode(payload), flush: true);
    } catch (e, stack) {
      debugPrint('CustomerDisplayWindowService._saveCartToFile: $e\n$stack');
    }
  }
}
