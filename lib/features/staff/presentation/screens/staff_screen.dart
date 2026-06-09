import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/app/pos_theme/pos_theme_toggle_button.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
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
    final ok = await confirmSettingsPanelLogout(context);
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = WindowLayout(width: constraints.maxWidth);
              final maxCardWidth = layout.isCompact
                  ? 420.0
                  : layout.isMedium
                      ? 520.0
                      : 640.0;
              final cols = layout.hubGridColumns(minCellWidth: 300);

              Widget profileCard = _StaffInfoCard(
                icon: Icons.badge_outlined,
                iconColor: theme.colorScheme.primary,
                title: user?.username ?? '—',
                subtitle: user?.roleLabel(l10n),
              );

              Widget shiftCard = _StaffInfoCard(
                icon: Icons.schedule_rounded,
                iconColor: theme.colorScheme.tertiary,
                title: l10n.staffShiftOpenHint,
                subtitle: l10n.staffShiftCloseHint,
                bodyStyle: theme.textTheme.bodyMedium,
              );

              if (cols <= 1) {
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxCardWidth),
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
                );
              }

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth * cols + 24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: GridView.count(
                      crossAxisCount: cols.clamp(2, 2),
                      shrinkWrap: true,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.05,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [profileCard, shiftCard],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StaffInfoCard extends StatelessWidget {
  const _StaffInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.bodyStyle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: bodyStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
