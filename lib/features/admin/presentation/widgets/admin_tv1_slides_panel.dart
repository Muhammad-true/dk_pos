import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_state.dart';
import 'package:dk_pos/features/admin/data/admin_category_row.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_repository.dart';

/// Назначение слайдов карусели ТВ1 по категориям (`categories.tv1_page`).
/// Позиции без своего `menu_items.tv1_page` попадают на слайд категории.
class AdminTv1SlidesPanel extends StatefulWidget {
  const AdminTv1SlidesPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<AdminTv1SlidesPanel> createState() => _AdminTv1SlidesPanelState();
}

class _AdminTv1SlidesPanelState extends State<AdminTv1SlidesPanel> {
  final _filterCtrl = TextEditingController();
  static const int _maxSlide = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogAdminBloc>().add(const CatalogLoadRequested());
    });
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  List<AdminCategoryRow> _filteredAndSorted(List<AdminCategoryRow> flat) {
    final ordered = orderCategoriesForAdminTree(flat);
    final q = _filterCtrl.text.trim().toLowerCase();
    Iterable<AdminCategoryRow> it = ordered;
    if (q.isNotEmpty) {
      it = it.where((e) => e.name.ru.toLowerCase().contains(q));
    }
    final list = it.toList();
    list.sort((a, b) {
      final ap = a.tv1Page;
      final bp = b.tv1Page;
      if (ap != null && bp == null) return -1;
      if (ap == null && bp != null) return 1;
      if (ap != null && bp != null && ap != bp) return ap.compareTo(bp);
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  Future<void> _setTv1Page(AdminCategoryRow cat, int? page) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<CatalogAdminRepository>();
    final bloc = context.read<CatalogAdminBloc>();
    try {
      await repo.updateCategoryTv1Page(id: cat.id, tv1Page: page);
      if (!mounted) return;
      bloc.add(const CatalogLoadRequested());
      messenger.showSnackBar(
        SnackBar(content: Text('«${cat.name.ru}»: ${page ?? 'не на ТВ1'}')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                'Карусель ТВ1',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Слайд задаётся для категории: все доступные позиции в ней без своего tv1_page попадут на этот кадр. У отдельного товара можно переопределить слайд в списке товаров (приоритет у товара).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: TextField(
                controller: _filterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Поиск по названию категории',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Обновить список',
                  onPressed: () {
                    context.read<CatalogAdminBloc>().add(const CatalogLoadRequested());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<CatalogAdminBloc, CatalogAdminState>(
                builder: (context, state) {
                  if (state.status == CatalogAdminStatus.loading &&
                      state.categories.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == CatalogAdminStatus.failure) {
                    return Center(
                      child: Text(state.errorMessage ?? 'Ошибка загрузки'),
                    );
                  }
                  final rows = _filteredAndSorted(state.categories);
                  if (rows.isEmpty) {
                    return const Center(child: Text('Нет категорий'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final cat = rows[i];
                      return Material(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 16.0 * cat.depth),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.name.ru,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (cat.subtitle != null &&
                                          cat.subtitle!.ru.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          cat.subtitle!.ru,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<int?>(
                                  key: ValueKey('tv1_cat_${cat.id}_${cat.tv1Page}'),
                                  initialValue: cat.tv1Page,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Слайд ТВ1',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('—'),
                                    ),
                                    for (var p = 1; p <= _maxSlide; p++)
                                      DropdownMenuItem<int?>(
                                        value: p,
                                        child: Text('$p'),
                                      ),
                                  ],
                                  onChanged: (v) => _setTv1Page(cat, v),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
