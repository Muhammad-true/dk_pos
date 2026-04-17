import 'package:auto_route/auto_route.dart';

import 'package:dk_pos/features/admin/presentation/screens/admin_screen.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_state.dart';
import 'package:dk_pos/features/auth/presentation/screens/login_screen.dart';
import 'package:dk_pos/features/expeditor/presentation/screens/expeditor_screen.dart';
import 'package:dk_pos/features/kitchen_board/presentation/screens/kitchen_screen.dart';
import 'package:dk_pos/features/kitchen_board/presentation/screens/queue_board_screen.dart';
import 'package:dk_pos/features/pos/presentation/screens/pos_screen.dart';

part 'app_router.gr.dart';

PageRouteInfo<void> _homeRouteForAuth(AuthState state) {
  final user = state.user;
  if (!state.isAuthenticated || user == null) {
    return const LoginRoute();
  }
  if (user.isAdmin) return const AdminRoute();
  if (user.role == 'warehouse') return const KitchenRoute();
  if (user.role == 'expeditor') return const ExpeditorRoute();
  return const PosRoute();
}

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter({required AuthBloc authBloc})
      : _adminGuard = _AdminOnlyGuard(authBloc),
        _kitchenGuard = _WarehouseOnlyGuard(authBloc),
        _posGuard = _PosAccessGuard(authBloc),
        _expeditorGuard = _ExpeditorAccessGuard(authBloc),
        _authAnyGuard = _AuthenticatedGuard(authBloc),
        _loginGuard = _LoginGateGuard(authBloc),
        super();

  final _AdminOnlyGuard _adminGuard;
  final _WarehouseOnlyGuard _kitchenGuard;
  final _PosAccessGuard _posGuard;
  final _ExpeditorAccessGuard _expeditorGuard;
  final _AuthenticatedGuard _authAnyGuard;
  final _LoginGateGuard _loginGuard;

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: LoginRoute.page,
          path: '/login',
          initial: true,
          guards: [_loginGuard],
        ),
        AutoRoute(page: AdminRoute.page, path: '/admin', guards: [_adminGuard]),
        AutoRoute(
          page: KitchenRoute.page,
          path: '/kitchen',
          guards: [_kitchenGuard],
        ),
        AutoRoute(
          page: QueueBoardRoute.page,
          path: '/queue-board',
          guards: [_authAnyGuard],
        ),
        AutoRoute(
          page: ExpeditorRoute.page,
          path: '/expeditor',
          guards: [_expeditorGuard],
        ),
        AutoRoute(page: PosRoute.page, path: '/pos', guards: [_posGuard]),
      ];
}

class _AdminOnlyGuard extends AutoRouteGuard {
  _AdminOnlyGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (!state.isAuthenticated) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    if (state.user?.isAdmin == true) {
      resolver.next(true);
      return;
    }
    router.replace(_homeRouteForAuth(state));
    resolver.next(false);
  }
}

/// Любой авторизованный пользователь (экран очереди на втором мониторе и т.п.).
class _AuthenticatedGuard extends AutoRouteGuard {
  _AuthenticatedGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (!state.isAuthenticated || state.user == null) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    resolver.next(true);
  }
}

class _WarehouseOnlyGuard extends AutoRouteGuard {
  _WarehouseOnlyGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (!state.isAuthenticated) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    if (state.user?.role == 'warehouse') {
      resolver.next(true);
      return;
    }
    router.replace(_homeRouteForAuth(state));
    resolver.next(false);
  }
}

class _PosAccessGuard extends AutoRouteGuard {
  _PosAccessGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (!state.isAuthenticated) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    final user = state.user;
    if (user == null) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    if (user.role == 'warehouse') {
      router.replace(const KitchenRoute());
      resolver.next(false);
      return;
    }
    if (user.role == 'expeditor') {
      router.replace(const ExpeditorRoute());
      resolver.next(false);
      return;
    }
    if (user.isAdmin) {
      router.replace(const AdminRoute());
      resolver.next(false);
      return;
    }
    resolver.next(true);
  }
}

class _ExpeditorAccessGuard extends AutoRouteGuard {
  _ExpeditorAccessGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (!state.isAuthenticated) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    final user = state.user;
    if (user == null) {
      router.replace(const LoginRoute());
      resolver.next(false);
      return;
    }
    const allowed = {'cashier', 'expeditor', 'admin'};
    if (!allowed.contains(user.role)) {
      router.replace(_homeRouteForAuth(state));
      resolver.next(false);
      return;
    }
    resolver.next(true);
  }
}

class _LoginGateGuard extends AutoRouteGuard {
  _LoginGateGuard(this._authBloc);

  final AuthBloc _authBloc;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final state = _authBloc.state;
    if (state.isAuthenticated && state.user != null) {
      router.replace(_homeRouteForAuth(state));
      resolver.next(false);
      return;
    }
    resolver.next(true);
  }
}
