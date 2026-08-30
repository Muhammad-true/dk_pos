import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/menu/bloc/menu_bloc.dart';
import 'package:dk_pos/features/menu/bloc/menu_event.dart';
import 'package:dk_pos/features/menu/bloc/menu_state.dart';
import 'package:dk_pos/features/menu/data/menu_repository.dart';
import 'package:dk_pos/shared/models/pos_menu_models.dart';

enum _SoldOutFilter { all, stopped, available }

class _SoldOutRow {
  const _SoldOutRow({required this.item, required this.categoryPath});

  final PosMenuItem item;
  final String categoryPath;
}

/// Экран кассы: отметить блюда «закончилось сегодня» (без долгого нажатия в меню).
Future<void> showPosSoldOutTodayDialog(BuildContext context) {
  // При повторном открытии показываем фактическую серверную отметку, а не
  // только старый снимок каталога. Если сеть временно недоступна, Bloc
  // сохранит уже загруженное состояние — кассир всё равно увидит свои метки.
  final menuBloc = context.read<MenuBloc>();
  menuBloc.add(const MenuLoadRequested());
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: menuBloc,
        child: const _SoldOutTodayDialog(),
      );
    },
  );
}

List<_SoldOutRow> _flattenMenuItems(List<PosCategory> roots) {
  final out = <_SoldOutRow>[];
  void walk(PosCategory cat, List<String> path) {
    final nextPath = [
      ...path,
      cat.name.trim(),
    ].where((s) => s.isNotEmpty).toList();
    final pathLabel = nextPath.join(' · ');
    for (final item in cat.items) {
      if (item.id.trim().isEmpty) continue;
      out.add(_SoldOutRow(item: item, categoryPath: pathLabel));
    }
    for (final child in cat.children) {
      walk(child, nextPath);
    }
  }

  for (final root in roots) {
    walk(root, const []);
  }
  out.sort((a, b) {
    final byCat = a.categoryPath.compareTo(b.categoryPath);
    if (byCat != 0) return byCat;
    return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  });
  return out;
}

class _SoldOutTodayDialog extends StatefulWidget {
  const _SoldOutTodayDialog();

  @override
  State<_SoldOutTodayDialog> createState() => _SoldOutTodayDialogState();
}

class _SoldOutTodayDialogState extends State<_SoldOutTodayDialog> {
  final _searchCtrl = TextEditingController();
  // Сначала — то, что уже выключили. Кассиру не нужно искать и отмечать
  // товар второй раз после закрытия окна.
  _SoldOutFilter _filter = _SoldOutFilter.stopped;
  final Set<String> _busyIds = {};

  /// Локальные переключатели поверх меню (пока не пришёл reload).
  final Map<String, bool> _localSoldOut = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isSoldOut(PosMenuItem item) =>
      _localSoldOut[item.id] ?? item.soldOutToday;

  Future<void> _toggle(PosMenuItem item) async {
    if (_busyIds.contains(item.id)) return;
    final next = !_isSoldOut(item);
    setState(() {
      _busyIds.add(item.id);
      _localSoldOut[item.id] = next;
    });
    try {
      await context.read<MenuRepository>().setSoldOutToday(
        menuItemId: item.id,
        stopped: next,
      );
      if (!mounted) return;
      context.read<MenuBloc>().add(
        MenuSoldOutTodayChanged(
          menuItemId: item.id,
          soldOutToday: next,
        ),
      );
      context.read<MenuBloc>().add(const MenuLoadRequested());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? '${item.name}: закончилось сегодня'
                : '${item.name}: снова в наличии',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _localSoldOut.remove(item.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(item.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final compact = WindowLayout(width: w).isCompact;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 24,
        vertical: compact ? 12 : 28,
      ),
      title: Row(
        children: [
          Icon(Icons.block_rounded, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Закончилось сегодня',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Отметьте блюда, которых нет в наличии. '
                  'Нашёл в меню и на сайте — недоступны до завтра.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: compact ? w - 16 : 720,
        height: h * (compact ? 0.78 : 0.72),
        child: BlocBuilder<MenuBloc, MenuState>(
          builder: (context, menu) {
            final rows = _flattenMenuItems(menu.categoryRoots);
            final q = _searchCtrl.text.trim().toLowerCase();
            final filtered = rows
                .where((r) {
                  final sold = _isSoldOut(r.item);
                  if (_filter == _SoldOutFilter.stopped && !sold) return false;
                  if (_filter == _SoldOutFilter.available && sold) return false;
                  if (q.isEmpty) return true;
                  return r.item.name.toLowerCase().contains(q) ||
                      r.categoryPath.toLowerCase().contains(q);
                })
                .toList(growable: false);
            final stoppedCount = rows.where((r) => _isSoldOut(r.item)).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Поиск',
                    hintText: 'Название или категория',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Все (${rows.length})'),
                      selected: _filter == _SoldOutFilter.all,
                      onSelected: (_) =>
                          setState(() => _filter = _SoldOutFilter.all),
                    ),
                    ChoiceChip(
                      label: Text('Закончились ($stoppedCount)'),
                      selected: _filter == _SoldOutFilter.stopped,
                      onSelected: (_) =>
                          setState(() => _filter = _SoldOutFilter.stopped),
                    ),
                    ChoiceChip(
                      label: Text('В наличии (${rows.length - stoppedCount})'),
                      selected: _filter == _SoldOutFilter.available,
                      onSelected: (_) =>
                          setState(() => _filter = _SoldOutFilter.available),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (menu.loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            rows.isEmpty
                                ? 'Меню ещё не загружено'
                                : _filter == _SoldOutFilter.stopped
                                ? 'Сегодня ещё ничего не отмечено как закончившееся'
                                : 'Ничего не найдено',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final row = filtered[i];
                            final sold = _isSoldOut(row.item);
                            final busy = _busyIds.contains(row.item.id);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: Text(
                                row.item.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: sold
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: sold ? scheme.onSurfaceVariant : null,
                                ),
                              ),
                              subtitle: Text(
                                row.categoryPath.isEmpty
                                    ? row.item.priceText
                                    : '${row.categoryPath} · ${row.item.priceText}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: busy
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          sold
                                              ? 'Стоп продаж: включён'
                                              : 'В продаже',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: sold
                                                    ? scheme.error
                                                    : Colors.green.shade700,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        Switch.adaptive(
                                          value: sold,
                                          activeThumbColor: scheme.error,
                                          onChanged: (_) => _toggle(row.item),
                                        ),
                                      ],
                                    ),
                              onTap: busy ? null : () => _toggle(row.item),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
