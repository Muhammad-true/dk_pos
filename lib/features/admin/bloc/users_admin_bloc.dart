import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/users_admin_repository.dart';

import 'users_admin_event.dart';
import 'users_admin_state.dart';

class UsersAdminBloc extends Bloc<UsersAdminEvent, UsersAdminState> {
  UsersAdminBloc(this._repo) : super(const UsersAdminState()) {
    on<UsersLoadRequested>(_onLoad);
    on<UserCreateSubmitted>(_onCreate);
    on<UserUpdateSubmitted>(_onUpdate);
    on<UserDeleteSubmitted>(_onDelete);
    on<UsersErrorDismissed>(_onDismissError);
  }

  final UsersAdminRepository _repo;

  Future<void> _onLoad(
    UsersLoadRequested event,
    Emitter<UsersAdminState> emit,
  ) async {
    emit(state.copyWith(status: UsersAdminStatus.loading, clearError: true));
    try {
      final list = await _repo.fetchUsers();
      emit(UsersAdminState(status: UsersAdminStatus.loaded, users: list));
    } on ApiException catch (e) {
      emit(
        UsersAdminState(
          status: UsersAdminStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        UsersAdminState(
          status: UsersAdminStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreate(
    UserCreateSubmitted event,
    Emitter<UsersAdminState> emit,
  ) async {
    if (state.status != UsersAdminStatus.loaded) return;
    emit(state.copyWith(status: UsersAdminStatus.loading, clearError: true));
    try {
      await _repo.createUser(
        username: event.username,
        password: event.password,
        role: event.role,
        kitchenStationId: event.kitchenStationId,
      );
      final list = await _repo.fetchUsers();
      emit(UsersAdminState(status: UsersAdminStatus.loaded, users: list));
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdate(
    UserUpdateSubmitted event,
    Emitter<UsersAdminState> emit,
  ) async {
    if (state.status != UsersAdminStatus.loaded) return;
    emit(state.copyWith(status: UsersAdminStatus.loading, clearError: true));
    try {
      await _repo.updateUser(
        event.id,
        username: event.username,
        role: event.role,
        kitchenStationId: event.kitchenStationId,
        password: event.password,
      );
      final list = await _repo.fetchUsers();
      emit(UsersAdminState(status: UsersAdminStatus.loaded, users: list));
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDismissError(
    UsersErrorDismissed event,
    Emitter<UsersAdminState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

  Future<void> _onDelete(
    UserDeleteSubmitted event,
    Emitter<UsersAdminState> emit,
  ) async {
    if (state.status != UsersAdminStatus.loaded) return;
    emit(state.copyWith(status: UsersAdminStatus.loading, clearError: true));
    try {
      await _repo.deleteUser(event.id);
      final list = await _repo.fetchUsers();
      emit(UsersAdminState(status: UsersAdminStatus.loaded, users: list));
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: UsersAdminStatus.loaded,
          users: state.users,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
