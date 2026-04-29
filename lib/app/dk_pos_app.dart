import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_route/auto_route.dart';
import 'package:dk_pos/app/app_locale_scope.dart';
import 'package:dk_pos/app/app_update_info.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/router/app_router.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/data/local_shift_repository.dart';
import 'package:dk_pos/features/auth/bloc/auth_state.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/bloc/cart_event.dart';
import 'package:dk_pos/theme/theme.dart';

/// Корень UI: тема, локализация, роутер, синхронизация с [AuthBloc].
class DkPosApp extends StatelessWidget {
  const DkPosApp({
    super.key,
    required this.router,
    this.startupUpdate,
  });

  final AppRouter router;
  final AppUpdateInfo? startupUpdate;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleBloc>().state.locale;
    final materialLocale =
        locale.languageCode == 'tg' ? const Locale('ru') : locale;
    final baseLight = buildAppTheme();

    return AppLocaleScope(
      locale: locale,
      child: BlocBuilder<PosThemeCubit, PosThemeSettings>(
        builder: (context, themeSettings) {
          return MaterialApp.router(
            onGenerateTitle: (ctx) => ctx.appL10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: buildPosWorkspaceTheme(
              baseLight,
              themeSettings.mode,
              themeSettings.accentColor,
            ),
            locale: materialLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router.config(),
            builder: (context, child) {
              return _ShiftLifecycleSync(
                child: _StartupUpdateNotice(
                  updateInfo: startupUpdate,
                  child: _RouterAuthSync(
                    router: router,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShiftLifecycleSync extends StatefulWidget {
  const _ShiftLifecycleSync({required this.child});

  final Widget child;

  @override
  State<_ShiftLifecycleSync> createState() => _ShiftLifecycleSyncState();
}

class _ShiftLifecycleSyncState extends State<_ShiftLifecycleSync>
    with WidgetsBindingObserver {
  DateTime? _lastCloseAttemptAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      _closeShiftBestEffort();
    }
  }

  void _closeShiftBestEffort() {
    final now = DateTime.now();
    final prev = _lastCloseAttemptAt;
    if (prev != null && now.difference(prev).inSeconds < 5) {
      return;
    }
    _lastCloseAttemptAt = now;
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) return;
    final repo = context.read<LocalShiftRepository>();
    // ignore: discarded_futures
    repo.closeShift().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _StartupUpdateNotice extends StatefulWidget {
  const _StartupUpdateNotice({
    required this.updateInfo,
    required this.child,
  });

  final AppUpdateInfo? updateInfo;
  final Widget child;

  @override
  State<_StartupUpdateNotice> createState() => _StartupUpdateNoticeState();
}

class _StartupUpdateNoticeState extends State<_StartupUpdateNotice> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    if (!_shown && info != null && info.shouldNotify && !info.requiresBlock) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Доступно обновление'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${info.displayName}: ${info.installedVersion} -> ${info.targetVersion ?? "новая версия"}',
                ),
                if ((info.releaseNotes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(info.releaseNotes!),
                ],
                if ((info.downloadUrl ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(info.downloadUrl!),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Позже'),
              ),
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: info.downloadUrl ?? ''),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Скопировать ссылку'),
              ),
            ],
          ),
        );
      });
    }
    return widget.child;
  }
}

class _RouterAuthSync extends StatefulWidget {
  const _RouterAuthSync({required this.router, required this.child});

  final AppRouter router;
  final Widget child;

  @override
  State<_RouterAuthSync> createState() => _RouterAuthSyncState();
}

class _RouterAuthSyncState extends State<_RouterAuthSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(context.read<AuthBloc>().state);
    });
  }

  void _sync(AuthState state) {
    if (!state.isReady || !mounted) return;
    if (state.isAuthenticated) {
      final user = state.user;
      late final PageRouteInfo<void> targetRoute;
      if (user != null && user.isAdmin) {
        targetRoute = const AdminRoute();
      } else if (user != null && user.role == 'warehouse') {
        targetRoute = const KitchenRoute();
      } else if (user != null && user.role == 'expeditor') {
        targetRoute = const ExpeditorRoute();
      } else {
        targetRoute = const PosRoute();
      }
      // При входе/смене роли полностью сбрасываем стек, чтобы не было перехода "назад" в чужой интерфейс.
      widget.router.replaceAll([targetRoute]);
    } else {
      // Полный сброс сессионных данных UI при выходе.
      context.read<CartBloc>().add(const CartResetAll());
      widget.router.replaceAll([const LoginRoute()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          prev.isAuthenticated != curr.isAuthenticated ||
          prev.status != curr.status ||
          (curr.isAuthenticated &&
              prev.user?.role != curr.user?.role),
      listener: (context, state) => _sync(state),
      child: widget.child,
    );
  }
}
