import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';
import 'package:dk_pos/features/auth/data/local_shift_repository.dart';
import 'package:dk_pos/features/kitchen_board/background/kitchen_background_service.dart';
import 'package:dk_pos/shared/shared.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._repo, {
    LocalShiftRepository? shiftRepo,
    required String branchId,
    String? terminalId,
  }) : _shiftRepo = shiftRepo,
       _branchId = branchId,
       _terminalId = terminalId,
       super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  final AuthRepository _repo;
  final LocalShiftRepository? _shiftRepo;
  final String _branchId;
  final String? _terminalId;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      await _repo.applyTokenFromStorage();
      UserModel? user = await _repo.readCachedUser();

      if (_repo.hasAccessToken) {
        try {
          user = await _repo.fetchMe();
          await _repo.cacheUser(user);
          await _openShiftSafe();
          emit(AuthState(status: AuthStatus.authenticated, user: user));
          return;
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            await KitchenBackgroundService.stopAndroidKitchenService();
            await _repo.clearSession();
            emit(const AuthState(status: AuthStatus.unauthenticated));
            return;
          }
        } catch (_) {}
        if (user != null) {
          emit(AuthState(status: AuthStatus.authenticated, user: user));
          return;
        }
      }

      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          loginError: 'Ошибка при запуске: $e',
        ),
      );
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(status: AuthStatus.authenticating, clearLoginError: true),
    );
    try {
      final (t, u) = await _repo.login(
        username: event.username,
        password: event.password,
      );
      await _repo.persistSession(t, u);
      if (u.role == 'warehouse') {
        await KitchenBackgroundService.initialize();
      } else {
        await KitchenBackgroundService.stopAndroidKitchenService();
      }
      await _openShiftSafe();
      emit(AuthState(status: AuthStatus.authenticated, user: u));
    } on ApiException catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          user: state.user,
          loginError: e.message,
        ),
      );
    } catch (e) {
      emit(
        AuthState(
          status: AuthStatus.unauthenticated,
          user: state.user,
          loginError: e.toString(),
        ),
      );
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _closeShiftSafe();
    await KitchenBackgroundService.stopAndroidKitchenService();
    await _repo.clearSession();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _openShiftSafe() async {
    try {
      await _shiftRepo?.openShift(
        branchId: _branchId,
        terminalId: _terminalId,
      );
    } catch (_) {
      // Смена не должна блокировать вход.
    }
  }

  Future<void> _closeShiftSafe() async {
    try {
      await _shiftRepo
          ?.closeShift(branchId: _branchId)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Смена не должна блокировать выход (сеть/таймаут на телефоне).
    }
  }
}
