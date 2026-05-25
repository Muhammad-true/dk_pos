import 'package:dk_pos/shared/shared.dart';

/// Путь в каталоге для режима «добавить к счёту»: сразу раздел с товарами, если есть.
List<int> initialMenuPathForProductPicker(List<PosCategory> roots) {
  List<int>? walk(PosCategory node, List<int> prefix) {
    final path = [...prefix, node.id];
    if (node.items.isNotEmpty) return path;
    for (final child in node.children) {
      final found = walk(child, path);
      if (found != null) return found;
    }
    return null;
  }

  for (final root in roots) {
    final found = walk(root, const []);
    if (found != null) return found;
  }
  if (roots.isNotEmpty) return [roots.first.id];
  return const [];
}
