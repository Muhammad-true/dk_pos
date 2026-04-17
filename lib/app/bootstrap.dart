import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dk_digitial_menu/core/app_config.dart' as dm_app_config;

import 'package:dk_pos/app/app_update_info.dart';
import 'package:dk_pos/core/cache/pos_local_cache_cleanup.dart';
import 'package:dk_pos/app/dk_pos_app.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/app/router/app_router.dart' show AppRouter;
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/config/server_endpoint_store.dart';
import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/dio_factory.dart';
import 'package:dk_pos/data/network/dio_http_client.dart';
import 'package:dk_pos/data/storage/shared_preferences_key_value_store.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/auth/data/auth_remote_data_source_impl.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';
import 'package:dk_pos/features/auth/data/local_shift_repository.dart';
import 'package:dk_pos/features/cart/bloc/cart_bloc.dart';
import 'package:dk_pos/features/cart/data/cart_repository.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_remote_data_source_impl.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_repository.dart';
import 'package:dk_pos/features/admin/data/app_versions_remote_data_source_impl.dart';
import 'package:dk_pos/features/admin/data/app_versions_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_remote_data_source_impl.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_display_preview_repository.dart';
import 'package:dk_pos/features/admin/data/screens_admin_remote_data_source_impl.dart';
import 'package:dk_pos/features/admin/data/screens_admin_repository.dart';
import 'package:dk_pos/features/admin/data/theme_admin_repository.dart';
import 'package:dk_pos/features/admin/data/menu_units_repository.dart';
import 'package:dk_pos/features/admin/data/combos_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';
import 'package:dk_pos/features/admin/data/users_admin_remote_data_source_impl.dart';
import 'package:dk_pos/features/admin/data/users_admin_repository.dart';
import 'package:dk_pos/features/admin/data/kitchen_stations_repository.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/menu/data/menu_remote_data_source_impl.dart';
import 'package:dk_pos/features/menu/data/menu_repository.dart';
import 'package:dk_pos/features/orders/data/local_orders_repository.dart';
import 'package:dk_pos/features/payments/data/local_payments_repository.dart';
import 'package:dk_pos/features/pos/presentation/screens/customer_display_window.dart';
import 'package:dk_pos/theme/app_theme.dart';

String _formatDotenvError(Object e) =>
    'Не удалось загрузить assets/.env (нужен API_BASE_URL и др.). '
    'Переустановите сборку или добавьте файл в проект.\n\n$e';

String _formatStartupError(Object e) {
  final origin = AppConfig.apiOrigin;
  if (e is TimeoutException) {
    return 'Сервер не ответил вовремя ($origin). '
        'Проверьте сеть и что backend запущен.\n\nТехнически: $e';
  }
  if (e is ApiException) {
    final msg = e.message;
    final lower = msg.toLowerCase();
    final isConn = e.statusCode == 0 ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable');
    if (isConn) {
      return 'Нет связи с сервером $origin.\n'
          'Убедитесь, что backend запущен, IP и порт верны, firewall не блокирует порт.\n\n'
          'Детали: $msg';
    }
    return 'Ошибка API (код ${e.statusCode}): $msg';
  }
  final t = e.toString();
  final lower = t.toLowerCase();
  if (lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('socketexception')) {
    return 'Нет связи с сервером $origin.\n'
        'Проверьте сеть и адрес в assets/.env или введите IP ниже.\n\n'
        'Детали: $t';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'Превышено время ожидания ответа от $origin.\n\nДетали: $t';
  }
  return t;
}

Future<void> bootstrap([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFE4002B),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ошибка интерфейса',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SelectableText(details.exceptionAsString()),
              ],
            ),
          ),
        ),
      ),
    );
  };
  fvp.registerWith(
    options: {
      // macOS/iOS/Android остаются на штатном video_player; на Windows у него нет нативного бэкенда.
      'platforms': ['windows', 'linux'],
    },
  );
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.settings_outlined,
                        size: 48,
                        color: Color(0xFFE4002B),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Нет файла конфигурации',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _formatDotenvError(e),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  final customerWindowPayload = _tryParseSubWindowArgs(args);
  if (customerWindowPayload != null &&
      customerWindowPayload['type'] == 'customer_display') {
    final windowId = int.parse(args[1]);
    runApp(
      CustomerDisplayWindowApp(
        windowController: WindowController.fromWindowId(windowId),
        arguments: customerWindowPayload,
      ),
    );
    return;
  }

  final savedOrigin = await ServerEndpointStore.read();
  if (savedOrigin != null && savedOrigin.isNotEmpty) {
    AppConfig.setApiOriginOverride(savedOrigin);
    dm_app_config.AppConfig.setApiOriginOverride(savedOrigin);
  }

  runApp(const _PosBootstrapGate());
}

