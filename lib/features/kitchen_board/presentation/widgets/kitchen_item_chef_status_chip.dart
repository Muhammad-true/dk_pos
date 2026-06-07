import 'package:flutter/material.dart';

/// Статус позиции в цвете повара (принято / готово).
class KitchenItemChefStatusChip extends StatelessWidget {
  const KitchenItemChefStatusChip({
    super.key,
    required this.chefColor,
    required this.label,
    required this.icon,
  });

  final Color chefColor;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = Color.lerp(chefColor, Colors.black, 0.42) ?? chefColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chefColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chefColor.withValues(alpha: 0.65), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chefColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
