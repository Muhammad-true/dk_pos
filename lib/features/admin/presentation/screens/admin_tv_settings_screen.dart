import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/screens_admin_event.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/admin/data/local_tv_display_settings_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/presentation/screens/admin_tv_queue_board_designer_screen.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_screens_panel.dart';

/// Все настройки клиентского ТВ точки (раньше — только в `dk_digitial_menu/assets/.env`).
class AdminTvSettingsScreen extends StatefulWidget {
  const AdminTvSettingsScreen({super.key, this.maxBodyWidth = 900});

  final double maxBodyWidth;

  @override
  State<AdminTvSettingsScreen> createState() => _AdminTvSettingsScreenState();
}

class _AdminTvSettingsScreenState extends State<AdminTvSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _audioUploading = false;

  bool _queueOnly = false;
  bool _queueTts = true;
  bool _fakeDelivery = false;
  bool _announceAcceptedOnTv = false;
  double _queuePoll = 10;

  final _readyTtsCtrl = TextEditingController();
  final _readyTtsNoNumberCtrl = TextEditingController();
  final _acceptedTtsCtrl = TextEditingController();

  double _tvReadyVol = 1;
  double _tvTtsVol = 1;
  double _tvVideoVol = 0;
  final _readySoundCtrl = TextEditingController();
  LocalAudioSettings? _audioBaseline;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readySoundCtrl.dispose();
    _readyTtsCtrl.dispose();
    _readyTtsNoNumberCtrl.dispose();
    _acceptedTtsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tvRepo = context.read<LocalTvDisplaySettingsRepository>();
      final audioRepo = context.read<LocalAudioSettingsRepository>();
      final tv = await tvRepo.fetch();
      final audio = await audioRepo.fetch(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _queueOnly = tv.queueOnly;
        _queueTts = tv.queueTtsEnabled;
        _fakeDelivery = tv.fakeDeliveryEnabled;
        _announceAcceptedOnTv = tv.announceAcceptedOnTv;
        _queuePoll = tv.queuePollSeconds.toDouble();
        _readyTtsCtrl.text = tv.readyTtsPhrase;
        _readyTtsNoNumberCtrl.text = tv.readyTtsPhraseNoNumber;
        _acceptedTtsCtrl.text = tv.acceptedTtsPhrase;
        _tvReadyVol = audio.tvReadySoundVolume;
        _tvTtsVol = audio.tvTtsVolume;
        _tvVideoVol = audio.tvVideoVolume;
        _readySoundCtrl.text = audio.readySoundPath ?? '';
        _audioBaseline = audio;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<LocalTvDisplaySettingsRepository>().update(
            queueOnly: _queueOnly,
            queueTtsEnabled: _queueTts,
            fakeDeliveryEnabled: _fakeDelivery,
            queuePollSeconds: _queuePoll.round(),
            readyTtsPhrase: _readyTtsCtrl.text.trim(),
            readyTtsPhraseNoNumber: _readyTtsNoNumberCtrl.text.trim(),
            announceAcceptedOnTv: _announceAcceptedOnTv,
            acceptedTtsPhrase: _acceptedTtsCtrl.text.trim(),
          );
      final base = _audioBaseline;
      await context.read<LocalAudioSettingsRepository>().update(
            readySoundPath: _readySoundCtrl.text.trim(),
            kitchenSoundPath: base?.kitchenSoundPath,
            websiteOrderSoundPath: base?.websiteOrderSoundPath,
            kitchenTtsEnabled: base?.kitchenTtsEnabled,
            kitchenTtsRate: base?.kitchenTtsRate,
            kitchenTtsLocale: base?.kitchenTtsLocale,
            kitchenTtsVoiceName: base?.kitchenTtsVoiceName,
            tvReadySoundVolume: _tvReadyVol,
            tvTtsVolume: _tvTtsVol,
            tvVideoVolume: _tvVideoVol,
          );
      if (!mounted) return;
      _snack('Настройки ТВ сохранены. Телевизоры подхватят в течение ~1 мин.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickReadySound() async {
    setState(() => _audioUploading = true);
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
        withData: true,
      );
      if (pick == null || pick.files.isEmpty) return;
      final f = pick.files.single;
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Файл не содержит данных');
      }
      final uploaded = await context.read<UploadRepository>().uploadAudioBytes(
            bytes,
            f.name.isEmpty ? 'tv-ready.mp3' : f.name,
          );
      if (!mounted) return;
      setState(() => _readySoundCtrl.text = uploaded);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _audioUploading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openScreens() {
    final repo = context.read<ScreensAdminRepository>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => BlocProvider(
          create: (_) => ScreensAdminBloc(repo)..add(const ScreensLoadRequested()),
          child: Scaffold(
            appBar: AppBar(title: const Text('Экраны ТВ')),
            body: AdminScreensPanel(maxBodyWidth: widget.maxBodyWidth),
          ),
        ),
      ),
    );
  }

  void _openQueueDesigner() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: SafeArea(child: AdminTvQueueBoardDesignerScreen()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxBodyWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Настройки телевизора (клиентский экран)',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Сохраняется на сервере точки. Приложение `dk_digitial_menu` подхватывает без пересборки APK. '
              'IP сервера на самом ТВ задаётся при первом запуске (экран «Подключиться»).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Режим и очередь',
              child: Column(
                children: [
                  SwitchListTile(
                    value: _queueOnly,
                    onChanged: _saving ? null : (v) => setState(() => _queueOnly = v),
                    title: const Text('Только очередь на весь экран'),
                    subtitle: const Text('Аналог TV_QUEUE_ONLY=true в .env'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: _queueTts,
                    onChanged: _saving ? null : (v) => setState(() => _queueTts = v),
                    title: const Text('Озвучивать номер при «Готово»'),
                    subtitle: const Text('TV_QUEUE_TTS'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: _announceAcceptedOnTv,
                    onChanged: _saving ? null : (v) => setState(() => _announceAcceptedOnTv = v),
                    title: const Text('Озвучивать «Принят» на ТВ'),
                    subtitle: const Text('Когда повар нажимает «Принять» на кухне'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: _fakeDelivery,
                    onChanged: _saving ? null : (v) => setState(() => _fakeDelivery = v),
                    title: const Text('Демо-заказы доставки (ТВ4)'),
                    subtitle: const Text('TV_FAKE_DELIVERY_ENABLED — для тестов'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Обновление списка очереди: ${_queuePoll.round()} с',
                    style: theme.textTheme.titleSmall,
                  ),
                  Slider(
                    value: _queuePoll,
                    min: 3,
                    max: 60,
                    divisions: 57,
                    label: '${_queuePoll.round()} с',
                    onChanged: _saving ? null : (v) => setState(() => _queuePoll = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Тексты озвучки (TTS)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'В шаблоне укажите {number} — подставится номер заказа. '
                    'Не пишите «готов», «готово», «готова» — TTS на ТВ часто говорит «года». '
                    'Лучше: «Можно забирать», «На выдаче», «Забирайте заказ».',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _readyTtsCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Готово (с номером)',
                      hintText: 'Заказ номер {number}. Можно забирать!',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _readyTtsNoNumberCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Готово (без номера)',
                      hintText: 'Можно забирать заказ!',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _acceptedTtsCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Принят (с номером)',
                      hintText: 'Заказ номер {number}. Принят.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Звук на ТВ',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _readySoundCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Файл «готово» (uploads/audio/...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: (_saving || _audioUploading) ? null : _pickReadySound,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_audioUploading ? 'Загрузка…' : 'Загрузить звук'),
                  ),
                  const SizedBox(height: 12),
                  _VolumeRow(
                    label: 'Громкость сигнала «готово»',
                    value: _tvReadyVol,
                    onChanged: (v) => setState(() => _tvReadyVol = v),
                    enabled: !_saving,
                  ),
                  _VolumeRow(
                    label: 'Громкость TTS номера',
                    value: _tvTtsVol,
                    onChanged: (v) => setState(() => _tvTtsVol = v),
                    enabled: !_saving,
                  ),
                  _VolumeRow(
                    label: 'Громкость видео на слайдах',
                    value: _tvVideoVol,
                    onChanged: (v) => setState(() => _tvVideoVol = v),
                    enabled: !_saving,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Экраны и оформление',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Создайте экран типа ТВ4, добавьте слайд «Очередь заказов» — он появится в списке «Выберите ТВ».',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _openScreens,
                    icon: const Icon(Icons.tv_rounded),
                    label: const Text('Управление экранами ТВ'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _openQueueDesigner,
                    icon: const Icon(Icons.format_list_numbered_rounded),
                    label: const Text('Оформление доски очереди'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Сохранить настройки ТВ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${(value * 100).round()}%'),
        Slider(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
