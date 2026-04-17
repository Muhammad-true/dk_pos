import 'package:equatable/equatable.dart';

import 'package:dk_pos/shared/shared.dart';

PosCategory? _nodeAtPath(List<PosCategory> roots, List<int> path) {
  if (path.isEmpty) return null;
  PosCategory? current;
  var level = roots;
  for (final id in path) {
    current = null;
    for (final n in level) {
      if (n.id == id) {
        current = n;
        break;
      }
    }
    if (current == null) return null;
    level = current.children;
  }
  return current;
}

class MenuState extends Equatable {
  const MenuState({
    this.loading = true,
    this.error,
    this.categoryRoots = const [],
    this.pathIds = const [],
  });

  final bool loading;
  final String? error;
  /// Корневые категории (дерево с полем [PosCategory.children]).
  final List<PosCategory> categoryRoots;
  /// Цепочка id от корня: заход в «Напитки» → «Горячие» и т.д.
  final List<int> pathIds;

  /// Дочерние категории текущего уровня (при пустом пути — корни).
  List<PosCategory> get currentChildCategories {
    if (categoryRoots.isEmpty) return [];
    if (pathIds.isEmpty) return categoryRoots;
    return _nodeAtPath(categoryRoots, pathIds)?.children ?? [];
  }

  /// Товары у текущего узла (у корня пусто, пока не выбрана категория).
  List<PosMenuItem> get currentItems {
    if (pathIds.isEmpty) return [];
    return _nodeAtPath(categoryRoots, pathIds)?.items ?? [];
  }

  String get breadcrumbLine {
    if (pathIds.isEmpty) return '';
    final parts = <String>[];
    var level = categoryRoots;
    for (final id in pathIds) {
      PosCategory? hit;
      for (final n in level) {
        if (n.id == id) {
          hit = n;
          break;
        }
      }
      if (hit == null) break;
      parts.add(hit.name);
      level = hit.children;
    }
    return parts.join(' › ');
  }

  bool get canGoBack => pathIds.isNotEmpty;

  MenuState copyWith({
    bool? loading,
    String? error,
    List<PosCategory>? categoryRoots,
    List<int>? pathIds,
    bool clearError = false,
  }) {
    return MenuState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      categoryRoots: categoryRoots ?? this.categoryRoots,
      pathIds: pathIds ?? this.pathIds,
    );
  }

  @override
  List<Object?> get props => [loading, error, categoryRoots, pathIds];
}
