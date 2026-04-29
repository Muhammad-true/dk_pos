import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/expeditor/presentation/widgets/expeditor_queue_panel.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

@RoutePage()
class ExpeditorScreen extends StatefulWidget {
  const ExpeditorScreen({super.key});

  @override
  State<ExpeditorScreen> createState() => _ExpeditorScreenState();
}

class _ExpeditorScreenState extends State<ExpeditorScreen> {
  final _panelKey = GlobalKey<ExpeditorQueuePanelState>();

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.expeditorTitle),
        actions: [
          const PosThemeToggleIconButton(),
          IconButton(
            tooltip: l10n.actionRefreshMenu,
            onPressed: () => _panelKey.currentState?.reloadFromAppBar(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.actionExit),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
                       colors: posWorkspaceBodyGradient(theme),
          ),
        ),
        child: ExpeditorQueuePanel(
          key: _panelKey,
          embedded: false,
        ),
      ),
    );
  }
}
