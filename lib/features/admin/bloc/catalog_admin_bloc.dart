import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_repository.dart';

import 'catalog_admin_event.dart';
import 'catalog_admin_state.dart';

class CatalogAdminBloc extends Bloc<CatalogAdminEvent, CatalogAdminState> {
  CatalogAdminBloc(this._repo) : super(const CatalogAdminState()) {
    on<CatalogLoadRequested>(_onLoad);
    on<CatalogCreateSubmitted>(_onCreate);
    on<CatalogErrorDismissed>(_onDismissError);
  }

  final CatalogAdminRepository _repo;

  Future<void> _onLoad(
    CatalogLoadRequested event,
    Emitter<CatalogAdminState> emit,
  ) async {
    emit(state.copyWith(status: CatalogAdminStatus.loading, clearError: true));
    try {
      final list = await _repo.fetchCategories();
      emit(CatalogAdminState(status: CatalogAdminStatus.loaded, categories: list));
    } on ApiException catch (e) {
      emit(
        CatalogAdminState(
          status: CatalogAdminStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        CatalogAdminState(
          status: CatalogAdminStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreate(
    CatalogCreateSubmitted event,
    Emitter<CatalogAdminState> emit,
  ) async {
    if (state.status != CatalogAdminStatus.loaded) return;
    emit(state.copyWith(status: CatalogAdminStatus.loading, clearError: true));
    try {
      await _repo.createCategory(
        nameRu: event.nameRu,
        nameTj: event.nameTj,
        nameEn: event.nameEn,
        subtitleRu: event.subtitleRu,
        subtitleTj: event.subtitleTj,
        subtitleEn: event.subtitleEn,
        sortOrder: event.sortOrder,
        parentId: event.parentId,
      );
      final list = await _repo.fetchCategories();
      emit(CatalogAdminState(status: CatalogAdminStatus.loaded, categories: list));
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: CatalogAdminStatus.loaded,
          categories: state.categories,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogAdminStatus.loaded,
          categories: state.categories,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDismissError(
    CatalogErrorDismissed event,
    Emitter<CatalogAdminState> emit,
  ) {
    emit(state.copyWith(clearError: true));
  }
}
