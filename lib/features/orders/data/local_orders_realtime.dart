import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_digitial_menu/core/app_file_logger.dart';

class LocalOrdersRealtimeEvent {
  const LocalOrdersRealtimeEvent({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;
}

/// Один WS на процесс `dk_pos` (касса + сборщик + кухня в одном приложении).
/// Сервер шлёт все события branch всем clientType — multiplex на клиенте.
class LocalOrdersRealtime {
  LocalOrdersRealtime._();

  static final LocalOrdersRealtime instance = LocalOrdersRealtime._();

  /// Совместимость: всегда shared instance (не открывать второй сокет).
  factory LocalOrdersRealtime() => instance;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  final _controller = StreamController<LocalOrdersRealtimeEvent>.broadcast();
  int _refs = 0;
  String? _branchId;

  Stream<LocalOrdersRealtimeEvent> get events => _controller.stream;
  bool get isConnected => _channel != null;
  int get refCount => _refs;

  /// Экран открылся: +1 ref, connect при необходимости.
  Future<void> acquire({
    required String branchId,
    String clientType = 'app',
  }) async {
    _refs += 1;
    await ensureConnected(branchId: branchId, clientType: clientType);
  }

  /// Экран закрылся: −1 ref, disconnect только когда refs == 0.
  Future<void> release() async {
    _refs = math.max(0, _refs - 1);
    if (_refs == 0) {
      await disconnect();
    }
  }

  /// Подключить / переподключить без изменения refcount (reconnect path).
  Future<void> connect({
    required String branchId,
    String clientType = 'app',
  }) =>
      ensureConnected(branchId: branchId, clientType: clientType);

  Future<void> ensureConnected({
    required String branchId,
    String clientType = 'app',
  }) async {
    final bid = branchId.trim();
    if (bid.isEmpty) return;
    if (_channel != null && _branchId == bid) return;
    await _openSocket(branchId: bid, clientType: clientType);
  }

  Future<void> _openSocket({
    required String branchId,
    required String clientType,
  }) async {
    await _closeSocket();
    final wsUri = _buildWsUri(branchId: branchId, clientType: clientType);
    _branchId = branchId;
    _channel = WebSocketChannel.connect(wsUri);
    _sub = _channel!.stream.listen(
      (raw) {
        if (_controller.isClosed) return;
        final event = _tryParse(raw);
        if (event != null) {
          _controller.add(event);
        }
      },
      onError: (error, stack) {
        if (_controller.isClosed) return;
        AppFileLogger.instance.error('orders_ws', 'stream error', error, stack);
        _controller.addError(error, stack);
      },
      onDone: () {
        _channel = null;
        _branchId = null;
        _pingTimer?.cancel();
        _pingTimer = null;
        if (!_controller.isClosed) {
          AppFileLogger.instance.warn('orders_ws', 'socket closed');
          _controller.add(
            const LocalOrdersRealtimeEvent(
              type: 'socket.done',
              payload: {},
            ),
          );
        }
      },
      cancelOnError: false,
    );
    _startPing();
  }

  void _startPing() {
    _pingTimer?.cancel();
    // 30 с: меньше трафика на Wi‑Fi при нескольких экранах (один сокет).
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel == null) return;
      try {
        _channel!.sink.add('{"type":"ping"}');
      } catch (_) {}
    });
  }

  Future<void> _closeSocket() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _branchId = null;
  }

  /// Принудительно закрыть сокет (не трогает refs). Для тестов/логаута осторожно.
  Future<void> disconnect() => _closeSocket();

  /// Эквивалент [release] для старых вызовов dispose в State.
  Future<void> dispose() => release();

  Uri _buildWsUri({
    required String branchId,
    required String clientType,
  }) {
    final base = Uri.parse(AppConfig.apiOrigin);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : (scheme == 'wss' ? 443 : 80),
      path: '/ws/local',
      queryParameters: {
        'branchId': branchId,
        'clientType': clientType,
      },
    );
  }

  LocalOrdersRealtimeEvent? _tryParse(dynamic raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type']?.toString() ?? '';
      if (type.isEmpty) return null;
      return LocalOrdersRealtimeEvent(type: type, payload: decoded);
    } catch (_) {
      return null;
    }
  }
}
