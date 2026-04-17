import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/data/admin_screen_row.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/pos/presentation/customer_display_content_config.dart';
import 'package:dk_pos/features/pos/presentation/widgets/customer_display_idle_renderer.dart';

class CustomerDisplayDesignerScreen extends StatefulWidget {
  const CustomerDisplayDesignerScreen({
    super.key,
    required this.screen,
    this.readOnly = false,
  });

  final AdminScreenRow screen;
  final bool readOnly;

  @override
  State<CustomerDisplayDesignerScreen> createState() =>
      _CustomerDisplayDesignerScreenState();
}

class _CustomerDisplayDesignerScreenState
    extends State<CustomerDisplayDesignerScreen> {
  late final TextEditingController _headlineCtrl;
  late final TextEditingController _brandTitleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _rotationCtrl;
  late final TextEditingController _transitionCtrl;
  late CustomerDisplayContentConfig _config;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config =
        CustomerDisplayContentConfig.fromScreenConfig(widget.screen.config) ??
        CustomerDisplayContentConfig.fallback();
    _headlineCtrl = TextEditingController(text: _config.left.headline);
    _brandTitleCtrl = TextEditingController(text: _config.left.brandTitle);
    _descriptionCtrl = TextEditingController(text: _config.left.description);
    _rotationCtrl = TextEditingController(text: _config.rotationSeconds.toString());
    _transitionCtrl = TextEditingController(
      text: _config.transitionDurationMs.toString(),
    );
  }

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _brandTitleCtrl.dispose();
    _descriptionCtrl.dispose();
    _rotationCtrl.dispose();
    _transitionCtrl.dispose();
    super.dispose();
  }

  void _syncTopLevelControllers() {
    final rotation = int.tryParse(_rotationCtrl.text.trim()) ?? _config.rotationSeconds;
    final transition =
        int.tryParse(_transitionCtrl.text.trim()) ?? _config.transitionDurationMs;
    _config = _config.copyWith(
      left: _config.left.copyWith(
        headline: _headlineCtrl.text.trim(),
        brandTitle: _brandTitleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
      ),
      rotationSeconds: rotation.clamp(3, 60),
      transitionDurationMs: transition.clamp(200, 3000),
    );
  }

  Future<void> _pickLeftLogo() async {
    final selected = await _pickImage();
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final path = await context.read<UploadRepository>().uploadMenuImageBytes(
        selected.bytes,
        selected.name,
      );
      setState(() {
        _config = _config.copyWith(
          left: _config.left.copyWith(logoPath: path),
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCardImage(int index, {required bool forQr}) async {
    final selected = await _pickImage();
    if (selected == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final path = await context.read<UploadRepository>().uploadMenuImageBytes(
        selected.bytes,
        selected.name,
      );
      final updated = [..._config.cards];
      final card = updated[index];
      updated[index] = forQr
          ? card.copyWith(qrImagePath: path, qrMode: CustomerDisplayQrMode.image)
          : card.copyWith(logoPath: path);
      setState(() => _config = _config.copyWith(cards: updated));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_PickedFile?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) return null;
    return _PickedFile(name: file.name, bytes: file.bytes!);
  }

  void _addCard() {
    final updated = [..._config.cards];
    updated.add(
      CustomerDisplayPromoCardConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: 'Новая карточка',
        body: '',
        animation: CustomerDisplayCardAnimation.slideUp,
      ),
    );
    setState(() => _config = _config.copyWith(cards: updated));
  }

  void _deleteCard(int index) {
    final updated = [..._config.cards]..removeAt(index);
    setState(() => _config = _config.copyWith(cards: updated));
  }

  void _moveCard(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _config.cards.length) return;
    final updated = [..._config.cards];
    final item = updated.removeAt(index);
    updated.insert(newIndex, item);
    setState(() => _config = _config.copyWith(cards: updated));
  }

  Future<void> _save() async {
    _syncTopLevelControllers();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final base = Map<String, dynamic>.from(widget.screen.config ?? const {});
      base['customerDisplay'] = _config.toJson();
      final updated = await context.read<ScreensAdminRepository>().updateScreen(
        widget.screen.id,
        {
          'name': widget.screen.name,
          'slug': widget.screen.slug,
          'type': 'customer_display',
          'sort_order': widget.screen.sortOrder,
          'is_active': widget.screen.isActive ? 1 : 0,
          'config': base,
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Конструктор клиентского экрана сохранен')),
      );
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final isWide = w >= 1200;
    final phoneLayout = w < 600;

    Widget screen() {
      final editor = _DesignerEditorPane(
        headlineCtrl: _headlineCtrl,
        brandTitleCtrl: _brandTitleCtrl,
        descriptionCtrl: _descriptionCtrl,
        rotationCtrl: _rotationCtrl,
        transitionCtrl: _transitionCtrl,
        config: _config,
        readOnly: widget.readOnly,
        saving: _saving,
        compact: phoneLayout,
        onChanged: () {
          _syncTopLevelControllers();
          setState(() {});
        },
        onPickLeftLogo: _pickLeftLogo,
        onConfigChanged: (config) => setState(() => _config = config),
        onAddCard: _addCard,
        onDeleteCard: _deleteCard,
        onMoveCard: _moveCard,
        onPickCardLogo: (index) => _pickCardImage(index, forQr: false),
        onPickCardQr: (index) => _pickCardImage(index, forQr: true),
      );

      final preview = DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFF111318)),
        child: Padding(
          padding: EdgeInsets.all(phoneLayout ? 8 : 20),
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(phoneLayout ? 16 : 24),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF120A0A),
                        Color(0xFF111318),
                        Color(0xFF090909),
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const SizedBox.expand(),
                      Padding(
                        padding: EdgeInsets.all(phoneLayout ? 12 : 28),
                        child: CustomerDisplayIdleRenderer(config: _config),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      return Scaffold(
        appBar: AppBar(
          toolbarHeight: phoneLayout ? 48 : kToolbarHeight,
          title: Text(
            widget.readOnly
                ? 'Предпросмотр клиентского экрана'
                : 'Конструктор клиентского экрана',
          ),
          actions: [
            if (!widget.readOnly)
              Padding(
                padding: EdgeInsets.only(right: phoneLayout ? 6 : 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: phoneLayout
                        ? VisualDensity.compact
                        : VisualDensity.standard,
                    padding: phoneLayout
                        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                        : null,
                  ),
                  onPressed: _saving ? null : _save,
                  icon: Icon(
                    Icons.save_rounded,
                    size: phoneLayout ? 18 : 24,
                  ),
                  label: const Text('Сохранить'),
                ),
              ),
          ],
        ),
        body: isWide
            ? Row(
                children: [
                  Expanded(flex: 5, child: editor),
                  Expanded(flex: 6, child: preview),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 6, child: editor),
                  Expanded(flex: 5, child: preview),
                ],
              ),
      );
    }

    if (!phoneLayout) return screen();

    final systemFactor = mq.textScaler.scale(1.0);
    final phoneFactor = (systemFactor * 0.78).clamp(0.65, 1.12);

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(phoneFactor)),
      child: Theme(
        data: Theme.of(context).copyWith(
          visualDensity: VisualDensity.compact,
        ),
        child: screen(),
      ),
    );
  }
}