Map<String, dynamic>? _tryParseSubWindowArgs(List<String> args) {
  if (args.length < 3 || args.first != 'multi_window') {
    return null;
  }
  try {
    final decoded = jsonDecode(args[2]);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return null;
  }
  return null;
}

class _PosBootstrapGate extends StatefulWidget {
  const _PosBootstrapGate();

  @override
  State<_PosBootstrapGate> createState() => _PosBootstrapGateState();
}

class _PosBootstrapGateState extends State<_PosBootstrapGate> {
  _BootPayload? _payload;
  final _ipController = TextEditingController();
  bool _loading = true;
  String? _error;
  AppUpdateInfo? _blockingUpdate;

  @override
  void initState() {
    super.initState();
    _ipController.text = AppConfig.isLocalhostApi ? '' : AppConfig.apiOrigin;
    _init();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kv = await SharedPreferencesKeyValueStore.create();
      final dio = createDio();
      final http = DioHttpClient(dio);
      await _ensureApiAvailable(http);
      final authRemote = AuthRemoteDataSourceImpl(http);
      final menuRemote = MenuRemoteDataSourceImpl(http);
      final usersAdminRemote = UsersAdminRemoteDataSourceImpl(http);
      final catalogAdminRemote = CatalogAdminRemoteDataSourceImpl(http);
      final appVersionsRemote = AppVersionsRemoteDataSourceImpl(http);
      final menuItemsAdminRemote = MenuItemsAdminRemoteDataSourceImpl(http);
      final screensAdminRemote = ScreensAdminRemoteDataSourceImpl(http);

      final authRepo = AuthRepository(kv: kv, remote: authRemote, http: http);
      final shiftRepo = LocalShiftRepository(http);
      final menuRepo = MenuRepository(menuRemote);
      final usersAdminRepo = UsersAdminRepository(usersAdminRemote);
      final kitchenStationsRepo = KitchenStationsRepository(http);
      final catalogAdminRepo = CatalogAdminRepository(catalogAdminRemote);
      final appVersionsRepo = AppVersionsRepository(appVersionsRemote);
      final menuItemsAdminRepo = MenuItemsAdminRepository(menuItemsAdminRemote);
      final screensAdminRepo = ScreensAdminRepository(screensAdminRemote);
      final themeAdminRepo = ThemeAdminRepository(http);
      final menuDisplayPreviewRepo = MenuDisplayPreviewRepository(http);
      final combosAdminRepo = CombosAdminRepository(http);
      final menuUnitsRepo = MenuUnitsRepository(http);
      final uploadRepo = UploadRepository(http);
      final localAudioSettingsRepo = LocalAudioSettingsRepository(http);
      final localHardwareRepo = LocalHardwareRepository(http);
      final localOrdersRepo = LocalOrdersRepository(http);
      final localPaymentsRepo = LocalPaymentsRepository(http);
      final adminReportsRepo = AdminReportsRepository(http);
      final cartRepo = CartRepository();
      final updateInfo = await _reportInstalledVersion(http);
      if (updateInfo != null && updateInfo.requiresBlock) {
        if (!mounted) return;
        setState(() {
          _blockingUpdate = updateInfo;
          _payload = null;
          _loading = false;
        });
        return;
      }

      final authBloc = AuthBloc(
        authRepo,
        shiftRepo: shiftRepo,
        branchId: dotenv.maybeGet('POS_BRANCH_ID')?.trim().isNotEmpty == true
            ? dotenv.maybeGet('POS_BRANCH_ID')!.trim()
            : 'branch_1',
        terminalId: dotenv.maybeGet('POS_TERMINAL_ID'),
      )..add(const AuthStarted());
      await authBloc.stream
          .firstWhere((s) => s.isReady)
          .timeout(const Duration(seconds: 90));
      final localeBloc = LocaleBloc(kv)..add(const LocaleStarted());
      final posThemeCubit = PosThemeCubit(kv);
      final appRouter = AppRouter(authBloc: authBloc);

      if (!mounted) return;
      setState(() {
        _payload = _BootPayload(
          authRepo: authRepo,
          shiftRepo: shiftRepo,
          menuRepo: menuRepo,
          usersAdminRepo: usersAdminRepo,
          kitchenStationsRepo: kitchenStationsRepo,
          catalogAdminRepo: catalogAdminRepo,
          appVersionsRepo: appVersionsRepo,
          menuItemsAdminRepo: menuItemsAdminRepo,
          screensAdminRepo: screensAdminRepo,
          themeAdminRepo: themeAdminRepo,
          menuDisplayPreviewRepo: menuDisplayPreviewRepo,
          menuUnitsRepo: menuUnitsRepo,
          combosAdminRepo: combosAdminRepo,
          uploadRepo: uploadRepo,
          localAudioSettingsRepo: localAudioSettingsRepo,
          localHardwareRepo: localHardwareRepo,
          localOrdersRepo: localOrdersRepo,
          localPaymentsRepo: localPaymentsRepo,
          adminReportsRepo: adminReportsRepo,
          cartRepo: cartRepo,
          startupUpdate: updateInfo?.shouldNotify == true ? updateInfo : null,
          localeBloc: localeBloc,
          posThemeCubit: posThemeCubit,
          authBloc: authBloc,
          appRouter: appRouter,
        );
        _blockingUpdate = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _payload = null;
        _error = _formatStartupError(e);
        _loading = false;
      });
    }
  }

  Future<void> _ensureApiAvailable(DioHttpClient http) async {
    await http.get('api/health');
  }

  Future<AppUpdateInfo?> _reportInstalledVersion(DioHttpClient http) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final versionText = '${info.version}+${info.buildNumber}';
      final res = await http.post(
        'api/versions/report',
        body: {
          'appKey': 'pos',
          'displayName': 'dk_pos',
          'currentVersion': versionText,
        },
      );
      final body = res.body;
      if (body is Map<String, dynamic>) {
        final raw = body['version'];
        if (raw is Map<String, dynamic>) {
          return AppUpdateInfo.fromJson(raw, installedVersion: versionText);
        }
      }
    } catch (_) {
      // Отчет о версии не должен ломать запуск приложения.
    }
    return null;
  }

  Future<void> _saveServerIp() async {
    final raw = _ipController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Введите IP сервера');
      return;
    }
    final normalized = AppConfig.normalizeServerConnectionInput(raw);

    final prevSaved = await ServerEndpointStore.read();

    setState(() {
      _error = null;
      _loading = true;
    });

    AppConfig.setApiOriginOverride(normalized);
    dm_app_config.AppConfig.setApiOriginOverride(normalized);

    try {
      final dio = createDio();
      await _ensureApiAvailable(DioHttpClient(dio));
      await ServerEndpointStore.save(normalized);
      await clearPosLocalCaches();
      await _bootstrapApp();
    } catch (e) {
      if (prevSaved != null && prevSaved.isNotEmpty) {
        AppConfig.setApiOriginOverride(prevSaved);
        dm_app_config.AppConfig.setApiOriginOverride(prevSaved);
      } else {
        AppConfig.clearApiOriginOverride();
        dm_app_config.AppConfig.clearApiOriginOverride();
      }
      if (!mounted) return;
      setState(() {
        _payload = null;
        _error = _formatStartupError(e);
        _loading = false;
        _blockingUpdate = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFE4002B)),
          ),
        ),
      );
    }

    if (_blockingUpdate != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _AppUpdateGate(info: _blockingUpdate!, onRetry: _bootstrapApp),
      );
    }

    if (_payload == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF4F6), Color(0xFFFBE7EC)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(
                            0xFFE4002B,
                          ).withValues(alpha: 0.15),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1AE4002B),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.wifi_tethering_rounded,
                              size: 46,
                              color: Color(0xFFE4002B),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Введите IP сервера',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'IP компьютера, где запущен backend (не этот ПК). Пример: 192.168.1.100 или http://192.168.1.100:3000',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _ipController,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _saveServerIp(),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'IP сервера',
                                hintText: '192.168.1.100',
                                prefixIcon: Icon(Icons.dns_rounded),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Ошибка подключения',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD92D20),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _saveServerIp,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE4002B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Подключиться'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final payload = _payload!;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: payload.authRepo),
        RepositoryProvider<LocalShiftRepository>.value(value: payload.shiftRepo),
        RepositoryProvider<MenuRepository>.value(value: payload.menuRepo),
        RepositoryProvider<AdminReportsRepository>.value(value: payload.adminReportsRepo),
        RepositoryProvider<UsersAdminRepository>.value(value: payload.usersAdminRepo),
        RepositoryProvider<KitchenStationsRepository>.value(value: payload.kitchenStationsRepo),
        RepositoryProvider<CatalogAdminRepository>.value(value: payload.catalogAdminRepo),
        RepositoryProvider<AppVersionsRepository>.value(value: payload.appVersionsRepo),
        RepositoryProvider<MenuItemsAdminRepository>.value(value: payload.menuItemsAdminRepo),
        RepositoryProvider<ScreensAdminRepository>.value(value: payload.screensAdminRepo),
        RepositoryProvider<ThemeAdminRepository>.value(value: payload.themeAdminRepo),
        RepositoryProvider<MenuDisplayPreviewRepository>.value(
          value: payload.menuDisplayPreviewRepo,
        ),
        RepositoryProvider<MenuUnitsRepository>.value(value: payload.menuUnitsRepo),
        RepositoryProvider<CombosAdminRepository>.value(value: payload.combosAdminRepo),
        RepositoryProvider<UploadRepository>.value(value: payload.uploadRepo),
        RepositoryProvider<LocalAudioSettingsRepository>.value(
          value: payload.localAudioSettingsRepo,
        ),
        RepositoryProvider<LocalHardwareRepository>.value(value: payload.localHardwareRepo),
        RepositoryProvider<LocalOrdersRepository>.value(value: payload.localOrdersRepo),
        RepositoryProvider<LocalPaymentsRepository>.value(value: payload.localPaymentsRepo),
        RepositoryProvider<CartRepository>.value(value: payload.cartRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LocaleBloc>.value(value: payload.localeBloc),
          BlocProvider<PosThemeCubit>.value(value: payload.posThemeCubit),
          BlocProvider<AuthBloc>.value(value: payload.authBloc),
          BlocProvider<CartBloc>(create: (_) => CartBloc(payload.cartRepo)),
        ],
        child: DkPosApp(
          router: payload.appRouter,
          startupUpdate: payload.startupUpdate,
        ),
      ),
    );
  }
}

