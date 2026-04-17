import 'package:equatable/equatable.dart';

sealed class CatalogAdminEvent extends Equatable {
  const CatalogAdminEvent();

  @override
  List<Object?> get props => [];
}

final class CatalogLoadRequested extends CatalogAdminEvent {
  const CatalogLoadRequested();
}

final class CatalogCreateSubmitted extends CatalogAdminEvent {
  const CatalogCreateSubmitted({
    required this.nameRu,
    this.nameTj,
    this.nameEn,
    this.subtitleRu,
    this.subtitleTj,
    this.subtitleEn,
    required this.sortOrder,
    this.parentId,
  });

  final String nameRu;
  final String? nameTj;
  final String? nameEn;
  final String? subtitleRu;
  final String? subtitleTj;
  final String? subtitleEn;
  final int sortOrder;
  final int? parentId;

  @override
  List<Object?> get props => [
        nameRu,
        nameTj,
        nameEn,
        subtitleRu,
        subtitleTj,
        subtitleEn,
        sortOrder,
        parentId,
      ];
}

final class CatalogErrorDismissed extends CatalogAdminEvent {
  const CatalogErrorDismissed();
}