class _DesignerEditorPane extends StatelessWidget {
  const _DesignerEditorPane({
    required this.headlineCtrl,
    required this.brandTitleCtrl,
    required this.descriptionCtrl,
    required this.rotationCtrl,
    required this.transitionCtrl,
    required this.config,
    required this.readOnly,
    required this.saving,
    this.compact = false,
    required this.onChanged,
    required this.onPickLeftLogo,
    required this.onConfigChanged,
    required this.onAddCard,
    required this.onDeleteCard,
    required this.onMoveCard,
    required this.onPickCardLogo,
    required this.onPickCardQr,
  });

  final TextEditingController headlineCtrl;
  final TextEditingController brandTitleCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController rotationCtrl;
  final TextEditingController transitionCtrl;
  final CustomerDisplayContentConfig config;
  final bool readOnly;
  final bool saving;
  final bool compact;
  final VoidCallback onChanged;
  final Future<void> Function() onPickLeftLogo;
  final ValueChanged<CustomerDisplayContentConfig> onConfigChanged;
  final VoidCallback onAddCard;
  final void Function(int index) onDeleteCard;
  final void Function(int index, int delta) onMoveCard;
  final Future<void> Function(int index) onPickCardLogo;
  final Future<void> Function(int index) onPickCardQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact ? 10.0 : 16.0;
    final gap = compact ? 8.0 : 12.0;
    final sectionGap = compact ? 16.0 : 20.0;
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Text('Левая часть экрана', style: theme.textTheme.titleLarge),
        SizedBox(height: gap),
        TextField(
          controller: headlineCtrl,
          onChanged: (_) => onChanged(),
          enabled: !readOnly,
          decoration: const InputDecoration(
            labelText: 'Верхний заголовок',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: gap),
        TextField(
          controller: brandTitleCtrl,
          onChanged: (_) => onChanged(),
          enabled: !readOnly,
          decoration: const InputDecoration(
            labelText: 'Название бренда',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: gap),
        TextField(
          controller: descriptionCtrl,
          onChanged: (_) => onChanged(),
          enabled: !readOnly,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Описание',
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: gap),
        Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: compact ? 6 : 8,
          children: [
            if (!readOnly)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity:
                      compact ? VisualDensity.compact : VisualDensity.standard,
                ),
                onPressed: saving ? null : onPickLeftLogo,
                icon: Icon(
                  Icons.image_outlined,
                  size: compact ? 18 : 24,
                ),
                label: const Text('Загрузить логотип слева'),
              ),
            if ((config.left.logoPath ?? '').trim().isNotEmpty)
              SelectableText(
                config.left.logoPath!,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        SizedBox(height: sectionGap),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: rotationCtrl,
                onChanged: (_) => onChanged(),
                enabled: !readOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Смена карточек, сек',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: TextField(
                controller: transitionCtrl,
                onChanged: (_) => onChanged(),
                enabled: !readOnly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Длительность анимации, ms',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 18 : 24),
        Row(
          children: [
            Expanded(child: Text('Карточки', style: theme.textTheme.titleLarge)),
            if (!readOnly)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity:
                      compact ? VisualDensity.compact : VisualDensity.standard,
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                      : null,
                ),
                onPressed: saving ? null : onAddCard,
                icon: Icon(
                  Icons.add_rounded,
                  size: compact ? 18 : 24,
                ),
                label: const Text('Добавить карточку'),
              ),
          ],
        ),
        SizedBox(height: gap),
        for (var i = 0; i < config.cards.length; i++)
          _CardEditorTile(
            index: i,
            card: config.cards[i],
            readOnly: readOnly,
            compact: compact,
            isFirst: i == 0,
            isLast: i == config.cards.length - 1,
            onChanged: (card) {
              final updated = [...config.cards];
              updated[i] = card;
              onConfigChanged(config.copyWith(cards: updated));
            },
            onDelete: () => onDeleteCard(i),
            onMoveUp: () => onMoveCard(i, -1),
            onMoveDown: () => onMoveCard(i, 1),
            onPickLogo: () => onPickCardLogo(i),
            onPickQr: () => onPickCardQr(i),
          ),
      ],
    );
  }
}

