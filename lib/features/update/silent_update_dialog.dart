import 'package:flutter/material.dart';

import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/update/silent_update_result.dart';
import 'package:dk_pos/features/update/silent_update_service.dart';

/// Диалог с прогрессом скачивания и запуском тихой установки.
Future<SilentUpdateResult?> showSilentUpdateDialog({
  required BuildContext context,
  required String appKey,
  required String downloadUrl,
  HttpClient? http,
}) async {
  return showDialog<SilentUpdateResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SilentUpdateDialog(
      appKey: appKey,
      downloadUrl: downloadUrl,
      http: http,
    ),
  );
}

class _SilentUpdateDialog extends StatefulWidget {
  const _SilentUpdateDialog({
    required this.appKey,
    required this.downloadUrl,
    this.http,
  });

  final String appKey;
  final String downloadUrl;
  final HttpClient? http;

  @override
  State<_SilentUpdateDialog> createState() => _SilentUpdateDialogState();
}

class _SilentUpdateDialogState extends State<_SilentUpdateDialog> {
  final _service = SilentUpdateService();
  String _status = 'Подготовка…';
  double? _progress;
  SilentUpdateResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final isServer = widget.appKey.trim().toLowerCase() == 'server';
      setState(
        () => _status = isServer
            ? 'Запуск тихой установки backend на сервере…'
            : 'Скачивание…',
      );
      final result = await _service.silentInstallAppKey(
        appKey: widget.appKey,
        downloadUrl: widget.downloadUrl,
        http: widget.http,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            if (total != null && total > 0) {
              _progress = received / total;
            }
            _status = 'Скачивание… ${(received / 1024 / 1024).toStringAsFixed(1)} МБ';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = SilentUpdateResult(ok: false, message: e.toString());
        _status = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _result != null;
    return AlertDialog(
      title: const Text('Тихое обновление'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_status),
          if (_progress != null && !done) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      actions: [
        if (done)
          FilledButton(
            onPressed: () => Navigator.pop(context, _result),
            child: const Text('OK'),
          ),
      ],
    );
  }
}
