import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';

import 'screens_admin_event.dart';
import 'screens_admin_state.dart';

class ScreensAdminBloc extends Bloc<ScreensAdminEvent, ScreensAdminState> {
  ScreensAdminBloc(this._repo) : super(const ScreensAdminState()) {
    on<ScreensLoadRequested>(_onLoad);
    on<ScreensErrorDismissed>(_onDismissError);
  }

  final ScreensAdminRepository _repo;

  Future<void> _onLoad(
    ScreensLoadRequested event,
    Emitter<ScreensAdminState> emit,
  ) async {
    emit(state.copyWith(status: ScreensAdminStatus.loading, clearError: true));
    try {
      final list = await _repo.fetchScreens();
      emit(ScreensAdminState(status: ScreensAdminStatus.loaded, screens: list));
    } on ApiException catch (e) {
      emit(
        ScreensAdminState(
          status: ScreensAdminStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        ScreensAdminState(
          status: ScreensAdminStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDismissError(
    ScreensErrorDismissed event,
    Emitter<ScreensAdminState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
