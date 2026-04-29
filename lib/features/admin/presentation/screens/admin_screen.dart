import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/app/pos_theme/pos_theme_cubit.dart';
import 'package:dk_pos/core/config/app_config.dart';
import 'package:dk_pos/core/constants/phone_defaults.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/catalog_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/menu_items_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_event.dart';
import 'package:dk_pos/features/admin/data/app_version_row.dart';
import 'package:dk_pos/features/admin/data/app_versions_repository.dart';
import 'package:dk_pos/features/admin/data/admin_reports_repository.dart';
import 'package:dk_pos/features/admin/data/catalog_admin_repository.dart';
import 'package:dk_pos/features/admin/data/local_audio_settings_repository.dart';
import 'package:dk_pos/features/admin/data/local_receipt_settings_repository.dart';
import 'package:dk_pos/features/hardware/data/local_hardware_repository.dart';
import 'package:dk_pos/features/admin/data/menu_items_admin_repository.dart';
import 'package:dk_pos/features/admin/data/upload_repository.dart';
import 'package:dk_pos/features/admin/data/users_admin_repository.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_catalog_hub.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_kitchen_ops_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_loyalty_panel.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_payment_methods_panel.dart';
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

  _AdminMenuGuide _guideForIndex(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return const _AdminMenuGuide(
          title: 'Обзор',
          purpose:
              'Главная точка контроля. Здесь вы быстро оцениваете состояние системы и переходите в нужный раздел без лишних кликов.',
          howTo: [
            'Откройте карточки и проверьте общую картину за смену.',
            'Если видите проблему, переходите в профильный раздел: пользователи, каталог, заказы или кухня.',
            'Используйте обзор как стартовый экран перед началом рабочей смены.',
          ],
          important: [
            'Обзор нужен для быстрой ориентации, а не для глубокого редактирования данных.',
            'Все изменения делайте в соответствующих разделах, чтобы сохранить порядок и контроль.',
          ],
        );
      case 1:
        return const _AdminMenuGuide(
          title: 'Пользователи',
          purpose:
              'Управление сотрудниками и доступами. Здесь создаются учетные записи, роли и права для кассы, кухни, экспедитора и админа.',
          howTo: [
            'Создайте пользователя и задайте ему понятный логин.',
            'Назначьте правильную роль: кассир, кухня, экспедитор, админ и т.д.',
            'Деактивируйте или корректируйте доступы при смене обязанностей сотрудника.',
          ],
          important: [
            'Роль определяет, какие экраны и действия доступны сотруднику.',
            'Перед удалением/блокировкой проверьте, не работает ли пользователь в активной смене.',
          ],
        );
      case 2:
        return const _AdminMenuGuide(
          title: 'Каталог',
          purpose:
              'Управление меню: категории, позиции, цены, доступность, кухня и визуальные экраны (TV/комбо/контент).',
          howTo: [
            'Создайте или проверьте категории, затем добавляйте позиции.',
            'Для каждой позиции заполните цену, кухню, состав и доступность.',
            'Проверьте, как изменения отображаются в POS и на экранах меню.',
          ],
          important: [
            'Сначала структура категорий, потом товары — так меньше ошибок в навигации.',
            'После массовых изменений проверяйте порядок и видимость в реальном POS-потоке.',
          ],
        );
      case 3:
        return const _AdminMenuGuide(
          title: 'Заказы',
          purpose:
              'Контроль продаж и заказов: история оплат, статусы, динамика и проверка операционной дисциплины.',
          howTo: [
            'Фильтруйте период и анализируйте ключевые метрики.',
            'Проверяйте аномалии: отмены, возвраты, расхождения по способам оплаты.',
            'Сверяйте отчеты с фактическими операциями в смене.',
          ],
          important: [
            'Используйте данные раздела для управленческих решений, а не только для просмотра.',
            'При спорных операциях фиксируйте причину и сверяйте с чеками/логами.',
          ],
        );
      case 4:
        return const _AdminMenuGuide(
          title: 'Смены и кухня',
          purpose:
              'Операционное управление производством: загрузка кухни, смены сотрудников, скорость выдачи и узкие места.',
          howTo: [
            'Проверьте активные смены и состав персонала.',
            'Оцените статусы заказов на кухне и в экспедировании.',
            'Корректируйте процессы: приоритеты, зоны ответственности, нагрузку.',
          ],
          important: [
            'Этот раздел помогает держать стабильное время приготовления.',
            'Регулярно проверяйте задержки — они напрямую влияют на качество сервиса.',
          ],
        );
      case 5:
        return const _AdminMenuGuide(
          title: 'Лояльность',
          purpose:
              'Управление клиентской базой и баллами: поиск, регистрация, уровни, начисления, списания и черный список.',
          howTo: [
            'Найдите клиента по телефону/карте/QR или создайте нового.',
            'Проверьте уровень и баланс, при необходимости скорректируйте баллы.',
            'Работайте с blacklist аккуратно: всегда указывайте понятную причину.',
          ],
          important: [
            'Любая ручная корректировка баллов должна быть обоснована.',
            'Следите за корректностью телефона и карты — это основа поиска в POS.',
          ],
        );
      case 6:
        return const _AdminMenuGuide(
          title: 'Настройки',
          purpose:
              'Конфигурация системы: язык, тема, обновления, звук и конструктор чека. Влияет на весь POS-контур.',
          howTo: [
            'Изменяйте параметры блоками: сначала язык/тема, затем звук, затем чек.',
            'После изменения настроек чека делайте тестовую печать.',
            'Проверяйте изменения на рабочем сценарии кассы перед запуском в смену.',
          ],
          important: [
            'Настройки применяются к реальным рабочим процессам — меняйте осознанно.',
            'Для критичных параметров (печать, звук, обновления) используйте пошаговую проверку.',
          ],
        );
      default:
        return const _AdminMenuGuide(
          title: 'Справка',
          purpose: 'Документация по выбранному разделу админки.',
          howTo: ['Откройте нужный раздел и следуйте шагам.'],
          important: ['Фиксируйте изменения в рабочих процессах.'],
        );
    }
  }

  Future<void> _showCurrentMenuGuide(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final guide = _guideForIndex(l10n, _index);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Справочник: ${guide.title}')),
            ],
          ),
          content: SizedBox(
            width: math.min(640, MediaQuery.sizeOf(ctx).width * 0.94),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Для чего',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guide.purpose,
                    style: textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Как работать',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < guide.howTo.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${i + 1}. ${guide.howTo[i]}'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Важно',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final note in guide.important)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(note)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
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
      'Лояльность',
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
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: l10n.tooltipAppMenu,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Text(titles[_index], overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Справочник по разделу',
                onPressed: () => _showCurrentMenuGuide(context, l10n),
                icon: const Icon(Icons.help_outline_rounded),
              ),
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

class _AdminMenuGuide {
  const _AdminMenuGuide({
    required this.title,
    required this.purpose,
    required this.howTo,
    required this.important,
  });

  final String title;
  final String purpose;
  final List<String> howTo;
  final List<String> important;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14);
    final selectedFg = scheme.primary;

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
          color: selected ? selectedBg : Colors.transparent,
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
                    color: selected ? selectedFg : null,
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
                            color: selected ? selectedFg : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
                          style: textTheme.bodySmall?.copyWith(
                            color: selected
                                ? selectedFg.withValues(alpha: 0.85)
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
                    iconOutlined: Icons.loyalty_outlined,
                    iconFilled: Icons.loyalty_rounded,
                    label: 'Лояльность',
                    hint: 'Клиенты, баллы, уровни, черный список',
                  ),
                  navDestination(
                    i: 6,
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBodyWidth),
            child: const AdminLoyaltyPanel(),
          ),
        ),
      );
    }

    if (index == 6) {
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
            0 => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSectionCard(
                  icon: Icons.insights_rounded,
                  title: l10n.adminDashboardHeadline,
                  body: l10n.adminDashboardBody,
                ),
                const SizedBox(height: 12),
                const _AdminSyncQuickCard(),
              ],
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _AdminSyncQuickCard extends StatefulWidget {
  const _AdminSyncQuickCard();

  @override
  State<_AdminSyncQuickCard> createState() => _AdminSyncQuickCardState();
}

