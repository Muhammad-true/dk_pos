import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dk_pos/core/cache/pos_local_cache_cleanup.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_applier.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/features/license/local_setup_api.dart';
/// Смена IP/URL backend: настройки кассы и админка.
class PosServerEndpointEditor extends StatefulWidget {
  const PosServerEndpointEditor({
    super.key,
    this.compact = false,
    this.allowSaveOnServer = false,
    this.httpClient,
    this.onApplied,
  });

  /// Узкий блок в диалоге «Настройки POS».
  final bool compact;

  /// Запись в config/install_local.json на сервере (только админ).
  final bool allowSaveOnServer;

  final DioHttpClient? httpClient;
  final VoidCallback? onApplied;

  @override
  State<PosServerEndpointEditor> createState() => _PosServerEndpointEditorState();
}

class _PosServerEndpointEditorState extends State<PosServerEndpointEditor> {
  final _controller = TextEditingController();
  bool _saveOnServer = true;
  bool _busy = false;
  String? _error;
  String? _hintLan;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final saved = await ServerEndpointStore.read();
    final origin = (saved != null && saved.isNotEmpty)
        ? saved
        : AppConfig.apiOrigin;
    final host = Uri.tryParse(origin)?.host;
    if (!mounted) return;
    setState(() {
      _controller.text = host ?? origin;
    });
    _fetchServerHint();
  }

  Future<void> _fetchServerHint() async {
    try {
      final setup = await LocalSetupApi(createDio()).fetchNetwork();
      if (!mounted) return;
      setState(() {
        _hintLan = setup.lanIpv4;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fillFromServer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await LocalSetupApi(createDio()).fetchNetwork();
      final suggested = setup.apiBaseUrlSuggested?.trim();
      final lan = setup.lanIpv4?.trim();
      final raw = suggested ?? (lan != null ? 'http://$lan:3000' : '');
      if (raw.isEmpty) {
        setState(() => _error = 'Сервер не вернул LAN IP');
        return;
      }
      final host = Uri.tryParse(
        AppConfig.normalizeServerConnectionInput(raw),
      )?.host;
      setState(() {
        _controller.text = host ?? raw;
        _hintLan = lan;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ServerEndpointApplier.apply(
        _controller.text,
        saveOnServer: widget.allowSaveOnServer && _saveOnServer,
        dioForServerSave:
            widget.httpClient?.dio ?? createDio(),
      );
      if (!result.ok) {
        setState(() => _error = result.message);
        return;
      }
      ServerEndpointApplier.refreshBoundHttpClient(widget.httpClient);
      await clearPosLocalCaches();
      if (!mounted) return;
      widget.onApplied?.call();
      final msg = result.message ??
          'Сохранено: ${result.normalizedOrigin}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg Обновите экран клиента, если он открыт.')),
      );
      setState(() {
        _controller.text =
            Uri.tryParse(result.normalizedOrigin)?.host ??
            result.normalizedOrigin;
      });
    } catch (e) {
      setState(
        () => _error = ServerEndpointApplier.formatConnectionError(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = AppConfig.apiOrigin;

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _fields(context, theme, scheme, current),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _fields(context, theme, scheme, current),
        ),
      ),
    );
  }

  List<Widget> _fields(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    String current,
  ) {
    return [
      Text(
        'Адрес сервера API',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Сейчас: $current'
        '${_hintLan != null ? '\nIP этого ПК в сети (с сервера): $_hintLan' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _controller,
        enabled: !_busy,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: const InputDecoration(
          labelText: 'IP или URL',
          hintText: '192.168.1.100',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.dns_rounded),
        ),
      ),
      if (widget.allowSaveOnServer) ...[
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _saveOnServer,
          onChanged: _busy
              ? null
              : (v) => setState(() => _saveOnServer = v ?? true),
          title: const Text('Сохранить на сервере кассы'),
          subtitle: const Text(
            'Файл install_local.json — подсказка для ТВ и других планшетов в Wi‑Fi',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
      ],
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _fillFromServer,
            icon: const Icon(Icons.router_rounded, size: 18),
            label: const Text('Подставить с сервера'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text('Сохранить'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'После смены Wi‑Fi нажмите «Подставить с сервера» или введите IP из ipconfig. '
        'Затем обновите экран клиента (иконка синхронизации у ТВ).',
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    ];
  }
}
