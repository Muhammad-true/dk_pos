import 'package:flutter/material.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_screen_page_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

const _kTv4PageTypes = ['tv4_welcome_pay', 'tv4_queue'];

String _tv4PageTypeLabel(AppLocalizations l10n, String t) {
  switch (t) {
    case 'tv4_welcome_pay':
      return l10n.adminTv4PageTypeWelcomePay;
    case 'tv4_queue':
      return l10n.adminTv4PageTypeQueue;
    default:
      return t;
  }
}

/// Редактор слайдов ТВ4: приветствие/оплата и очередь как страницы `screen_pages`.
class Tv4SlidesEditorScreen extends StatefulWidget {
  const Tv4SlidesEditorScreen({
    super.key,
    required this.screenId,
    required this.screensRepo,
  });

  final int screenId;
  final ScreensAdminRepository screensRepo;

  @override
  State<Tv4SlidesEditorScreen> createState() => _Tv4SlidesEditorScreenState();
}

class _Tv4SlidesEditorScreenState extends State<Tv4SlidesEditorScreen> {
  List<AdminScreenPageRow> _pages = [];
  bool _loading = true;
  bool _savingOrder = false;
  String? _error;
  String _newPageType = 'tv4_welcome_pay';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pages = await widget.screensRepo.fetchScreenPages(widget.screenId);
      if (!mounted) return;
      pages.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
      setState(() {
        _pages = pages;
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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _persistOrder(List<AdminScreenPageRow> ordered) async {
    setState(() => _savingOrder = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      for (var i = 0; i < ordered.length; i++) {
        await widget.screensRepo.patchScreenPage(
          widget.screenId,
          ordered[i].id,
          sortOrder: i * 10,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4SlidesOrderSaved)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _addPage(AppLocalizations l10n) async {
    try {
      final nextOrder = _pages.isEmpty
          ? 0
          : (_pages.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 10);
      await widget.screensRepo.addScreenPage(
        widget.screenId,
        pageType: _newPageType,
        sortOrder: nextOrder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4PageAdded)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deletePage(AdminScreenPageRow p, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminScreenPageDeleteTitle),
        content: Text(
          l10n.adminScreenPageDeleteConfirm(_tv4PageTypeLabel(l10n, p.pageType)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.screensRepo.deleteScreenPage(widget.screenId, p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminTv4PageDeleted)),
      );
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTv4SlidesEditorTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _reload, child: Text(l10n.adminTvPreviewRetry)),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        l10n.adminTv4SlidesEditorSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.adminTv4SlidesReorderHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _pages.length,
                        onReorder: (oldIndex, newIndex) {
                          if (_savingOrder) return;
                          if (newIndex > oldIndex) newIndex -= 1;
                          final next = List<AdminScreenPageRow>.from(_pages);
                          final item = next.removeAt(oldIndex);
                          next.insert(newIndex, item);
                          setState(() => _pages = next);
                          _persistOrder(next);
                        },
                        itemBuilder: (context, index) {
                          final p = _pages[index];
                          return ListTile(
                            key: ValueKey<int>(p.id),
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle_rounded),
                            ),
                            title: Text(_tv4PageTypeLabel(l10n, p.pageType)),
                            subtitle: Text('id=${p.id} · sort=${p.sortOrder}'),
                            trailing: IconButton(
                              tooltip: l10n.actionDelete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: _savingOrder ? null : () => _deletePage(p, l10n),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _savingOrder ? null : () => _addPage(l10n),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.adminTv4AddPage),
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>(_newPageType),
                        initialValue: _newPageType,
                        decoration: InputDecoration(
                          labelText: l10n.adminTv4SlidesEditorTitle,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in _kTv4PageTypes)
                            DropdownMenuItem(
                              value: t,
                              child: Text(_tv4PageTypeLabel(l10n, t)),
                            ),
                        ],
                        onChanged: _savingOrder
                            ? null
                            : (v) {
                                if (v != null) setState(() => _newPageType = v);
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
