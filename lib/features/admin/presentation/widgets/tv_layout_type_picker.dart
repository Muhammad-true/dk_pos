import 'package:flutter/material.dart';

/// Один вариант макета в визуальном конструкторе (ТВ2/ТВ3/экран).
class TvLayoutTypeOption {
  const TvLayoutTypeOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
}

/// Карточный выбор типа страницы/экрана — вместо выпадающего списка.
class TvLayoutTypePicker extends StatelessWidget {
  const TvLayoutTypePicker({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.title,
    this.hint,
    this.crossAxisCount = 2,
  });

  final List<TvLayoutTypeOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final String? title;
  final String? hint;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cols = crossAxisCount.clamp(1, 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
        ],
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        if (title != null || hint != null) const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final gap = 10.0;
            final cellW = (width - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final opt in options)
                  SizedBox(
                    width: cellW,
                    child: _TypeCard(
                      option: opt,
                      selected: opt.id == selectedId,
                      onTap: () => onSelected(opt.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TvLayoutTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = option.accentColor ?? scheme.primary;

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : scheme.surfaceContainerLow,
      elevation: selected ? 1 : 0,
      shadowColor: accent.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? accent : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(option.icon, color: accent, size: 22),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: accent, size: 22),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                option.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                option.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