class _AdminSyncQuickCardState extends State<_AdminSyncQuickCard> {
  late Future<AdminSyncStatus> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminSyncStatus> _load() {
    return context.read<AdminReportsRepository>().fetchSyncStatus();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _runAction(
    Future<AdminSyncActionResult> Function() action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка синка: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<AdminSyncStatus>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Загрузка sync статуса...'),
                ],
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Синхронизация Global <-> Local',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Ошибка: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              );
            }

            final status = snapshot.data!;
            final hasError =
                status.outbox.failed > 0 ||
                (status.pushState?.lastError?.isNotEmpty ?? false) ||
                (status.pullState?.lastError?.isNotEmpty ?? false);
            final tone = hasError ? Colors.red : Colors.green;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Синхронизация Global <-> Local',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.10),
                        border: Border.all(color: tone.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasError ? 'Есть проблемы' : 'Норма',
                        style: text.labelMedium?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Очередь: pending ${status.outbox.pending}, retry ${status.outbox.retrying}, failed ${status.outbox.failed}',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Push: ${status.pushState?.lastSuccessAt ?? '—'} | Pull: ${status.pullState?.lastSuccessAt ?? '—'}',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if ((status.pushState?.lastError ?? '').isNotEmpty)
                  Text(
                    'Push error: ${status.pushState!.lastError}',
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                if ((status.pullState?.lastError ?? '').isNotEmpty)
                  Text(
                    'Pull error: ${status.pullState!.lastError}',
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runAction(
                              () => context
                                  .read<AdminReportsRepository>()
                                  .triggerPushNow(),
                            ),
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Push now'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runAction(
                              () => context
                                  .read<AdminReportsRepository>()
                                  .triggerPullNow(),
                            ),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Pull now'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Обновить'),
                    ),
                  ],
                ),
              ],
            );
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

enum _AdminSettingsSection {
  languageTheme,
  updates,
  sound,
  paymentMethods,
  receipt,
}

