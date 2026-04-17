import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_combo_row.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/combo_editor_screen.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_list_row_card.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Вкладка «Комбо»: список и создание.
class CombosAdminPanel extends StatefulWidget {
  const CombosAdminPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  @override
  State<CombosAdminPanel> createState() => _CombosAdminPanelState();
}

class _CombosAdminPanelState extends State<CombosAdminPanel> {
  List<AdminComboRow> _combos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<CombosAdminRepository>();
    final l10n = AppLocalizations.of(context)!;
    try {
      final list = await repo.fetchCombos();
      if (!mounted) return;
      setState(() {
        _combos = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.adminCombosLoadError;
        _loading = false;
      });
    }
  }

  String _comboSubtitle(AppLocalizations l10n, AdminComboRow c) {
    final buf = StringBuffer('id: ${c.id}');
    if (!c.validNow) {
      buf.write(' · ${l10n.adminCombosValidityOutside}');
    } else {
      final parts = <String>[];
      if (c.validDateStart != null || c.validDateEnd != null) {
        parts.add('${c.validDateStart ?? '…'} — ${c.validDateEnd ?? '…'}');
      }
      if (c.validTimeStart != null &&
          c.validTimeStart!.isNotEmpty &&
          c.validTimeEnd != null &&
          c.validTimeEnd!.isNotEmpty) {
        parts.add('${c.validTimeStart}–${c.validTimeEnd}');
      }
      if (parts.isNotEmpty) {
        buf.write(' · ${parts.join(' · ')}');
      }
    }
    return buf.toString();
  }

  Future<void> _createDialog(AppLocalizations l10n) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminCombosCreateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.adminCombosNameRu,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: InputDecoration(
                labelText: l10n.adminCombosPriceRu,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final price = priceCtrl.text.trim();
    if (name.isEmpty || price.isEmpty) return;
    final repo = context.read<CombosAdminRepository>();
    try {
      await repo.createCombo({
        'name': {'ru': name},
        'price_text': {'ru': price},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCombosCreated)),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxW = widget.maxBodyWidth;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: Text(l10n.actionRetry)),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_combos.isEmpty)
              Center(child: Text(l10n.adminCombosEmpty))
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                physics: kAdminListScrollPhysics,
                itemCount: _combos.length,
                itemBuilder: (_, i) {
                  final c = _combos[i];
                  final title = c.nameRu.isEmpty ? '#${c.id}' : c.nameRu;
                  return AdminListRowCard(
                    child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _comboSubtitle(l10n, c),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final combosRepo =
                              context.read<CombosAdminRepository>();
                          final menuRepo =
                              context.read<MenuItemsAdminRepository>();
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => RepositoryProvider.value(
                                value: combosRepo,
                                child: RepositoryProvider.value(
                                  value: menuRepo,
                                  child: ComboEditorScreen(comboId: c.id),
                                ),
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                      ),
                  );
                },
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _createDialog(l10n),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.adminCombosCreateTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
