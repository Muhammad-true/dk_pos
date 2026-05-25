import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/shifts/presentation/shift_close_guard.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/shared/extensions/user_role_l10n.dart';
import 'package:dk_pos/theme/pos_workspace_theme.dart';

/// Экран для роли staff: учёт смены без кассы и заказов.
@RoutePage()
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final role = context.read<AuthBloc>().state.user?.role ?? '';
    final ok = await confirmLogoutWithShiftChecks(context, role: role);
    if (!ok || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final theme = Theme.of(context);
    final user = context.watch<AuthBloc>().state.user;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.staffScreenTitle),
        actions: [
          const PosThemeToggleIconButton(),
          TextButton.icon(
            onPressed: () => _logout(context),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user?.username ?? '—',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.roleLabel(l10n),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      l10n.staffShiftOpenHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.staffShiftCloseHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