class _AdminSettingsPanelState extends State<_AdminSettingsPanel> {
  late Future<List<AppVersionRow>> _versionsFuture;
  late final TextEditingController _readySoundCtrl;
  late final TextEditingController _kitchenSoundCtrl;
  late final TextEditingController _kitchenTtsRateCtrl;
  late final TextEditingController _kitchenTtsLocaleCtrl;
  late final TextEditingController _kitchenTtsVoiceNameCtrl;
  late final TextEditingController _receiptBrandCtrl;
  late final TextEditingController _receiptSiteCtrl;
  late final TextEditingController _receiptFooter1Ctrl;
  late final TextEditingController _receiptFooter2Ctrl;
  late final TextEditingController _receiptQrSizeCtrl;
  late final TextEditingController _receiptGdiOffsetCtrl;
  late final TextEditingController _receiptLineWidthCtrl;
  late final TextEditingController _receiptTaxPercentCtrl;
  late final TextEditingController _receiptTaxLabelCtrl;
  late final TextEditingController _receiptCompanyNameCtrl;
  late final TextEditingController _receiptCompanyAddressCtrl;
  late final TextEditingController _receiptCompanyPhoneCtrl;
  late final TextEditingController _receiptCompanyInnCtrl;
  late final TextEditingController _receiptFiscalKkmCtrl;
  late final TextEditingController _receiptFiscalRnmCtrl;
  late final TextEditingController _receiptFiscalCashierIdCtrl;
  late final TextEditingController _receiptFiscalShiftNoCtrl;
  bool _audioLoading = false;
  bool _audioSaving = false;
  bool _audioUploading = false;
  bool _kitchenTtsEnabled = true;
  bool _receiptLoading = false;
  bool _receiptSaving = false;
  bool _receiptTesting = false;
  bool _receiptQrEnabled = true;
  bool _receiptShowFooterLine1 = true;
  bool _receiptShowFooterLine2 = true;
  bool _receiptShowOrderItems = true;
  bool _receiptShowUnitPrice = true;
  bool _receiptShowCashier = true;
  bool _receiptShowPaymentMethod = true;
  bool _receiptShowBranch = true;
  bool _receiptShowBusinessInfo = false;
  bool _receiptShowFiscalInfo = false;
  bool _receiptShowTax = false;
  bool _receiptTaxIncluded = true;
  bool _receiptTrimItemPriceZeros = true;
  _AdminSettingsSection _settingsSection = _AdminSettingsSection.languageTheme;

  @override
  void initState() {
    super.initState();
    _versionsFuture = context.read<AppVersionsRepository>().fetchVersions();
    _readySoundCtrl = TextEditingController();
    _kitchenSoundCtrl = TextEditingController();
    _kitchenTtsRateCtrl = TextEditingController(text: '0.48');
    _kitchenTtsLocaleCtrl = TextEditingController(text: 'ru-RU');
    _kitchenTtsVoiceNameCtrl = TextEditingController();
    _receiptBrandCtrl = TextEditingController(text: 'DONER KEBAB');
    _receiptSiteCtrl = TextEditingController(text: 'https://donerkebab.tj');
    _receiptFooter1Ctrl = TextEditingController(text: 'Спасибо за покупку!');
    _receiptFooter2Ctrl = TextEditingController(text: 'Ташаккур барои харид');
    _receiptQrSizeCtrl = TextEditingController(text: '7');
    _receiptGdiOffsetCtrl = TextEditingController(text: '0');
    _receiptLineWidthCtrl = TextEditingController(text: '36');
    _receiptTaxPercentCtrl = TextEditingController(text: '0');
    _receiptTaxLabelCtrl = TextEditingController(text: 'НДС');
    _receiptCompanyNameCtrl = TextEditingController();
    _receiptCompanyAddressCtrl = TextEditingController();
    _receiptCompanyPhoneCtrl = TextEditingController();
    _receiptCompanyInnCtrl = TextEditingController();
    _receiptFiscalKkmCtrl = TextEditingController();
    _receiptFiscalRnmCtrl = TextEditingController();
    _receiptFiscalCashierIdCtrl = TextEditingController();
    _receiptFiscalShiftNoCtrl = TextEditingController();
    _loadAudioSettings();
    _loadReceiptSettings();
  }

