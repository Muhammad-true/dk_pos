import 'package:flutter/material.dart';

/// Карточка-строка для списков админки: удобно листать на телефоне.
class AdminListRowCard extends StatelessWidget {
  const AdminListRowCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(left: 12, right: 12, bottom: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: child,
      ),
    );
  }
}

/// Физика прокрутки списков админки (лёгкий отскок).
const ScrollPhysics kAdminListScrollPhysics = BouncingScrollPhysics(
  parent: AlwaysScrollableScrollPhysics(),
);
