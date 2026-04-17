import 'package:equatable/equatable.dart';

import 'package:dk_pos/features/admin/data/admin_category_row.dart';

enum CatalogAdminStatus { initial, loading, loaded, failure }

class CatalogAdminState extends Equatable {
  const CatalogAdminState({
    this.status = CatalogAdminStatus.initial,
    this.categories = const [],
    this.errorMessage,
  });

  final CatalogAdminStatus status;
  final List<AdminCategoryRow> categories;
  final String? errorMessage;

  bool get isLoading => status == CatalogAdminStatus.loading;

  CatalogAdminState copyWith({
    CatalogAdminStatus? status,
    List<AdminCategoryRow>? categories,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogAdminState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, categories, errorMessage];
}
