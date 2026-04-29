import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:dk_pos/core/config/app_config.dart';

class LocalOrdersRealtimeEvent {
  const LocalOrdersRealtimeEvent({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;
}

class LocalOrdersRealtime {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<LocalOrdersRealtimeEvent>.broadcast();
  bool _disposed = false;

  Stream<LocalOrdersRealtimeEvent> get events => _controller.stream;

  Future<void> connect({
    required String branchId,
    String clientType = 'kitchen',
  }) async {
    if (_disposed) return;
    await disconnect();
    final wsUri = _buildWsUri(branchId: branchId, clientType: clientType);
    _channel = WebSocketChannel.connect(wsUri);
    _sub = _channel!.stream.listen(
      (raw) {
        if (_disposed || _controller.isClosed) return;
        final event = _tryParse(raw);
        if (event != null) {
          _controller.add(event);
        }
      },
      onError: (error, stack) {
        if (_disposed || _controller.isClosed) return;
        _controller.addError(error, stack);
      },
      onDone: () {
        if (!_disposed && !_controller.isClosed) {
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
  }

  Future<void> disconnect() async {
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

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
