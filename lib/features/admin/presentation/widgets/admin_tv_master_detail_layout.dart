import 'package:flutter/material.dart';

/// Master-detail для редакторов ТВ: список страниц слева, редактор справа на планшете.
class AdminTvMasterDetailLayout extends StatefulWidget {
  const AdminTvMasterDetailLayout({
    super.key,
    required this.header,
    required this.master,
    required this.detail,
    this.detailScrollIdentity,
    this.breakpoint = 840,
    this.masterWidth = 300,
  });

  final Widget header;
  final Widget master;
  final Widget? detail;
  /// Меняется при выборе другой страницы и возвращает её редактор к началу.
  final Object? detailScrollIdentity;
  final double breakpoint;
  final double masterWidth;

  @override
  State<AdminTvMasterDetailLayout> createState() =>
      _AdminTvMasterDetailLayoutState();
}

class _AdminTvMasterDetailLayoutState extends State<AdminTvMasterDetailLayout> {
  final ScrollController _detailScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant AdminTvMasterDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detailScrollIdentity == widget.detailScrollIdentity) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_detailScrollController.hasClients) return;
      _detailScrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _detailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= widget.breakpoint;
    if (!wide) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          widget.header,
          widget.master,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: widget.header,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: widget.masterWidth,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 8, 16),
                  children: [widget.master],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: widget.detail == null
                    ? Center(
                        child: Text(
                          'Выберите страницу слева',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    : Scrollbar(
                        controller: _detailScrollController,
                        thumbVisibility: true,
                        interactive: true,
                        child: ListView(
                          controller: _detailScrollController,
                          primary: false,
                          padding: const EdgeInsets.all(16),
                          children: [widget.detail!],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Плитка страницы в master-колонке.
class AdminTvPageMasterTile extends StatelessWidget {
  const AdminTvPageMasterTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.leading,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
