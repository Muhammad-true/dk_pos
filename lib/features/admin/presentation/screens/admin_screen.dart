import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_event.dart';
import 'package:dk_pos/features/admin/data/app_version_row.dart';
import 'package:dk_pos/features/admin/data/app_versions_repository.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_repository.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/data/users_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_catalog_hub.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_kitchen_ops_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_sales_reports_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_section_card.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_users_panel.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/shared/shared.dart';
import 'package:dk_pos/theme/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _index = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _logout(BuildContext context) {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final user = context.watch<AuthBloc>().state.user;
    final titles = [
      l10n.adminNavOverview,
      l10n.adminNavUsers,
      l10n.adminNavCatalog,
      l10n.adminNavOrders,
      'Смены и кухня',
      l10n.adminNavSettings,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final root = WindowLayout(width: constraints.maxWidth);
        final narrowActions = constraints.maxWidth < 420;

        final body = _AdminTabBody(
          index: _index,
          l10n: l10n,
          maxBodyWidth: root.adminBodyMaxWidth(constraints.maxWidth),
        );

        final content = AnimatedSwitcher(
          duration: AppMotion.medium,
          switchInCurve: AppMotion.tabSwitch,
          switchOutCurve: AppMotion.tabSwitch,
          transitionBuilder: adminTabTransition,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            fit: StackFit.passthrough,
            children: [...previous, if (current != null) current],
          ),
          child: KeyedSubtree(key: ValueKey<int>(_index), child: body),
        );

        return Scaffold(
          key: _scaffoldKey,
          drawer: _AdminNavDrawer(
            index: _index,
            l10n: l10n,
            onNavTap: (i) {
              setState(() => _index = i);
              Navigator.of(context).pop();
            },
            onLogout: () {
              Navigator.of(context).pop();
              _logout(context);
            },
          ),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: l10n.tooltipAppMenu,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Text(titles[_index], overflow: TextOverflow.ellipsis),
            actions: [
              if (user != null)
                narrowActions
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            user.username.isNotEmpty
                                ? user.username.substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: Chip(
                            avatar: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                              child: Text(
                                user.username.isNotEmpty
                                    ? user.username
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            label: Text(user.roleLabel(l10n)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
            ],
          ),
          body: content,
        );
      },
    );
  }
}

class _AdminNavDrawer extends StatelessWidget {
  const _AdminNavDrawer({
    required this.index,
    required this.l10n,
    required this.onNavTap,
    required this.onLogout,
  });

  final int index;
  final AppLocalizations l10n;
  final ValueChanged<int> onNavTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = context.watch<AuthBloc>().state.user;
    final mq = MediaQuery.sizeOf(context);

