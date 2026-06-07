import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_server_endpoint_editor.dart';

/// Админка: IP backend на кассе и на сервере (install_local.json для ТВ).
class AdminServerNetworkSection extends StatelessWidget {
  const AdminServerNetworkSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final http = context.read<HttpClient>();
    final dioClient = http is DioHttpClient ? http : null;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.lan_rounded, color: scheme.primary),
        title: Text(
          'Адрес сервера в сети (Wi‑Fi)',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Касса, экран клиента, ТВ и планшеты — один IP после смены роутера',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        children: [
          PosServerEndpointEditor(
            compact: true,
            allowSaveOnServer: dioClient != null,
            httpClient: dioClient,
          ),
        ],
      ),
    );
  }
}
