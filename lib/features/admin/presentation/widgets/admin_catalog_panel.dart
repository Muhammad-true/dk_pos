import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';

import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_state.dart';
import 'package:dk_pos/features/admin/data/admin_category_row.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_list_row_card.dart';

String _treeIndentDots(int depth) {
  if (depth <= 0) return '';
  return '${List.filled(depth, '·').join(' ')} ';
}

class AdminCatalogPanel extends StatelessWidget {
  const AdminCatalogPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  static int _nextSortOrder(List<AdminCategoryRow> categories) {
    if (categories.isEmpty) return 0;
    var m = 0;
    for (final c in categories) {
      if (c.sortOrder > m) m = c.sortOrder;
    }
    return m + 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.adminCatalogManageTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: l10n.actionRetry,
                    onPressed: () => context
                        .read<CatalogAdminBloc>()
                        .add(const CatalogLoadRequested()),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 8),
                  BlocBuilder<CatalogAdminBloc, CatalogAdminState>(
                    buildWhen: (p, c) =>
                        p.status != c.status || p.categories != c.categories,
                    builder: (context, state) {
                      return FilledButton.icon(
                        onPressed: state.status == CatalogAdminStatus.loaded
                            ? () => _openCategoryForm(
                                  context,
                                  l10n,
                                  orderCategoriesForAdminTree(state.categories),
                                  _nextSortOrder(state.categories),
                                )
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.adminCategoryAdd),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<CatalogAdminBloc, CatalogAdminState>(
                builder: (context, state) {
                  if (state.status == CatalogAdminStatus.initial ||
                      (state.status == CatalogAdminStatus.loading &&
                          state.categories.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == CatalogAdminStatus.failure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? l10n.adminCatalogLoadError,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context
                                  .read<CatalogAdminBloc>()
                                  .add(const CatalogLoadRequested()),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.categories.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.adminCatalogEmpty,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.errorMessage != null &&
                          state.status == CatalogAdminStatus.loaded)
                        Material(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => context
                                      .read<CatalogAdminBloc>()
                                      .add(const CatalogErrorDismissed()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (state.errorMessage != null &&
                          state.status == CatalogAdminStatus.loaded)
                        const SizedBox(height: 12),
                        Expanded(
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Builder(
                                builder: (context) {
                                  final ordered = orderCategoriesForAdminTree(
                                    state.categories,
                                  );
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 20,
                                    ),
                                    physics: kAdminListScrollPhysics,
                                    itemCount: ordered.length,
                                    itemBuilder: (context, i) {
                                      final c = ordered[i];
                                      final extras = <String>[];
                                      if (c.name.tj != null &&
                                          c.name.tj!.isNotEmpty) {
                                        extras.add(c.name.tj!);
                                      }
                                      if (c.name.en != null &&
                                          c.name.en!.isNotEmpty) {
                                        extras.add(c.name.en!);
                                      }
                                      final sub = c.subtitle;
                                      String? subLine;
                                      if (sub != null && sub.ru.isNotEmpty) {
                                        subLine = sub.ru;
                                      }
                                      final meta =
                                          '#${c.id} · ${l10n.adminCategoryDepthLabel(c.depth + 1)} · ${l10n.adminCategorySortOrder}: ${c.sortOrder}';
                                      final secondaryParts = <String>[];
                                      if (extras.isNotEmpty) {
                                        secondaryParts.add(extras.join(' · '));
                                      }
                                      if (subLine != null) {
                                        secondaryParts.add(subLine);
                                      }
                                      secondaryParts.add(meta);
                                      final secondary =
                                          secondaryParts.join(' · ');

                                      return AdminListRowCard(
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                            14 + c.depth * 12.0,
                                            12,
                                            14,
                                            12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                c.name.ru,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                secondary,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategoryForm(
    BuildContext context,
    AppLocalizations l10n,
    List<AdminCategoryRow> orderedCategories,
    int defaultSortOrder,
  ) async {
    final parentMessenger = ScaffoldMessenger.of(context);
    final bloc = context.read<CatalogAdminBloc>();

    final nameRuCtrl = TextEditingController();
    final nameTjCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final subRuCtrl = TextEditingController();
    final subTjCtrl = TextEditingController();
    final subEnCtrl = TextEditingController();
    final sortCtrl =
        TextEditingController(text: defaultSortOrder.toString());
    final formKey = GlobalKey<FormState>();
    final parentCandidates = orderedCategories.where((c) => c.depth < 4).toList();
    var selectedParentId = ValueNotifier<int?>(null);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return BlocProvider.value(
          value: bloc,
          child: BlocListener<CatalogAdminBloc, CatalogAdminState>(
            listenWhen: (p, c) => p.isLoading && !c.isLoading,
            listener: (ctx, state) {
              if (state.errorMessage != null) {
                parentMessenger.showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
                return;
              }
              Navigator.of(ctx).pop();
              parentMessenger.showSnackBar(
                SnackBar(content: Text(l10n.adminCategoryCreated)),
              );
            },
            child: AlertDialog(
              title: Text(l10n.adminCategoryFormTitle),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<int?>(
                        valueListenable: selectedParentId,
                        builder: (context, parentId, _) {
                          return DropdownButtonFormField<int?>(
                            key: ValueKey(parentId),
                            initialValue: parentId,
                            isExpanded: true,
                            selectedItemBuilder: (context) => [
                              Text(
                                l10n.adminCategoryParentRoot,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              ...parentCandidates.map(
                                (c) => Text(
                                  '${_treeIndentDots(c.depth)}${c.name.ru}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.adminCategoryParentLabel,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(l10n.adminCategoryParentRoot),
                              ),
                              ...parentCandidates.map(
                                (c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(
                                    '${_treeIndentDots(c.depth)}${c.name.ru}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => selectedParentId.value = v,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameRuCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategoryNameRu,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? l10n.adminCategoryNameRuError
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameTjCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategoryNameTg,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameEnCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategoryNameEn,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: subRuCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategorySubtitleRu,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subTjCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategorySubtitleTg,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subEnCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategorySubtitleEn,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: sortCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.adminCategorySortOrder,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return l10n.adminCategorySortInvalid;
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return l10n.adminCategorySortInvalid;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final sort = int.parse(sortCtrl.text.trim());
                    bloc.add(
                      CatalogCreateSubmitted(
                        nameRu: nameRuCtrl.text.trim(),
                        nameTj: nameTjCtrl.text.trim().isEmpty
                            ? null
                            : nameTjCtrl.text.trim(),
                        nameEn: nameEnCtrl.text.trim().isEmpty
                            ? null
                            : nameEnCtrl.text.trim(),
                        subtitleRu: subRuCtrl.text.trim().isEmpty
                            ? null
                            : subRuCtrl.text.trim(),
                        subtitleTj: subTjCtrl.text.trim().isEmpty
                            ? null
                            : subTjCtrl.text.trim(),
                        subtitleEn: subEnCtrl.text.trim().isEmpty
                            ? null
                            : subEnCtrl.text.trim(),
                        sortOrder: sort,
                        parentId: selectedParentId.value,
                      ),
                    );
                  },
                  child: Text(l10n.actionSave),
                ),
              ],
            ),
          ),
        );
      },
    );

    nameRuCtrl.dispose();
    nameTjCtrl.dispose();
    nameEnCtrl.dispose();
    subRuCtrl.dispose();
    subTjCtrl.dispose();
    subEnCtrl.dispose();
    sortCtrl.dispose();
    selectedParentId.dispose();
  }
}