class _CardEditorTile extends StatelessWidget {
  const _CardEditorTile({
    required this.index,
    required this.card,
    required this.readOnly,
    this.compact = false,
    required this.isFirst,
    required this.isLast,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onPickLogo,
    required this.onPickQr,
  });

  final int index;
  final CustomerDisplayPromoCardConfig card;
  final bool readOnly;
  final bool compact;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<CustomerDisplayPromoCardConfig> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Future<void> Function() onPickLogo;
  final Future<void> Function() onPickQr;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 20.0 : 24.0;
    return Card(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Карточка ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!readOnly) ...[
                  IconButton(
                    visualDensity:
                        compact ? VisualDensity.compact : VisualDensity.standard,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 36, minHeight: 36)
                        : null,
                    padding: compact ? EdgeInsets.zero : null,
                    onPressed: isFirst ? null : onMoveUp,
                    icon: Icon(Icons.arrow_upward_rounded, size: iconSize),
                  ),
                  IconButton(
                    visualDensity:
                        compact ? VisualDensity.compact : VisualDensity.standard,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 36, minHeight: 36)
                        : null,
                    padding: compact ? EdgeInsets.zero : null,
                    onPressed: isLast ? null : onMoveDown,
                    icon: Icon(Icons.arrow_downward_rounded, size: iconSize),
                  ),
                  IconButton(
                    visualDensity:
                        compact ? VisualDensity.compact : VisualDensity.standard,
                    constraints: compact
                        ? const BoxConstraints(minWidth: 36, minHeight: 36)
                        : null,
                    padding: compact ? EdgeInsets.zero : null,
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, size: iconSize),
                  ),
                ],
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            TextFormField(
              initialValue: card.title,
              enabled: !readOnly,
              onChanged: (v) => onChanged(card.copyWith(title: v)),
              decoration: const InputDecoration(
                labelText: 'Заголовок',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            TextFormField(
              initialValue: card.body,
              enabled: !readOnly,
              maxLines: 3,
              onChanged: (v) => onChanged(card.copyWith(body: v)),
              decoration: const InputDecoration(
                labelText: 'Текст карточки',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            DropdownButtonFormField<CustomerDisplayQrMode>(
              initialValue: card.qrMode,
              onChanged: readOnly
                  ? null
                  : (value) {
                      if (value != null) onChanged(card.copyWith(qrMode: value));
                    },
              items: const [
                DropdownMenuItem(
                  value: CustomerDisplayQrMode.generated,
                  child: Text('QR из текста/ссылки'),
                ),
                DropdownMenuItem(
                  value: CustomerDisplayQrMode.image,
                  child: Text('QR как картинка'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Тип QR',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            if (card.qrMode == CustomerDisplayQrMode.generated)
              TextFormField(
                initialValue: card.qrText ?? '',
                enabled: !readOnly,
                onChanged: (v) => onChanged(card.copyWith(qrText: v)),
                decoration: const InputDecoration(
                  labelText: 'Текст/ссылка для QR',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Wrap(
                spacing: compact ? 6 : 8,
                runSpacing: compact ? 6 : 8,
                children: [
                  if (!readOnly)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                      ),
                      onPressed: onPickQr,
                      icon: Icon(
                        Icons.qr_code_2_rounded,
                        size: compact ? 18 : 24,
                      ),
                      label: const Text('Загрузить картинку QR'),
                    ),
                  if ((card.qrImagePath ?? '').trim().isNotEmpty)
                    SelectableText(
                      card.qrImagePath!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            SizedBox(height: compact ? 6 : 8),
            DropdownButtonFormField<CustomerDisplayCardAnimation>(
              initialValue: card.animation,
              onChanged: readOnly
                  ? null
                  : (value) {
                      if (value != null) onChanged(card.copyWith(animation: value));
                    },
              items: const [
                DropdownMenuItem(
                  value: CustomerDisplayCardAnimation.slideUp,
                  child: Text('Анимация: снизу вверх'),
                ),
                DropdownMenuItem(
                  value: CustomerDisplayCardAnimation.slideLeft,
                  child: Text('Анимация: справа налево'),
                ),
                DropdownMenuItem(
                  value: CustomerDisplayCardAnimation.fade,
                  child: Text('Анимация: fade'),
                ),
                DropdownMenuItem(
                  value: CustomerDisplayCardAnimation.scale,
                  child: Text('Анимация: scale'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Анимация карточки',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: [
                if (!readOnly)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                    ),
                    onPressed: onPickLogo,
                    icon: Icon(
                      Icons.account_balance_outlined,
                      size: compact ? 18 : 24,
                    ),
                    label: const Text('Загрузить логотип/иконку'),
                  ),
                if ((card.logoPath ?? '').trim().isNotEmpty)
                  SelectableText(
                    card.logoPath!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            TextFormField(
              initialValue: card.footer ?? '',
              enabled: !readOnly,
              onChanged: (v) => onChanged(card.copyWith(footer: v)),
              decoration: const InputDecoration(
                labelText: 'Нижний текст',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            TextFormField(
              initialValue: card.phone ?? '',
              enabled: !readOnly,
              onChanged: (v) => onChanged(card.copyWith(phone: v)),
              decoration: const InputDecoration(
                labelText: 'Телефон',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedFile {
  const _PickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}
