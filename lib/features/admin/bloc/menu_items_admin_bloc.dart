import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';

import 'menu_items_admin_event.dart';
import 'menu_items_admin_state.dart';

class MenuItemsAdminBloc extends Bloc<MenuItemsAdminEvent, MenuItemsAdminState> {
  MenuItemsAdminBloc(this._repo) : super(const MenuItemsAdminState()) {
    on<MenuItemsLoadRequested>(_onLoad);
    on<MenuItemsErrorDismissed>(_onDismissError);
  }

  final MenuItemsAdminRepository _repo;

  Future<void> _onLoad(
    MenuItemsLoadRequested event,
    Emitter<MenuItemsAdminState> emit,
  ) async {
    emit(state.copyWith(status: MenuItemsAdminStatus.loading, clearError: true));
    try {
      final list = await _repo.fetchItems();
      emit(MenuItemsAdminState(status: MenuItemsAdminStatus.loaded, items: list));
    } on ApiException catch (e) {
      emit(
        MenuItemsAdminState(
          status: MenuItemsAdminStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        MenuItemsAdminState(
          status: MenuItemsAdminStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDismissError(
    MenuItemsErrorDismissed event,
    Emitter<MenuItemsAdminState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }

}
