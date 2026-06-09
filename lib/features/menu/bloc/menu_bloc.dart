import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/cache/pos_menu_image_prefetch.dart';
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
      unawaited(prefetchPosMenuCatalog(list));
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
    final next = state.copyWith(pathIds: [...state.pathIds, id]);
    emit(next);
    _prefetchVisibleItems(next);
  }

  void _onBack(MenuCatalogBack event, Emitter<MenuState> emit) {
    if (state.pathIds.isEmpty) return;
    final next = state.copyWith(
      pathIds: state.pathIds.sublist(0, state.pathIds.length - 1),
    );
    emit(next);
    _prefetchVisibleItems(next);
  }

  void _onPathSet(MenuCatalogPathSet event, Emitter<MenuState> emit) {
    final next = state.copyWith(pathIds: [...event.pathIds]);
    emit(next);
    _prefetchVisibleItems(next);
  }

  void _prefetchVisibleItems(MenuState menu) {
    final items = menu.currentItems;
    if (items.isEmpty) return;
    unawaited(
      prefetchPosMenuCatalog(
        menu.categoryRoots,
        priorityItems: items,
      ),
    );
  }
}