class _BootPayload {
  const _BootPayload({
    required this.authRepo,
    required this.shiftRepo,
    required this.menuRepo,
    required this.adminReportsRepo,
    required this.usersAdminRepo,
    required this.kitchenStationsRepo,
    required this.catalogAdminRepo,
    required this.appVersionsRepo,
    required this.menuItemsAdminRepo,
    required this.screensAdminRepo,
    required this.themeAdminRepo,
    required this.menuDisplayPreviewRepo,
    required this.menuUnitsRepo,
    required this.combosAdminRepo,
    required this.uploadRepo,
    required this.localAudioSettingsRepo,
    required this.localHardwareRepo,
    required this.localOrdersRepo,
    required this.localPaymentsRepo,
    required this.cartRepo,
    required this.startupUpdate,
    required this.localeBloc,
    required this.posThemeCubit,
    required this.authBloc,
    required this.appRouter,
  });

  final AuthRepository authRepo;
  final LocalShiftRepository shiftRepo;
  final MenuRepository menuRepo;
  final AdminReportsRepository adminReportsRepo;
  final UsersAdminRepository usersAdminRepo;
  final KitchenStationsRepository kitchenStationsRepo;
  final CatalogAdminRepository catalogAdminRepo;
  final AppVersionsRepository appVersionsRepo;
  final MenuItemsAdminRepository menuItemsAdminRepo;
  final ScreensAdminRepository screensAdminRepo;
  final ThemeAdminRepository themeAdminRepo;
  final MenuDisplayPreviewRepository menuDisplayPreviewRepo;
  final MenuUnitsRepository menuUnitsRepo;
  final CombosAdminRepository combosAdminRepo;
  final UploadRepository uploadRepo;
  final LocalAudioSettingsRepository localAudioSettingsRepo;
  final LocalHardwareRepository localHardwareRepo;
  final LocalOrdersRepository localOrdersRepo;
  final LocalPaymentsRepository localPaymentsRepo;
  final CartRepository cartRepo;
  final AppUpdateInfo? startupUpdate;
  final LocaleBloc localeBloc;
  final PosThemeCubit posThemeCubit;
  final AuthBloc authBloc;
  final AppRouter appRouter;
}

class _AppUpdateGate extends StatelessWidget {
  const _AppUpdateGate({required this.info, required this.onRetry});

  final AppUpdateInfo info;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        size: 48,
                        color: Color(0xFFE4002B),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Требуется обновление',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${info.displayName}\nТекущая версия: ${info.installedVersion}\nНужна версия: ${info.targetVersion ?? info.minSupportedVersion ?? "новее"}',
                        textAlign: TextAlign.center,
                      ),
                      if ((info.releaseNotes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(info.releaseNotes!, textAlign: TextAlign.center),
                      ],
                      if ((info.downloadUrl ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SelectableText(
                          info.downloadUrl!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: info.downloadUrl ?? ''),
                        ),
                        child: const Text('Скопировать ссылку обновления'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Проверить снова'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
