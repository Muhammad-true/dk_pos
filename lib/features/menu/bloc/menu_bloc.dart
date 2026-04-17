import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/menu/data/menu_repository.dart';

import 'menu_event.dart';
import 'menu_state.dart';

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  MenuBloc(this._repo) : super(const MenuState()) {
    on<MenuLoadRequested>(_onLoad);
    on<MenuDrillInto>(_onDrill);
    on<MenuCatalogBack>(_onBack);
    on<MenuCatalogPathSet>(_onPathSet);
  }

  final MenuRepository _repo;

  Future<void> _onLoad(MenuLoadRequested event, Emitter<MenuState> emit) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final list = await _repo.fetchMenu(lang: event.lang);
      emit(
        MenuState(
          loading: false,
          categoryRoots: list,
          pathIds: const [],
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void _onDrill(MenuDrillInto event, Emitter<MenuState> emit) {
    final children = state.currentChildCategories;
    if (event.childIndex < 0 || event.childIndex >= children.length) return;
    final id = children[event.childIndex].id;
    emit(state.copyWith(pathIds: [...state.pathIds, id]));
  }

  void _onBack(MenuCatalogBack event, Emitter<MenuState> emit) {
    if (state.pathIds.isEmpty) return;
    emit(
      state.copyWith(
        pathIds: state.pathIds.sublist(0, state.pathIds.length - 1),
      ),
    );
  }

  void _onPathSet(MenuCatalogPathSet event, Emitter<MenuState> emit) {
    emit(state.copyWith(pathIds: [...event.pathIds]));
  }
}
