import 'package:equatable/equatable.dart';

sealed class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => [];
}

final class MenuLoadRequested extends MenuEvent {
  const MenuLoadRequested({this.lang = 'ru'});

  final String lang;

  @override
  List<Object?> get props => [lang];
}

/// Войти в подкатегорию по индексу в [MenuState.currentChildCategories].
final class MenuDrillInto extends MenuEvent {
  const MenuDrillInto(this.childIndex);

  final int childIndex;

  @override
  List<Object?> get props => [childIndex];
}

/// Шаг назад по иерархии категорий.
final class MenuCatalogBack extends MenuEvent {
  const MenuCatalogBack();
}

/// Перейти к конкретному пути категорий напрямую.
final class MenuCatalogPathSet extends MenuEvent {
  const MenuCatalogPathSet(this.pathIds);

  final List<int> pathIds;

  @override
  List<Object?> get props => [pathIds];
}