  @override
  void dispose() {
    _readySoundCtrl.dispose();
    _kitchenSoundCtrl.dispose();
    _kitchenTtsRateCtrl.dispose();
    _kitchenTtsLocaleCtrl.dispose();
    _kitchenTtsVoiceNameCtrl.dispose();
    _receiptBrandCtrl.dispose();
    _receiptSiteCtrl.dispose();
    _receiptFooter1Ctrl.dispose();
    _receiptFooter2Ctrl.dispose();
    _receiptQrSizeCtrl.dispose();
    _receiptGdiOffsetCtrl.dispose();
    _receiptLineWidthCtrl.dispose();
    _receiptTaxPercentCtrl.dispose();
    _receiptTaxLabelCtrl.dispose();
    _receiptCompanyNameCtrl.dispose();
    _receiptCompanyAddressCtrl.dispose();
    _receiptCompanyPhoneCtrl.dispose();
    _receiptCompanyInnCtrl.dispose();
    _receiptFiscalKkmCtrl.dispose();
    _receiptFiscalRnmCtrl.dispose();
    _receiptFiscalCashierIdCtrl.dispose();
    _receiptFiscalShiftNoCtrl.dispose();
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

  Future<void> _loadReceiptSettings() async {
    setState(() => _receiptLoading = true);
    try {
      final settings = await context
          .read<LocalReceiptSettingsRepository>()
          .fetch(branchId: AppConfig.storeBranchId);
      if (!mounted) return;
      _receiptBrandCtrl.text = settings.brandName;
      _receiptSiteCtrl.text = settings.siteUrl;
      _receiptFooter1Ctrl.text = settings.footerLine1;
      _receiptFooter2Ctrl.text = settings.footerLine2;
      _receiptQrSizeCtrl.text = settings.qrSize.toString();
      _receiptGdiOffsetCtrl.text = settings.gdiLeftOffset.toString();
      _receiptLineWidthCtrl.text = settings.receiptCharsPerLine.toString();
      _receiptTaxPercentCtrl.text = settings.taxPercent.toStringAsFixed(2);
      _receiptTaxLabelCtrl.text = settings.taxLabel;
      _receiptCompanyNameCtrl.text = settings.companyName ?? '';
      _receiptCompanyAddressCtrl.text = settings.companyAddress ?? '';
      final cp = (settings.companyPhone ?? '').trim();
      _receiptCompanyPhoneCtrl.text = cp.isEmpty ? kDefaultPhoneDialPrefix : cp;
      _receiptCompanyInnCtrl.text = settings.companyInn ?? '';
      _receiptFiscalKkmCtrl.text = settings.fiscalKkm ?? '';
      _receiptFiscalRnmCtrl.text = settings.fiscalRnm ?? '';
      _receiptFiscalCashierIdCtrl.text = settings.fiscalCashierId ?? '';
      _receiptFiscalShiftNoCtrl.text = settings.fiscalShiftNo ?? '';
      _receiptQrEnabled = settings.qrEnabled;
      _receiptShowFooterLine1 = settings.showFooterLine1;
      _receiptShowFooterLine2 = settings.showFooterLine2;
      _receiptShowOrderItems = settings.showOrderItems;
      _receiptShowUnitPrice = settings.showUnitPrice;
      _receiptShowCashier = settings.showCashier;
      _receiptShowPaymentMethod = settings.showPaymentMethod;
      _receiptShowBranch = settings.showBranch;
      _receiptShowBusinessInfo = settings.showBusinessInfo;
      _receiptShowFiscalInfo = settings.showFiscalInfo;
      _receiptShowTax = settings.showTax;
      _receiptTaxIncluded = settings.taxIncluded;
      _receiptTrimItemPriceZeros = settings.trimItemPriceZeros;
    } catch (_) {
      // не блокируем экран, если новая таблица еще не создана
    } finally {
      if (mounted) setState(() => _receiptLoading = false);
    }
  }

  Future<void> _saveReceiptSettings() async {
    setState(() => _receiptSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final qrSize = int.tryParse(_receiptQrSizeCtrl.text.trim());
      if (qrSize == null || qrSize < 3 || qrSize > 12) {
        throw Exception('Размер QR должен быть от 3 до 12');
      }
      final taxPercent = double.tryParse(
        _receiptTaxPercentCtrl.text.trim().replaceAll(',', '.'),
      );
      if (taxPercent == null || taxPercent < 0 || taxPercent > 100) {
        throw Exception('Налог должен быть от 0 до 100');
      }
      final gdiLeftOffset = int.tryParse(_receiptGdiOffsetCtrl.text.trim());
      if (gdiLeftOffset == null || gdiLeftOffset < -40 || gdiLeftOffset > 40) {
        throw Exception('Смещение печати должно быть от -40 до 40');
      }
      final receiptCharsPerLine = int.tryParse(
        _receiptLineWidthCtrl.text.trim(),
      );
      if (receiptCharsPerLine == null ||
          receiptCharsPerLine < 30 ||
          receiptCharsPerLine > 48) {
        throw Exception('Ширина строки должна быть от 30 до 48');
      }
      await context.read<LocalReceiptSettingsRepository>().update(
        brandName: _receiptBrandCtrl.text.trim(),
        siteUrl: _receiptSiteCtrl.text.trim(),
        footerLine1: _receiptFooter1Ctrl.text.trim(),
        showFooterLine1: _receiptShowFooterLine1,
        footerLine2: _receiptFooter2Ctrl.text.trim(),
        showFooterLine2: _receiptShowFooterLine2,
        qrEnabled: _receiptQrEnabled,
        qrSize: qrSize,
        showOrderItems: _receiptShowOrderItems,
        showUnitPrice: _receiptShowUnitPrice,
        showCashier: _receiptShowCashier,
        showPaymentMethod: _receiptShowPaymentMethod,
        showBranch: _receiptShowBranch,
        showBusinessInfo: _receiptShowBusinessInfo,
        companyName: _receiptCompanyNameCtrl.text.trim().isEmpty
            ? null
            : _receiptCompanyNameCtrl.text.trim(),
        companyAddress: _receiptCompanyAddressCtrl.text.trim().isEmpty
            ? null
            : _receiptCompanyAddressCtrl.text.trim(),
        companyPhone: _receiptCompanyPhoneCtrl.text.trim().isEmpty
            ? null
            : _receiptCompanyPhoneCtrl.text.trim(),
        companyInn: _receiptCompanyInnCtrl.text.trim().isEmpty
            ? null
            : _receiptCompanyInnCtrl.text.trim(),
        showFiscalInfo: _receiptShowFiscalInfo,
        fiscalKkm: _receiptFiscalKkmCtrl.text.trim().isEmpty
            ? null
            : _receiptFiscalKkmCtrl.text.trim(),
        fiscalRnm: _receiptFiscalRnmCtrl.text.trim().isEmpty
            ? null
            : _receiptFiscalRnmCtrl.text.trim(),
        fiscalCashierId: _receiptFiscalCashierIdCtrl.text.trim().isEmpty
            ? null
            : _receiptFiscalCashierIdCtrl.text.trim(),
        fiscalShiftNo: _receiptFiscalShiftNoCtrl.text.trim().isEmpty
            ? null
            : _receiptFiscalShiftNoCtrl.text.trim(),
        showTax: _receiptShowTax,
        taxPercent: taxPercent,
        taxLabel: _receiptTaxLabelCtrl.text.trim(),
        taxIncluded: _receiptTaxIncluded,
        gdiLeftOffset: gdiLeftOffset,
        receiptCharsPerLine: receiptCharsPerLine,
        trimItemPriceZeros: _receiptTrimItemPriceZeros,
        branchId: AppConfig.storeBranchId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Настройки чека сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _receiptSaving = false);
    }
  }

  Future<void> _printTestReceipt() async {
    setState(() => _receiptTesting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final hardware = context.read<LocalHardwareRepository>();
      final now = DateTime.now();
      final testOrderId =
          'test_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}';
      final result = await hardware.printReceipt(
        orderId: testOrderId,
        totalAmount: 64,
        paymentMethod: 'card',
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Пробная печать выполнена: № ${result.receiptNumber} (${result.mode})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Пробная печать не удалась: $e')),
      );
    } finally {
      if (mounted) setState(() => _receiptTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14);
    final selectedFg = scheme.primary;
    final lang = context.watch<LocaleBloc>().state.locale.languageCode;
    final themeSettings = context.watch<PosThemeCubit>().state;
    final posTheme = themeSettings.mode;
    final posAccent = themeSettings.accent;
    final currentAccentColor = themeSettings.accentColor;

    void setLang(String code) {
      context.read<LocaleBloc>().add(LocaleChanged(Locale(code)));
    }

    void setTheme(PosScreenTheme mode) {
      context.read<PosThemeCubit>().setTheme(mode);
    }

    void setAccent(PosAccentColor accent) {
      context.read<PosThemeCubit>().setAccent(accent);
    }

    Color resolveAccentColor(PosAccentColor accent) {
      if (accent == PosAccentColor.custom) return currentAccentColor;
      return accent.presetColor;
    }

    Future<void> pickCustomAccentColor() async {
      final posThemeCubit = context.read<PosThemeCubit>();
      final picked = await _showAccentColorPickerDialog(
        context,
        initialColor: currentAccentColor,
      );
      if (picked == null || !mounted) return;
      await posThemeCubit.setCustomAccentColor(picked);
    }

    Widget languageTile(String code, String title) {
      final selected = lang == code;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected ? selectedBg : scheme.surfaceContainerLow,
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
                    color: selected ? selectedFg : scheme.outline,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: selected ? selectedFg : null,
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

    Widget settingsSectionChip({
      required _AdminSettingsSection section,
      required String label,
      required IconData icon,
    }) {
      final selected = _settingsSection == section;
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? selectedFg : scheme.onSurfaceVariant,
          ),
        ),
        selectedColor: selectedBg,
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(
          color: selected
              ? selectedFg.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? selectedFg : scheme.onSurfaceVariant,
        ),
        selected: selected,
        onSelected: (_) => setState(() => _settingsSection = section),
      );
    }

    Widget sectionGuide(String text) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.menu_book_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              settingsSectionChip(
                section: _AdminSettingsSection.languageTheme,
                label: 'Язык и тема',
                icon: Icons.translate_rounded,
              ),
              settingsSectionChip(
                section: _AdminSettingsSection.updates,
                label: 'Обновления',
                icon: Icons.system_update_alt_rounded,
              ),
              settingsSectionChip(
                section: _AdminSettingsSection.sound,
                label: 'Звук',
                icon: Icons.volume_up_rounded,
              ),
              settingsSectionChip(
                section: _AdminSettingsSection.paymentMethods,
                label: 'Оплата',
                icon: Icons.account_balance_wallet_rounded,
              ),
              settingsSectionChip(
                section: _AdminSettingsSection.receipt,
                label: 'Чек',
                icon: Icons.receipt_long_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_settingsSection == _AdminSettingsSection.languageTheme) ...[
            Text(
              l10n.adminDrawerSectionLanguage,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            const SizedBox(height: 12),
            Text(
              'Тема интерфейса POS',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Светлая'),
                    selected: posTheme == PosScreenTheme.light,
                    selectedColor: selectedBg,
                    backgroundColor: scheme.surfaceContainerLow,
                    side: BorderSide(
                      color: posTheme == PosScreenTheme.light
                          ? selectedFg.withValues(alpha: 0.35)
                          : scheme.outlineVariant,
                    ),
                    labelStyle: TextStyle(
                      color: posTheme == PosScreenTheme.light
                          ? selectedFg
                          : scheme.onSurfaceVariant,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setTheme(PosScreenTheme.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Тёмная'),
                    selected: posTheme == PosScreenTheme.dark,
                    selectedColor: selectedBg,
                    backgroundColor: scheme.surfaceContainerLow,
                    side: BorderSide(
                      color: posTheme == PosScreenTheme.dark
                          ? selectedFg.withValues(alpha: 0.35)
                          : scheme.outlineVariant,
                    ),
                    labelStyle: TextStyle(
                      color: posTheme == PosScreenTheme.dark
                          ? selectedFg
                          : scheme.onSurfaceVariant,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setTheme(PosScreenTheme.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Акцентный цвет',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final accent in PosAccentColor.values)
                  FilterChip(
                    selected: posAccent == accent,
                    selectedColor: selectedBg,
                    backgroundColor: scheme.surfaceContainerLow,
                    side: BorderSide(
                      color: posAccent == accent
                          ? resolveAccentColor(accent).withValues(alpha: 0.45)
                          : scheme.outlineVariant,
                    ),
                    avatar: Icon(
                      Icons.circle,
                      size: 14,
                      color: resolveAccentColor(accent),
                    ),
                    label: Text(
                      accent.label,
                      style: TextStyle(
                        color: posAccent == accent
                            ? selectedFg
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    showCheckmark: false,
                    onSelected: (_) {
                      if (accent == PosAccentColor.custom) {
                        pickCustomAccentColor();
                      } else {
                        setAccent(accent);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            sectionGuide(
              'Справочник: здесь выбирается язык, светлая/тёмная тема и акцентный цвет интерфейса POS.',
            ),
          ],
          if (_settingsSection == _AdminSettingsSection.updates) ...[
            const SizedBox(height: 28),
            Text(
              'Версии приложений',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь видно версии backend, POS и APK меню. Эта же таблица станет основой для будущих удаленных обновлений.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            sectionGuide(
              'Справочник: блок для контроля версий backend/POS/APK и подготовки к централизованным обновлениям.',
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
          ],
          if (_settingsSection == _AdminSettingsSection.sound) ...[
            const SizedBox(height: 28),
            Text(
              'Озвучка очереди',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            sectionGuide(
              'Справочник: настройки звуков и TTS для очереди и кухни. Можно загружать файлы и настраивать голос.',
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
                                (_audioLoading ||
                                    _audioUploading ||
                                    _audioSaving)
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
          if (_settingsSection == _AdminSettingsSection.paymentMethods) ...[
            const SizedBox(height: 28),
            Text(
              'Банки в способах оплаты',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Настройте список банков для кассы: ДС, Эсхата и другие. Кассир увидит только активные варианты.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            sectionGuide(
              'Справочник: управление банковскими способами оплаты для кассы. Наличные всегда остаются системным способом.',
            ),
            const SizedBox(height: 12),
            const AdminPaymentMethodsPanel(),
          ],
          if (_settingsSection == _AdminSettingsSection.receipt) ...[
            const SizedBox(height: 28),
            Text(
              'Конструктор чека',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Меняйте состав чека: поля, налог, QR и подпись. Предпросмотр обновляется сразу.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            sectionGuide(
              'Справочник: управление шаблоном чека (поля, налог, QR, ширина, смещение, реквизиты, предпросмотр, тест-печать).',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Основное',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _receiptBrandCtrl,
                      enabled: !_receiptLoading,
                      decoration: const InputDecoration(
                        labelText: 'Бренд (заголовок чека)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _receiptSiteCtrl,
                      enabled: !_receiptLoading,
                      decoration: const InputDecoration(
                        labelText: 'Сайт',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Налог и QR',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _receiptFooter1Ctrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Footer строка 1',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _receiptFooter2Ctrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Footer строка 2',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _receiptGdiOffsetCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Смещение печати (-40..40)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _receiptLineWidthCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Ширина строки (30..48)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _receiptQrSizeCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Размер QR (3..12)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _receiptTaxPercentCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Налог %',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _receiptTaxLabelCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Название налога (НДС/VAT)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilterChip(
                            label: Text(
                              _receiptTaxIncluded
                                  ? 'Налог включен в цену'
                                  : 'Налог сверху',
                            ),
                            selected: _receiptTaxIncluded,
                            onSelected: (_receiptLoading || _receiptSaving)
                                ? null
                                : (v) =>
                                      setState(() => _receiptTaxIncluded = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Поля чека',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: const Text('QR'),
                          selected: _receiptQrEnabled,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(() => _receiptQrEnabled = v),
                        ),
                        FilterChip(
                          label: const Text('Спасибо за покупку'),
                          selected: _receiptShowFooterLine1,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) =>
                                    setState(() => _receiptShowFooterLine1 = v),
                        ),
                        FilterChip(
                          label: const Text('Ташаккур барои харид'),
                          selected: _receiptShowFooterLine2,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) =>
                                    setState(() => _receiptShowFooterLine2 = v),
                        ),
                        FilterChip(
                          label: const Text('Позиции'),
                          selected: _receiptShowOrderItems,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) =>
                                    setState(() => _receiptShowOrderItems = v),
                        ),
                        FilterChip(
                          label: const Text('Цена за штуку'),
                          selected: _receiptShowUnitPrice,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) =>
                                    setState(() => _receiptShowUnitPrice = v),
                        ),
                        FilterChip(
                          label: const Text('Цены без .00'),
                          selected: _receiptTrimItemPriceZeros,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(
                                  () => _receiptTrimItemPriceZeros = v,
                                ),
                        ),
                        FilterChip(
                          label: const Text('Кассир'),
                          selected: _receiptShowCashier,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(() => _receiptShowCashier = v),
                        ),
                        FilterChip(
                          label: const Text('Оплата'),
                          selected: _receiptShowPaymentMethod,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(
                                  () => _receiptShowPaymentMethod = v,
                                ),
                        ),
                        FilterChip(
                          label: const Text('Филиал'),
                          selected: _receiptShowBranch,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(() => _receiptShowBranch = v),
                        ),
                        FilterChip(
                          label: const Text('Реквизиты'),
                          selected: _receiptShowBusinessInfo,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(
                                  () => _receiptShowBusinessInfo = v,
                                ),
                        ),
                        FilterChip(
                          label: const Text('Фискальные поля'),
                          selected: _receiptShowFiscalInfo,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) =>
                                    setState(() => _receiptShowFiscalInfo = v),
                        ),
                        FilterChip(
                          label: const Text('Налог'),
                          selected: _receiptShowTax,
                          onSelected: (_receiptLoading || _receiptSaving)
                              ? null
                              : (v) => setState(() => _receiptShowTax = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_receiptShowBusinessInfo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Реквизиты компании',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _receiptCompanyNameCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Название компании',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _receiptCompanyAddressCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'Адрес',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _receiptCompanyPhoneCtrl,
                                  enabled: !_receiptLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Телефон',
                                    hintText: '$kDefaultPhoneDialPrefix…',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _receiptCompanyInnCtrl,
                                  enabled: !_receiptLoading,
                                  decoration: const InputDecoration(
                                    labelText: 'ИНН',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    if (_receiptShowFiscalInfo)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Фискальные данные',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _receiptFiscalKkmCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'ККМ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _receiptFiscalRnmCtrl,
                            enabled: !_receiptLoading,
                            decoration: const InputDecoration(
                              labelText: 'РНМ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _receiptFiscalCashierIdCtrl,
                                  enabled: !_receiptLoading,
                                  decoration: const InputDecoration(
                                    labelText: 'ID кассира',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _receiptFiscalShiftNoCtrl,
                                  enabled: !_receiptLoading,
                                  decoration: const InputDecoration(
                                    labelText: 'Номер смены',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          (_receiptLoading || _receiptSaving || _receiptTesting)
                          ? null
                          : _saveReceiptSettings,
                      icon: _receiptSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Сохранить шаблон чека'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          (_receiptLoading || _receiptSaving || _receiptTesting)
                          ? null
                          : _printTestReceipt,
                      icon: _receiptTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_rounded),
                      label: const Text('Пробная печать чека'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Предпросмотр',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: SelectableText(
                        _buildReceiptPreview(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildReceiptPreview() {
    String fmtItem(double value) {
      if (!_receiptTrimItemPriceZeros) return '${value.toStringAsFixed(2)} TJS';
      if ((value - value.roundToDouble()).abs() < 0.000001) {
        return '${value.round()} TJS';
      }
      return '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} TJS';
    }

    final brand = _receiptBrandCtrl.text.trim().isEmpty
        ? 'DONER KEBAB'
        : _receiptBrandCtrl.text.trim();
    final footer1 = _receiptFooter1Ctrl.text.trim().isEmpty
        ? 'Спасибо за покупку!'
        : _receiptFooter1Ctrl.text.trim();
    final footer2 = _receiptFooter2Ctrl.text.trim();
    final site = _receiptSiteCtrl.text.trim().isEmpty
        ? 'https://donerkebab.tj'
        : _receiptSiteCtrl.text.trim();
    final companyName = _receiptCompanyNameCtrl.text.trim();
    final companyAddress = _receiptCompanyAddressCtrl.text.trim();
    final companyPhone = _receiptCompanyPhoneCtrl.text.trim();
    final companyInn = _receiptCompanyInnCtrl.text.trim();
    final fiscalKkm = _receiptFiscalKkmCtrl.text.trim();
    final fiscalRnm = _receiptFiscalRnmCtrl.text.trim();
    final fiscalCashierId = _receiptFiscalCashierIdCtrl.text.trim();
    final fiscalShiftNo = _receiptFiscalShiftNoCtrl.text.trim();
    final taxLabel = _receiptTaxLabelCtrl.text.trim().isEmpty
        ? 'НДС'
        : _receiptTaxLabelCtrl.text.trim();
    final taxPercent =
        double.tryParse(
          _receiptTaxPercentCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    const total = 64.00;
    final tax = _receiptShowTax
        ? (_receiptTaxIncluded
              ? total - (total / (1 + taxPercent / 100))
              : (total * taxPercent / 100))
        : 0.0;
    final subtotal = _receiptTaxIncluded ? total - tax : total;
    final payable = _receiptTaxIncluded ? total : total + tax;

    final out = <String>[
      brand,
      '------------------------------------------',
      'Чек: ABCD1234                  Заказ: 201',
      if (_receiptShowCashier) 'Кассир: admin',
      if (_receiptShowBranch) 'Филиал: ${AppConfig.storeBranchId}',
      'Касса: KASSA-1',
      'Время: 2026-04-19 12:34:56',
      if (_receiptShowBusinessInfo && companyName.isNotEmpty)
        'Компания: $companyName',
      if (_receiptShowBusinessInfo && companyAddress.isNotEmpty)
        'Адрес: $companyAddress',
      if (_receiptShowBusinessInfo && companyPhone.isNotEmpty)
        'Телефон: $companyPhone',
      if (_receiptShowBusinessInfo && companyInn.isNotEmpty) 'INN: $companyInn',
      if (_receiptShowFiscalInfo && fiscalKkm.isNotEmpty) 'KKM: $fiscalKkm',
      if (_receiptShowFiscalInfo && fiscalRnm.isNotEmpty) 'RNM: $fiscalRnm',
      if (_receiptShowFiscalInfo && fiscalCashierId.isNotEmpty)
        'Cashier ID: $fiscalCashierId',
      if (_receiptShowFiscalInfo && fiscalShiftNo.isNotEmpty)
        'Shift: $fiscalShiftNo'
      else if (_receiptShowFiscalInfo)
        'Shift: auto (active shift)',
      '',
      '------------------------------------------',
    ];
    if (_receiptShowOrderItems) {
      out.add('Позиции               Кол-во x Цена');
      if (_receiptShowUnitPrice) {
        out.add('Burger');
        out.add('  2 x ${fmtItem(20)}                 ${fmtItem(40)}');
      } else {
        out.add('Burger');
        out.add('  Кол-во: 2                  ${fmtItem(40)}');
      }
      if (_receiptShowUnitPrice) {
        out.add('Fries');
        out.add('  1 x ${fmtItem(24)}                 ${fmtItem(24)}');
      } else {
        out.add('Fries');
        out.add('  Кол-во: 1                  ${fmtItem(24)}');
      }
      out.add('------------------------------------------');
    }
    if (_receiptShowTax && taxPercent > 0) {
      out.add(
        'ПОДИТОГ                             ${subtotal.toStringAsFixed(2)} TJS',
      );
      final mode = _receiptTaxIncluded ? '(incl.)' : '';
      out.add(
        '${'$taxLabel ${taxPercent.toStringAsFixed(2)}% $mode'.padRight(31).substring(0, 31)}'
        '${tax.toStringAsFixed(2)} TJS',
      );
    }
    out.add(
      'ИТОГО К ОПЛАТЕ                       ${payable.toStringAsFixed(2)} TJS',
    );
    out.add('');
    if (_receiptShowPaymentMethod)
      out.add('СПОСОБ ОПЛАТЫ                   Наличными');
    out.add('Сайт: $site');
    if (_receiptQrEnabled) out.add('[QR: $site]');
    if (_receiptShowFooterLine1) out.add(footer1);
    if (_receiptShowFooterLine2 && footer2.isNotEmpty) out.add(footer2);
    return out.join('\n');
  }
}

Future<Color?> _showAccentColorPickerDialog(
  BuildContext context, {
  required Color initialColor,
}) {
  var hsv = HSVColor.fromColor(initialColor);
  return showDialog<Color>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) {
          final preview = hsv.toColor();
          return AlertDialog(
            title: const Text('Свой акцентный цвет'),
            content: SizedBox(
              width: math.min(430, MediaQuery.sizeOf(ctx).width * 0.94),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: preview,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Hue: ${hsv.hue.round()}'),
                  Slider(
                    value: hsv.hue,
                    min: 0,
                    max: 360,
                    onChanged: (v) => setState(() => hsv = hsv.withHue(v)),
                  ),
                  Text('Saturation: ${(hsv.saturation * 100).round()}%'),
                  Slider(
                    value: hsv.saturation,
                    min: 0,
                    max: 1,
                    onChanged: (v) =>
                        setState(() => hsv = hsv.withSaturation(v)),
                  ),
                  Text('Brightness: ${(hsv.value * 100).round()}%'),
                  Slider(
                    value: hsv.value,
                    min: 0.2,
                    max: 1,
                    onChanged: (v) => setState(() => hsv = hsv.withValue(v)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(preview),
                child: const Text('Применить'),
              ),
            ],
          );
        },
      );
    },
  );
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