    Widget sectionHeading(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(
          text.toUpperCase(),
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    Widget navDestination({
      required int i,
      required IconData iconOutlined,
      required IconData iconFilled,
      required String label,
      required String hint,
    }) {
      final selected = index == i;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: selected
              ? scheme.secondaryContainer.withValues(alpha: 0.65)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onNavTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? iconFilled : iconOutlined,
                    size: 26,
                    color: selected ? scheme.onSecondaryContainer : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: textTheme.bodySmall?.copyWith(
                            color: selected
                                ? scheme.onSecondaryContainer.withValues(
                                    alpha: 0.85,
                                  )
                                : scheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSecondaryContainer.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Drawer(
      width: math.min(320, mq.width * 0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 42,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.adminTitle,
                      style: textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.roleLabel(l10n),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                children: [
                  sectionHeading(l10n.adminDrawerSectionNav),
                  navDestination(
                    i: 0,
                    iconOutlined: Icons.space_dashboard_outlined,
                    iconFilled: Icons.space_dashboard_rounded,
                    label: l10n.adminNavOverview,
                    hint: l10n.adminNavOverviewDrawerHint,
                  ),
                  navDestination(
                    i: 1,
                    iconOutlined: Icons.people_outline_rounded,
                    iconFilled: Icons.people_rounded,
                    label: l10n.adminNavUsers,
                    hint: l10n.adminNavUsersDrawerHint,
                  ),
                  navDestination(
                    i: 2,
                    iconOutlined: Icons.restaurant_menu_outlined,
                    iconFilled: Icons.restaurant_menu_rounded,
                    label: l10n.adminNavCatalog,
                    hint: l10n.adminNavCatalogDrawerHint,
                  ),
                  navDestination(
                    i: 3,
                    iconOutlined: Icons.receipt_long_outlined,
                    iconFilled: Icons.receipt_long_rounded,
                    label: l10n.adminNavOrders,
                    hint: l10n.adminNavOrdersDrawerHint,
                  ),
                  navDestination(
                    i: 4,
                    iconOutlined: Icons.schedule_outlined,
                    iconFilled: Icons.schedule_rounded,
                    label: 'Смены и кухня',
                    hint: 'Смены пользователей и эффективность кухни',
                  ),
                  navDestination(
                    i: 5,
                    iconOutlined: Icons.settings_outlined,
                    iconFilled: Icons.settings_rounded,
                    label: l10n.adminNavSettings,
                    hint: l10n.adminNavSettingsDrawerHint,
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text(
                      l10n.adminDrawerSignOutHint,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FilledButton.tonalIcon(
                      onPressed: onLogout,
                      icon: Icon(Icons.logout_rounded, color: scheme.error),
                      label: Text(l10n.actionExit),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: scheme.error,
                        backgroundColor: scheme.errorContainer.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTabBody extends StatelessWidget {
  const _AdminTabBody({
    required this.index,
    required this.l10n,
    required this.maxBodyWidth,
  });

  final int index;
  final AppLocalizations l10n;
  final double maxBodyWidth;

  @override
  Widget build(BuildContext context) {
    if (index == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: BlocProvider(
          create: (_) =>
              UsersAdminBloc(context.read<UsersAdminRepository>())
                ..add(const UsersLoadRequested()),
          child: AdminUsersPanel(maxBodyWidth: maxBodyWidth),
        ),
      );
    }

    if (index == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  CatalogAdminBloc(context.read<CatalogAdminRepository>())
                    ..add(const CatalogLoadRequested()),
            ),
            BlocProvider(
              create: (_) =>
                  MenuItemsAdminBloc(context.read<MenuItemsAdminRepository>())
                    ..add(const MenuItemsLoadRequested()),
            ),
          ],
          child: AdminCatalogHub(l10n: l10n, maxBodyWidth: maxBodyWidth),
        ),
      );
    }

    if (index == 3) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: AdminSalesReportsPanel(maxBodyWidth: maxBodyWidth),
      );
    }

    if (index == 4) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: AdminKitchenOpsPanel(maxBodyWidth: maxBodyWidth),
      );
    }

    if (index == 5) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBodyWidth),
          child: _AdminSettingsPanel(l10n: l10n),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBodyWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: switch (index) {
            0 => AdminSectionCard(
              icon: Icons.insights_rounded,
              title: l10n.adminDashboardHeadline,
              body: l10n.adminDashboardBody,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _AdminSettingsPanel extends StatefulWidget {
  const _AdminSettingsPanel({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_AdminSettingsPanel> createState() => _AdminSettingsPanelState();
}

class _AdminSettingsPanelState extends State<_AdminSettingsPanel> {
  late Future<List<AppVersionRow>> _versionsFuture;
  late final TextEditingController _readySoundCtrl;
  late final TextEditingController _kitchenSoundCtrl;
  late final TextEditingController _kitchenTtsRateCtrl;
  late final TextEditingController _kitchenTtsLocaleCtrl;
  late final TextEditingController _kitchenTtsVoiceNameCtrl;
  bool _audioLoading = false;
  bool _audioSaving = false;
  bool _audioUploading = false;
  bool _kitchenTtsEnabled = true;

  @override
  void initState() {
    super.initState();
    _versionsFuture = context.read<AppVersionsRepository>().fetchVersions();
    _readySoundCtrl = TextEditingController();
    _kitchenSoundCtrl = TextEditingController();
    _kitchenTtsRateCtrl = TextEditingController(text: '0.48');
    _kitchenTtsLocaleCtrl = TextEditingController(text: 'ru-RU');
    _kitchenTtsVoiceNameCtrl = TextEditingController();
    _loadAudioSettings();
  }

  @override
  void dispose() {
    _readySoundCtrl.dispose();
    _kitchenSoundCtrl.dispose();
    _kitchenTtsRateCtrl.dispose();
    _kitchenTtsLocaleCtrl.dispose();
    _kitchenTtsVoiceNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = context.read<AppVersionsRepository>().fetchVersions();
    setState(() => _versionsFuture = future);
    await future;
  }

  Future<void> _loadAudioSettings() async {
    setState(() => _audioLoading = true);
    try {
      final settings = await context
          .read<LocalAudioSettingsRepository>()
          .fetch();
      if (!mounted) return;
      _readySoundCtrl.text = settings.readySoundPath ?? '';
      _kitchenSoundCtrl.text = settings.kitchenSoundPath ?? '';
      _kitchenTtsRateCtrl.text = settings.kitchenTtsRate.toStringAsFixed(2);
      _kitchenTtsLocaleCtrl.text = settings.kitchenTtsLocale;
      _kitchenTtsVoiceNameCtrl.text = settings.kitchenTtsVoiceName ?? '';
      _kitchenTtsEnabled = settings.kitchenTtsEnabled;
    } catch (_) {
      // Не блокируем страницу настроек, если этот блок пока не настроен.
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _pickAndUploadSound(TextEditingController target) async {
    setState(() => _audioUploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
        withData: true,
      );
      final file = (picked != null && picked.files.isNotEmpty)
          ? picked.files.first
          : null;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Файл не содержит данных');
      }
      if (!mounted) return;
      final path = await context.read<UploadRepository>().uploadAudioBytes(
        bytes,
        file.name,
      );
      if (!mounted) return;
      target.text = path;
      messenger.showSnackBar(const SnackBar(content: Text('Звук загружен')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _audioUploading = false);
    }
  }

  Future<void> _saveAudioSettings() async {
    setState(() => _audioSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ttsRate = double.tryParse(
        _kitchenTtsRateCtrl.text.trim().replaceAll(',', '.'),
      );
      if (ttsRate == null || ttsRate < 0.2 || ttsRate > 1.2) {
        throw Exception('Скорость TTS должна быть от 0.20 до 1.20');
      }
      await context.read<LocalAudioSettingsRepository>().update(
        readySoundPath: _readySoundCtrl.text.trim(),
        kitchenSoundPath: _kitchenSoundCtrl.text.trim().isEmpty
            ? null
            : _kitchenSoundCtrl.text.trim(),
        kitchenTtsEnabled: _kitchenTtsEnabled,
        kitchenTtsRate: ttsRate,
        kitchenTtsLocale: _kitchenTtsLocaleCtrl.text.trim(),
        kitchenTtsVoiceName: _kitchenTtsVoiceNameCtrl.text.trim().isEmpty
            ? null
            : _kitchenTtsVoiceNameCtrl.text.trim(),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Настройки звука сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _audioSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lang = context.watch<LocaleBloc>().state.locale.languageCode;

    void setLang(String code) {
      context.read<LocaleBloc>().add(LocaleChanged(Locale(code)));
    }

    Widget languageTile(String code, String title) {
      final selected = lang == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected
              ? scheme.secondaryContainer.withValues(alpha: 0.55)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setLang(code),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 24,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminDrawerSectionLanguage,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminNavSettingsDrawerHint,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          languageTile('ru', l10n.languageRu),
          languageTile('en', l10n.languageEn),
          languageTile('tg', l10n.languageTg),
          const SizedBox(height: 28),
          Text(
            'Версии приложений',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь видно версии backend, POS и APK меню. Эта же таблица станет основой для будущих удаленных обновлений.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<AppVersionRow>>(
            future: _versionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return AdminSectionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Не удалось загрузить версии',
                  body: snapshot.error.toString(),
                );
              }
              final versions = snapshot.data ?? const <AppVersionRow>[];
              return Column(
                children: [
                  for (final item in versions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VersionCardEditor(
                        item: item,
                        onSaved: () => _reload(),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Озвучка очереди',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Звук "Заказ готов" для отдельного экрана очереди (TV_QUEUE_ONLY=true).',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _readySoundCtrl,
                    enabled: !_audioLoading,
                    decoration: const InputDecoration(
                      labelText: 'Путь звука (uploads/audio/...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_audioUploading || _audioSaving)
                              ? null
                              : () => _pickAndUploadSound(_readySoundCtrl),
                          icon: _audioUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          label: const Text('Загрузить звук'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              (_audioLoading || _audioUploading || _audioSaving)
                              ? null
                              : _saveAudioSettings,
                          icon: _audioSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Кухня: звук + TTS',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _kitchenSoundCtrl,
                    enabled: !_audioLoading,
                    decoration: const InputDecoration(
                      labelText: 'Путь кухонного звука (uploads/audio/...)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: (_audioUploading || _audioSaving)
                        ? null
                        : () => _pickAndUploadSound(_kitchenSoundCtrl),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Загрузить звук кухни'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _kitchenTtsEnabled,
                    onChanged: (_audioLoading || _audioSaving)
                        ? null
                        : (v) => setState(() => _kitchenTtsEnabled = v),
                    title: const Text('Включить озвучку TTS на кухне'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _kitchenTtsRateCtrl,
                    enabled: !_audioLoading,
                    decoration: const InputDecoration(
                      labelText: 'Скорость TTS (0.20 - 1.20)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _kitchenTtsLocaleCtrl,
                    enabled: !_audioLoading,
                    decoration: const InputDecoration(
                      labelText: 'Язык/локаль TTS (пример: ru-RU)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _kitchenTtsVoiceNameCtrl,
                    enabled: !_audioLoading,
                    decoration: const InputDecoration(
                      labelText: 'Имя голоса TTS (необязательно)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCardEditor extends StatefulWidget {
  const _VersionCardEditor({required this.item, required this.onSaved});

  final AppVersionRow item;
  final Future<void> Function() onSaved;

  @override
  State<_VersionCardEditor> createState() => _VersionCardEditorState();
}

class _VersionCardEditorState extends State<_VersionCardEditor> {
  late final TextEditingController _displayCtrl;
  late final TextEditingController _currentCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _notesCtrl;
  late bool _isMandatory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayCtrl = TextEditingController(text: widget.item.displayName);
    _currentCtrl = TextEditingController(
      text: widget.item.currentVersion ?? '',
    );
    _targetCtrl = TextEditingController(text: widget.item.targetVersion ?? '');
    _minCtrl = TextEditingController(
      text: widget.item.minSupportedVersion ?? '',
    );
    _urlCtrl = TextEditingController(text: widget.item.downloadUrl ?? '');
    _notesCtrl = TextEditingController(text: widget.item.releaseNotes ?? '');
    _isMandatory = widget.item.isMandatory;
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    _minCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppVersionsRepository>().updateVersion(
        widget.item.appKey,
        displayName: _displayCtrl.text.trim(),
        currentVersion: _currentCtrl.text.trim(),
        targetVersion: _targetCtrl.text.trim(),
        minSupportedVersion: _minCtrl.text.trim(),
        downloadUrl: _urlCtrl.text.trim(),
        releaseNotes: _notesCtrl.text.trim(),
        isMandatory: _isMandatory,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Версия "${widget.item.appKey}" обновлена')),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final updatedAt =
        widget.item.updatedAt?.toLocal().toString() ?? 'неизвестно';

    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ключ: ${widget.item.appKey} | обновлено: $updatedAt',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isMandatory,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _isMandatory = v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: _displayCtrl, decoration: deco('Название')),
            const SizedBox(height: 10),
            TextField(
              controller: _currentCtrl,
              decoration: deco('Текущая версия'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _targetCtrl,
              decoration: deco('Целевая версия'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _minCtrl,
              decoration: deco('Минимально поддерживаемая версия'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              decoration: deco('Ссылка на обновление'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: deco('Примечания к релизу'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
