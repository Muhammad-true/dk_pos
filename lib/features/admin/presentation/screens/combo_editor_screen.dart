import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:dk_digitial_menu/widgets/robust_network_image.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_menu_item_row.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/l10n/app_localizations.dart';

/// Редактор комбо: название, описание, цена, фото, состав.
class ComboEditorScreen extends StatefulWidget {
  const ComboEditorScreen({
    super.key,
    required this.comboId,
  });

  final int comboId;

  @override
  State<ComboEditorScreen> createState() => _ComboEditorScreenState();
}

class _ComboEditorScreenState extends State<ComboEditorScreen> {
  Map<String, dynamic>? _detail;
  List<AdminMenuItemRow> _menuItems = [];
  bool _loading = true;
  String? _error;

  final _nameRu = TextEditingController();
  final _descRu = TextEditingController();
  final _priceRu = TextEditingController();
  bool _metaDirty = false;
  bool _uploadingImage = false;
  bool _savingMeta = false;

  bool _limitDates = false;
  bool _limitTimes = false;
  DateTime? _dateStart;
  DateTime? _dateEnd;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;

  CombosAdminRepository get _combos => context.read<CombosAdminRepository>();
  MenuItemsAdminRepository get _menu => context.read<MenuItemsAdminRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _nameRu.dispose();
    _descRu.dispose();
    _priceRu.dispose();
    super.dispose();
  }

  void _applyDetailToControllers(Map<String, dynamic> d) {
    final name = d['name'];
    _nameRu.text = name is Map ? (name['ru']?.toString() ?? '') : '';
    final desc = d['description'];
    _descRu.text = desc is Map ? (desc['ru']?.toString() ?? '') : '';
    final pt = d['priceText'];
    _priceRu.text = pt is Map ? (pt['ru']?.toString() ?? '') : '';
  }

  DateTime? _parseApiDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  TimeOfDay? _parseApiTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0].trim()) ?? 0;
    final m = int.tryParse(p[1].trim()) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    String t(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${t(d.month)}-${t(d.day)}';
  }

  String? _fmtTime(TimeOfDay? td) {
    if (td == null) return null;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(td.hour)}:${p(td.minute)}:00';
  }

  void _applyValidityFromDetail(Map<String, dynamic> d) {
    final ds = d['validDateStart']?.toString();
    final de = d['validDateEnd']?.toString();
    _limitDates =
        (ds != null && ds.isNotEmpty) || (de != null && de.isNotEmpty);
    _dateStart = _parseApiDate(ds);
    _dateEnd = _parseApiDate(de);
    final ts = d['validTimeStart']?.toString();
    final te = d['validTimeEnd']?.toString();
    _limitTimes =
        ts != null && ts.isNotEmpty && te != null && te.isNotEmpty;
    _timeStart = _parseApiTime(ts);
    _timeEnd = _parseApiTime(te);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final d = await _combos.fetchComboDetail(widget.comboId);
      final items = await _menu.fetchItems();
      if (!mounted) return;
      setState(() {
        _detail = d;
        _menuItems = items;
        _loading = false;
        if (!_metaDirty) {
          _applyDetailToControllers(d);
          _applyValidityFromDetail(d);
        }
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

  Future<void> _saveMeta(AppLocalizations l10n) async {
    if (_limitTimes && (_timeStart == null || _timeEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCombosTimesBothRequired)),
      );
      return;
    }
    setState(() => _savingMeta = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final body = <String, dynamic>{
        'name': {'ru': _nameRu.text.trim()},
        'description': {'ru': _descRu.text.trim()},
        'price_text': {'ru': _priceRu.text.trim()},
      };
      if (!_limitDates) {
        body['valid_date_start'] = null;
        body['valid_date_end'] = null;
      } else {
        body['valid_date_start'] = _fmtDate(_dateStart);
        body['valid_date_end'] = _fmtDate(_dateEnd);
      }
      if (!_limitTimes) {
        body['valid_time_start'] = null;
        body['valid_time_end'] = null;
      } else {
        body['valid_time_start'] = _fmtTime(_timeStart);
        body['valid_time_end'] = _fmtTime(_timeEnd);
      }
      await _combos.patchCombo(widget.comboId, body);
      if (!mounted) return;
      setState(() => _metaDirty = false);
      final d = await _combos.fetchComboDetail(widget.comboId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _applyDetailToControllers(d);
        _applyValidityFromDetail(d);
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminCombosUpdated)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _savingMeta = false);
    }
  }

  Future<void> _pickImage(AppLocalizations l10n) async {
    final picked = await _pickImageBytes();
    if (picked == null || !mounted) return;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminMenuItemImageReadError)),
      );
      return;
    }
    setState(() => _uploadingImage = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await context.read<UploadRepository>().uploadMenuImageBytes(
            bytes,
            picked.name,
          );
      await _combos.patchCombo(widget.comboId, {'image_path': path});
      if (!mounted) return;
      final d = await _combos.fetchComboDetail(widget.comboId);
      if (!mounted) return;
      setState(() => _detail = d);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminCombosUpdated)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<_SelectedImage?> _pickImageBytes() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return _SelectedImage(
        name: picked.name.isEmpty ? 'image.jpg' : picked.name,
        bytes: await picked.readAsBytes(),
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    return _SelectedImage(name: file.name, bytes: file.bytes);
  }

  Future<void> _clearImage(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _combos.patchCombo(widget.comboId, {'image_path': ''});
      if (!mounted) return;
      final d = await _combos.fetchComboDetail(widget.comboId);
      if (!mounted) return;
      setState(() => _detail = d);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminCombosUpdated)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addItem(AppLocalizations l10n) async {
    final id = await _pickMenuItem(l10n);
    if (id == null) return;
    try {
      await _combos.addComboItem(widget.comboId, id);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorItemAdded)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  AdminMenuItemRow? _menuRowById(String id) {
    for (final m in _menuItems) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<String?> _pickMenuItem(AppLocalizations l10n) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        var q = '';
        String? selId;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final scheme = Theme.of(ctx).colorScheme;
            final filtered = _menuItems
                .where(
                  (e) =>
                      q.isEmpty ||
                      e.name.ru.toLowerCase().contains(q.toLowerCase()) ||
                      e.id.toLowerCase().contains(q.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              title: Text(l10n.adminTv2EditorPickItem),
              content: SizedBox(
                width: 420,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: l10n.adminTv2EditorSearch,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setSt(() => q = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final it = filtered[i];
                          final sel = selId == it.id;
                          final priceLine = it.displayPriceLineRu;
                          final priceNum = it.price % 1 == 0
                              ? it.price.toStringAsFixed(0)
                              : it.price.toStringAsFixed(2);
                          return ListTile(
                            leading: Icon(
                              sel ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: sel ? scheme.primary : null,
                            ),
                            title: Text(
                              it.name.ru,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  it.id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(ctx).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${l10n.adminMenuItemPrice}: $priceNum · $priceLine',
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            selected: sel,
                            dense: true,
                            onTap: () => setSt(() => selId = it.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.actionCancel),
                ),
                FilledButton(
                  onPressed: selId == null ? null : () => Navigator.pop(ctx, selId),
                  child: Text(l10n.adminTv2EditorAddSelectedButton(1)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteCombo(AppLocalizations l10n) async {
    final name =
        _nameRu.text.trim().isEmpty ? '#${widget.comboId}' : _nameRu.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminCombosDeleteCombo),
        content: Text(l10n.adminCombosDeleteComboConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.adminCombosDeleteCombo),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _combos.deleteCombo(widget.comboId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminCombosDeleted)),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 409
          ? l10n.adminCombosDeleteErrorInUse
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickDateStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateStart ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateStart = picked;
      _metaDirty = true;
    });
  }

  Future<void> _pickDateEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateEnd ?? _dateStart ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateEnd = picked;
      _metaDirty = true;
    });
  }

  Future<void> _pickTimeStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeStart ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _timeStart = picked;
      _metaDirty = true;
    });
  }

  Future<void> _pickTimeEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeEnd ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _timeEnd = picked;
      _metaDirty = true;
    });
  }

  Future<void> _remove(int rowId, AppLocalizations l10n) async {
    try {
      await _combos.deleteComboItem(widget.comboId, rowId);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminTv2EditorItemRemoved)),
        );
      }
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
        title: Text('${l10n.adminCombosTitle} #${widget.comboId}'),
        actions: [
          IconButton(
            tooltip: l10n.adminCombosDeleteCombo,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDeleteCombo(l10n),
          ),
        ],
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
                        FilledButton(onPressed: _reload, child: Text(l10n.actionRetry)),
                      ],
                    ),
                  ),
                )
              : _buildBody(l10n),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(l10n),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.adminTv2EditorPickItem),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final d = _detail;
    if (d == null) return const SizedBox.shrink();
    final rawItems = d['items'];
    final items = rawItems is List ? rawItems : const [];
    final imagePath = d['imagePath']?.toString();
    final imageUrl = AppConfig.mediaUrl(imagePath);
    final validNow = d['validNow'] != false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!validNow)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.adminCombosValidityOutside,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(l10n.adminCombosNameRu, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _nameRu,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) => setState(() => _metaDirty = true),
        ),
        const SizedBox(height: 12),
        Text(l10n.adminCombosDescriptionRu, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _descRu,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) => setState(() => _metaDirty = true),
        ),
        const SizedBox(height: 12),
        Text(l10n.adminCombosPriceRu, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _priceRu,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: l10n.adminCombosPriceRu,
          ),
          onChanged: (_) => setState(() => _metaDirty = true),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.adminCombosValidityTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.adminCombosDatesRange),
          subtitle: Text(
            _limitDates
                ? '${_fmtDate(_dateStart) ?? '…'} — ${_fmtDate(_dateEnd) ?? '…'}'
                : l10n.adminCombosDatesAny,
          ),
          value: _limitDates,
          onChanged: (v) => setState(() {
            _limitDates = v;
            if (v) {
              _dateStart ??= DateTime.now();
            } else {
              _dateStart = null;
              _dateEnd = null;
            }
            _metaDirty = true;
          }),
        ),
        if (_limitDates) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: _pickDateStart,
                child: Text(
                  '${l10n.adminCombosDateStart}: ${_fmtDate(_dateStart) ?? '—'}',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickDateEnd,
                child: Text(
                  '${l10n.adminCombosDateEnd}: ${_fmtDate(_dateEnd) ?? '—'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.adminCombosTimesRange),
          subtitle: Text(
            _limitTimes
                ? '${_fmtTime(_timeStart) ?? '…'} — ${_fmtTime(_timeEnd) ?? '…'}'
                : l10n.adminCombosTimesAny,
          ),
          value: _limitTimes,
          onChanged: (v) => setState(() {
            _limitTimes = v;
            if (v) {
              _timeStart ??= const TimeOfDay(hour: 10, minute: 0);
              _timeEnd ??= const TimeOfDay(hour: 22, minute: 0);
            } else {
              _timeStart = null;
              _timeEnd = null;
            }
            _metaDirty = true;
          }),
        ),
        if (_limitTimes) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: _pickTimeStart,
                child: Text(
                  '${l10n.adminCombosTimeStart}: ${_timeStart != null ? '${_timeStart!.hour.toString().padLeft(2, '0')}:${_timeStart!.minute.toString().padLeft(2, '0')}' : '—'}',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _pickTimeEnd,
                child: Text(
                  '${l10n.adminCombosTimeEnd}: ${_timeEnd != null ? '${_timeEnd!.hour.toString().padLeft(2, '0')}:${_timeEnd!.minute.toString().padLeft(2, '0')}' : '—'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (validNow)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.adminCombosValidityNow,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        FilledButton.icon(
          onPressed: (_savingMeta || !_metaDirty) ? null : () => _saveMeta(l10n),
          icon: _savingMeta
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(l10n.actionSave),
        ),
        const SizedBox(height: 24),
        Text(l10n.adminCombosImageSection, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
              aspectRatio: 16 / 9,
              child: RobustNetworkImage(
                url: imageUrl,
                fit: BoxFit.cover,
                errorWidget: const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          )
        else
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.adminCombosImageSection,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _uploadingImage ? null : () => _pickImage(l10n),
              child: Text(_uploadingImage ? '…' : l10n.adminMenuItemPickImage),
            ),
            if (imagePath != null && imagePath.isNotEmpty)
              OutlinedButton(
                onPressed: _uploadingImage ? null : () => _clearImage(l10n),
                child: Text(l10n.adminCombosRemoveImage),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.adminTv2EditorPickHintMulti,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(l10n.adminCombosEmpty)
        else
          ...items.map<Widget>((dynamic e) {
            if (e is! Map<String, dynamic>) return const SizedBox.shrink();
            final id = (e['id'] as num?)?.toInt() ?? 0;
            final nm = e['name'];
            final ru = nm is Map ? (nm['ru']?.toString() ?? '') : '';
            final mid = e['menuItemId']?.toString() ?? '';
            final qty = (e['quantity'] as num?)?.toInt() ?? 1;
            final row = _menuRowById(mid);
            final priceBlock = row != null
                ? '×$qty  ${row.displayPriceLineRu}'
                : mid;
            return ListTile(
              title: Text(ru),
              subtitle: Text(priceBlock, maxLines: 4, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _remove(id, l10n),
              ),
            );
          }),
      ],
    );
  }
}

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List? bytes;
}
