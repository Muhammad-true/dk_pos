import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:dk_pos/l10n/app_localizations.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:dk_pos/core/error/api_exception.dart';

import 'package:dk_pos/features/admin/bloc/users_admin_bloc.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_event.dart';
import 'package:dk_pos/features/admin/bloc/users_admin_state.dart';
import 'package:dk_pos/features/admin/data/kitchen_type_row.dart';
import 'package:dk_pos/features/admin/data/admin_user_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_button_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_station_row.dart';
import 'package:dk_pos/features/admin/data/kitchen_buttons_repository.dart';
import 'package:dk_pos/features/admin/data/kitchen_stations_repository.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/admin/presentation/widgets/admin_list_row_card.dart';

class AdminUsersPanel extends StatelessWidget {
  const AdminUsersPanel({super.key, required this.maxBodyWidth});

  final double maxBodyWidth;

  static const _roles = ['admin', 'warehouse', 'cashier', 'expeditor', 'waiter'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;
    final selfId = context.watch<AuthBloc>().state.user?.id ?? -1;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBodyWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 560;
                  final title = Text(
                    l10n.adminUsersTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  );
                  final refresh = IconButton.filledTonal(
                    tooltip: l10n.actionRetry,
                    onPressed: () => context
                        .read<UsersAdminBloc>()
                        .add(const UsersLoadRequested()),
                    icon: const Icon(Icons.refresh_rounded),
                  );
                  final addBtn = FilledButton.icon(
                    onPressed: () => _openUserForm(context, l10n, null),
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(l10n.adminUsersAdd),
                  );
                  final kitchensBtn = OutlinedButton.icon(
                    onPressed: () => _openKitchenStationsDialog(context),
                    icon: const Icon(Icons.soup_kitchen_outlined),
                    label: const Text('Кухни'),
                  );
                  final buttonsBtn = OutlinedButton.icon(
                    onPressed: () => _openKitchenButtonsDialog(context),
                    icon: const Icon(Icons.radio_button_checked_rounded),
                    label: const Text('Кнопки'),
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: title),
                            refresh,
                          ],
                        ),
                        const SizedBox(height: 8),
                        addBtn,
                        const SizedBox(height: 8),
                        kitchensBtn,
                        const SizedBox(height: 8),
                        buttonsBtn,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: title),
                      refresh,
                      const SizedBox(width: 8),
                      addBtn,
                      const SizedBox(width: 8),
                      kitchensBtn,
                      const SizedBox(width: 8),
                      buttonsBtn,
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<UsersAdminBloc, UsersAdminState>(
                builder: (context, state) {
                  if (state.status == UsersAdminStatus.initial ||
                      (state.status == UsersAdminStatus.loading &&
                          state.users.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == UsersAdminStatus.failure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? l10n.adminUsersLoadError,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context
                                  .read<UsersAdminBloc>()
                                  .add(const UsersLoadRequested()),
                              child: Text(l10n.actionRetry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.users.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.adminUsersEmpty,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.errorMessage != null &&
                          state.status == UsersAdminStatus.loaded)
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
                                      .read<UsersAdminBloc>()
                                      .add(const UsersErrorDismissed()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (state.errorMessage != null &&
                          state.status == UsersAdminStatus.loaded)
                        const SizedBox(height: 12),
                      Expanded(
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(
                                builder: (context, c) {
                                  final wide = c.maxWidth >= 720;
                                  final fmt = DateFormat.yMMMd().add_Hm();
                                  if (wide) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SingleChildScrollView(
                                        child: DataTable(
                                          columns: [
                                            DataColumn(
                                              label: Text(l10n.fieldUsername),
                                            ),
                                            DataColumn(
                                              label: Text(l10n.fieldRole),
                                            ),
                                            const DataColumn(
                                              label: Text('Активен'),
                                            ),
                                            const DataColumn(
                                              label: Text('Кухня'),
                                            ),
                                            const DataColumn(
                                              label: Text('Кнопка'),
                                            ),
                                            DataColumn(
                                              label: Text(
                                                l10n.adminUsersColumnCreated,
                                              ),
                                            ),
                                            DataColumn(
                                              label: Text(l10n.adminUsersActions),
                                            ),
                                          ],
                                          rows: state.users.map((u) {
                                            return DataRow(
                                              cells: [
                                                DataCell(Text(u.username)),
                                                DataCell(
                                                  Text(_roleLabel(l10n, u.role)),
                                                ),
                                                DataCell(
                                                  Switch(
                                                    value: u.isActive == 1,
                                                    onChanged: u.id == selfId
                                                        ? null
                                                        : (v) => _toggleUserActive(
                                                              context,
                                                              u,
                                                              v,
                                                            ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(u.kitchenStationName ?? '—'),
                                                ),
                                                DataCell(
                                                  Text(u.kitchenButtonName ?? '—'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    u.createdAt != null
                                                        ? fmt.format(
                                                            u.createdAt!
                                                                .toLocal(),
                                                          )
                                                        : 'вЂ”',
                                                  ),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        tooltip:
                                                            l10n.adminUsersEdit,
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                        ),
                                                        onPressed: () =>
                                                            _openUserForm(
                                                          context,
                                                          l10n,
                                                          u,
                                                        ),
                                                      ),
                                                      if (u.id != selfId)
                                                        IconButton(
                                                          tooltip: l10n
                                                              .adminUsersDelete,
                                                          icon: Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .error,
                                                          ),
                                                          onPressed: () =>
                                                              _confirmDelete(
                                                            context,
                                                            l10n,
                                                            u,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 20,
                                    ),
                                    physics: kAdminListScrollPhysics,
                                    itemCount: state.users.length,
                                    itemBuilder: (context, i) {
                                      final u = state.users[i];
                                      final sub =
                                          '${u.isActive == 1 ? 'активен' : 'отключен'} · ${_roleLabel(l10n, u.role)} · ${u.kitchenStationName ?? 'без кухни'} · ${u.kitchenButtonName ?? 'без кнопки'} · ${u.createdAt != null ? fmt.format(u.createdAt!.toLocal()) : '—'}';
                                      return AdminListRowCard(
                                        child: ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          title: Text(
                                            u.username,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          subtitle: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              sub,
                                              maxLines: 1,
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
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Switch(
                                                value: u.isActive == 1,
                                                onChanged: u.id == selfId
                                                    ? null
                                                    : (v) => _toggleUserActive(
                                                          context,
                                                          u,
                                                          v,
                                                        ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                onPressed: () =>
                                                    _openUserForm(
                                                  context,
                                                  l10n,
                                                  u,
                                                ),
                                              ),
                                              if (u.id != selfId)
                                                IconButton(
                                                  icon: Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                  ),
                                                  onPressed: () =>
                                                      _confirmDelete(
                                                    context,
                                                    l10n,
                                                    u,
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

  String _roleLabel(AppLocalizations l10n, String role) {
    switch (role) {
      case 'admin':
        return l10n.roleAdmin;
      case 'warehouse':
        return l10n.roleWarehouse;
      case 'cashier':
        return l10n.roleCashier;
      case 'expeditor':
        return l10n.roleExpeditor;
      case 'waiter':
        final code = l10n.localeName.toLowerCase();
        if (code.startsWith('en')) return 'Waiter';
        if (code.startsWith('tg')) return 'Офисиант';
        return 'Официант';
      default:
        return role;
    }
  }

  Future<void> _openUserForm(
    BuildContext context,
    AppLocalizations l10n,
    AdminUserRow? existing,
  ) async {
    final bloc = context.read<UsersAdminBloc>();

    final result = await showDialog<_UserFormResult>(
      context: context,
      builder: (ctx) => _AdminUserFormDialog(
        l10n: l10n,
        existing: existing,
        roleLabelBuilder: _roleLabel,
        roles: _roles,
      ),
    );

    if (result != null && context.mounted) {
      final row = existing;
      if (row != null) {
        bloc.add(
          UserUpdateSubmitted(
            id: row.id,
            username: result.username,
            role: result.role,
            kitchenStationId: result.kitchenStationId,
            kitchenButtonId: result.kitchenButtonId,
            isActive: result.isActive,
            password: result.password?.isEmpty ?? true ? null : result.password,
          ),
        );
      } else {
        bloc.add(
          UserCreateSubmitted(
            username: result.username,
            password: result.password ?? '',
            role: result.role,
            kitchenStationId: result.kitchenStationId,
            kitchenButtonId: result.kitchenButtonId,
            isActive: result.isActive,
          ),
        );
      }
    }
  }

  void _toggleUserActive(BuildContext context, AdminUserRow u, bool active) {
    context.read<UsersAdminBloc>().add(
          UserUpdateSubmitted(
            id: u.id,
            username: u.username,
            role: u.role,
            isActive: active ? 1 : 0,
            kitchenStationId: u.kitchenStationId,
            kitchenButtonId: u.kitchenButtonId,
          ),
        );
  }

  Future<void> _openKitchenStationsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _KitchenStationsDialog(),
    );
  }

  Future<void> _openKitchenButtonsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _KitchenButtonsDialog(),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppLocalizations l10n,
    AdminUserRow u,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminUsersDelete),
        content: Text(l10n.adminUsersConfirmDelete(u.username)),
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
            child: Text(l10n.adminUsersDelete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<UsersAdminBloc>().add(UserDeleteSubmitted(u.id));
    }
  }
}

class _AdminUserFormDialog extends StatefulWidget {
  const _AdminUserFormDialog({
    required this.l10n,
    required this.existing,
    required this.roleLabelBuilder,
    required this.roles,
  });

  final AppLocalizations l10n;
  final AdminUserRow? existing;
  final String Function(AppLocalizations l10n, String role) roleLabelBuilder;
  final List<String> roles;

  @override
  State<_AdminUserFormDialog> createState() => _AdminUserFormDialogState();
}

class _AdminUserFormDialogState extends State<_AdminUserFormDialog> {
  static const int _newKitchenStationValue = -1;
  static const int _newKitchenButtonValue = -2;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();
  late String _role;
  List<KitchenStationRow> _stations = const [];
  List<KitchenButtonRow> _buttons = const [];
  bool _stationsLoading = true;
  bool _buttonsLoading = true;
  int? _kitchenStationId;
  int? _kitchenButtonId;
  bool _isActive = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.existing?.username ?? '',
    );
    _passwordController = TextEditingController();
    _role = widget.existing?.role ?? 'cashier';
    _kitchenStationId = widget.existing?.kitchenStationId;
    _kitchenButtonId = widget.existing?.kitchenButtonId;
    _isActive = (widget.existing?.isActive ?? 1) == 1;
    _loadStations();
    _loadButtons();
  }

  Future<void> _loadStations() async {
    try {
      final repo = context.read<KitchenStationsRepository>();
      final list = await repo.fetchStations();
      if (!mounted) return;
      setState(() {
        _stations = list.where((e) => e.isActive == 1).toList();
        _stationsLoading = false;
        if (_kitchenStationId != null &&
            !_stations.any((e) => e.id == _kitchenStationId)) {
          _kitchenStationId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stations = const [];
        _stationsLoading = false;
      });
    }
  }

  Future<void> _loadButtons() async {
    try {
      final repo = context.read<KitchenButtonsRepository>();
      final list = await repo.fetchButtons();
      if (!mounted) return;
      setState(() {
        _buttons = list.where((e) => e.isActive == 1).toList();
        _buttonsLoading = false;
        if (_kitchenButtonId != null &&
            !_buttons.any((e) => e.id == _kitchenButtonId)) {
          _kitchenButtonId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buttons = const [];
        _buttonsLoading = false;
      });
    }
  }

  Future<void> _createKitchenInline() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _KitchenStationsDialog(),
    );
    if (created == true) {
      await _loadStations();
    }
  }

  Future<void> _createKitchenButtonInline() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _KitchenButtonsDialog(),
    );
    if (created == true) {
      await _loadButtons();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _UserFormResult(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _role,
        isActive: _isActive ? 1 : 0,
        kitchenStationId: _role == 'warehouse' ? _kitchenStationId : null,
        kitchenButtonId: _role == 'warehouse' ? _kitchenButtonId : null,
      ),
    );
  }

  String _kitchenTypeLabel(String type) {
    switch (type) {
      case 'pizza':
        return 'Пицца';
      case 'inside':
        return 'Внутренняя';
      case 'outside':
        return 'Внешняя';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(_isEdit ? l10n.adminUsersEdit : l10n.adminUsersAdd),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: l10n.fieldUsername),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? l10n.fieldUsernameError
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.fieldPassword,
                    hintText: _isEdit ? l10n.adminUsersPasswordOptional : null,
                  ),
                  validator: (v) {
                    if (!_isEdit && (v == null || v.length < 6)) {
                      return l10n.adminUsersPasswordMin;
                    }
                    if (_isEdit && v != null && v.isNotEmpty && v.length < 6) {
                      return l10n.adminUsersPasswordMin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.fieldRole,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final roleSegments = widget.roles
                        .map(
                          (r) => ButtonSegment<String>(
                            value: r,
                            label: Text(widget.roleLabelBuilder(l10n, r)),
                          ),
                        )
                        .toList();
                    final wide =
                        MediaQuery.sizeOf(context).width >= 480;
                    if (wide) {
                      return SegmentedButton<String>(
                        segments: roleSegments,
                        selected: {_role},
                        onSelectionChanged: (s) {
                          if (s.isNotEmpty) {
                            setState(() => _role = s.first);
                          }
                        },
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.roles.map((r) {
                        final selected = _role == r;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ChoiceChip(
                            label: Text(widget.roleLabelBuilder(l10n, r)),
                            selected: selected,
                            onSelected: (v) {
                              if (v) setState(() => _role = r);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Активный пользователь'),
                  subtitle: Text(
                    _isActive
                        ? 'Показывается в списке логина'
                        : 'Скрыт из списка логина',
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                if (_role == 'warehouse') ...[
                  const SizedBox(height: 12),
                  if (_stationsLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: _kitchenStationId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Кухня',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Выберите кухню',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ..._stations.map(
                          (s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(
                              '${s.name} (${_kitchenTypeLabel(s.type)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const DropdownMenuItem<int?>(
                          value: _newKitchenStationValue,
                          child: Text('(новый)'),
                        ),
                      ],
                      selectedItemBuilder: (context) {
                        return [
                          Text(
                            'Выберите кухню',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          ..._stations.map((s) {
                            return Text(
                              '${s.name} (${_kitchenTypeLabel(s.type)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            );
                          }),
                        ];
                      },
                      onChanged: (v) async {
                        if (v == _newKitchenStationValue) {
                          await _createKitchenInline();
                          return;
                        }
                        if (!mounted) return;
                        setState(() => _kitchenStationId = v);
                      },
                      validator: (v) {
                        if (_role == 'warehouse' && v == null) {
                          return 'Для сотрудника кухни выберите кухню';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 12),
                  if (_buttonsLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<int?>(
                      initialValue: _kitchenButtonId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Кнопка',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Выберите кнопку',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ..._buttons.map(
                          (b) => DropdownMenuItem<int?>(
                            value: b.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _kitchenButtonColorFromHex(b.colorHex),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    b.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const DropdownMenuItem<int?>(
                          value: _newKitchenButtonValue,
                          child: Text('(новая)'),
                        ),
                      ],
                      onChanged: (v) async {
                        if (v == _newKitchenButtonValue) {
                          await _createKitchenButtonInline();
                          return;
                        }
                        if (!mounted) return;
                        setState(() => _kitchenButtonId = v);
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _UserFormResult {
  const _UserFormResult({
    required this.username,
    required this.password,
    required this.role,
    required this.isActive,
    required this.kitchenStationId,
    required this.kitchenButtonId,
  });

  final String username;
  final String? password;
  final String role;
  final int isActive;
  final int? kitchenStationId;
  final int? kitchenButtonId;
}

class _KitchenButtonColorOption {
  const _KitchenButtonColorOption({
    required this.name,
    required this.hex,
    required this.color,
  });

  final String name;
  final String hex;
  final Color color;
}

const _kitchenButtonColorOptions = <_KitchenButtonColorOption>[
  _KitchenButtonColorOption(name: 'Красный', hex: '#E53935', color: Color(0xFFE53935)),
  _KitchenButtonColorOption(name: 'Зеленый', hex: '#2E7D32', color: Color(0xFF2E7D32)),
  _KitchenButtonColorOption(name: 'Синий', hex: '#1565C0', color: Color(0xFF1565C0)),
  _KitchenButtonColorOption(name: 'Оранжевый', hex: '#EF6C00', color: Color(0xFFEF6C00)),
  _KitchenButtonColorOption(name: 'Фиолетовый', hex: '#7B1FA2', color: Color(0xFF7B1FA2)),
  _KitchenButtonColorOption(name: 'Бирюзовый', hex: '#00897B', color: Color(0xFF00897B)),
];

_KitchenButtonColorOption? _kitchenButtonColorByHex(String? hex) {
  final target = (hex ?? '').trim().toUpperCase();
  for (final option in _kitchenButtonColorOptions) {
    if (option.hex == target) return option;
  }
  return null;
}

String _kitchenButtonColorName(String? hex) =>
    _kitchenButtonColorByHex(hex)?.name ?? 'Другой цвет';

Color _kitchenButtonColorFromHex(String? hex) {
  final option = _kitchenButtonColorByHex(hex);
  if (option != null) return option.color;
  final normalized = (hex ?? '').trim().toUpperCase();
  if (RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized)) {
    return Color(int.parse(normalized.replaceFirst('#', '0xFF')));
  }
  return _kitchenButtonColorOptions.first.color;
}

class _KitchenButtonsDialog extends StatefulWidget {
  const _KitchenButtonsDialog();

  @override
  State<_KitchenButtonsDialog> createState() => _KitchenButtonsDialogState();
}

class _KitchenButtonsDialogState extends State<_KitchenButtonsDialog> {
  final _nameCtrl = TextEditingController();
  final _sortCtrl = TextEditingController(text: '0');
  String _selectedColorHex = _kitchenButtonColorOptions.first.hex;
  bool _busy = false;
  List<KitchenButtonRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final rows = await context.read<KitchenButtonsRepository>().fetchButtons();
      if (!mounted) return;
      setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final color = _selectedColorHex;
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    if (name.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<KitchenButtonsRepository>().createButton(
            name: name,
            colorHex: color,
            sortOrder: sort,
            isActive: 1,
          );
      _nameCtrl.clear();
      _selectedColorHex = _kitchenButtonColorOptions.first.hex;
      _sortCtrl.text = '0';
      await _reload();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(KitchenButtonRow row, bool value) async {
    try {
      await context.read<KitchenButtonsRepository>().updateButton(
            row.id,
            isActive: value ? 1 : 0,
          );
      await _reload();
    } catch (_) {}
  }

  Future<void> _delete(KitchenButtonRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<KitchenButtonsRepository>().deleteButton(row.id);
      await _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final addButton = FilledButton(
      onPressed: _busy ? null : _create,
      child: const Text('Добавить'),
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          width: math.min(560, MediaQuery.sizeOf(context).width * 0.96),
          height: math.min(520, MediaQuery.sizeOf(context).height * 0.86),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Кнопки кухни',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название кнопки',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _sortCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Порядок',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    addButton,
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Цвет кнопки',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _kitchenButtonColorOptions.map((option) {
                    final selected = _selectedColorHex == option.hex;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _busy
                            ? null
                            : () => setState(() => _selectedColorHex = option.hex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 168,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: selected
                                ? option.color.withValues(alpha: 0.18)
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: selected
                                  ? option.color
                                  : Theme.of(context).colorScheme.outlineVariant,
                              width: selected ? 2.4 : 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: option.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  option.name,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: option.color,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _busy && _rows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final row = _rows[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _kitchenButtonColorFromHex(row.colorHex),
                              ),
                              title: Text(row.name),
                              subtitle: Text(_kitchenButtonColorName(row.colorHex)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: row.isActive == 1,
                                    onChanged: (v) => _setActive(row, v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    onPressed: () => _delete(row),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KitchenStationsDialog extends StatefulWidget {
  const _KitchenStationsDialog();

  @override
  State<_KitchenStationsDialog> createState() => _KitchenStationsDialogState();
}

class _KitchenStationsDialogState extends State<_KitchenStationsDialog> {
  static const String _newTypeValue = '__new__';
  final _nameCtrl = TextEditingController();
  final _sortCtrl = TextEditingController(text: '0');
  String _type = '';
  List<KitchenTypeRow> _types = const [];
  bool _busy = false;
  List<KitchenStationRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  String _typeLabel(String type) {
    final m = _types.where((t) => t.code == type);
    if (m.isNotEmpty) return m.first.name;
    return type;
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final repo = context.read<KitchenStationsRepository>();
      final list = await repo.fetchStations();
      final types = await repo.fetchTypes();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _types = types;
        if (_type.isEmpty && _types.isNotEmpty) {
          _type = _types.first.code;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTypeInline() async {
    final typeNameCtrl = TextEditingController();
    final typeCodeCtrl = TextEditingController();
    final created = await showDialog<KitchenTypeRow>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый тип кухни'),
        content: SizedBox(
          width: math.min(360, MediaQuery.sizeOf(ctx).width * 0.94),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: typeCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Код (latin)',
                  hintText: 'например: grill',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final code = typeCodeCtrl.text.trim().toLowerCase();
              final name = typeNameCtrl.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              try {
                final row = await context.read<KitchenStationsRepository>().createType(
                  code: code,
                  name: name,
                  isActive: 1,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, row);
              } on ApiException catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    typeNameCtrl.dispose();
    typeCodeCtrl.dispose();
    if (created != null) {
      await _reload();
      if (!mounted) return;
      setState(() => _type = created.code);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_type.isEmpty) return;
    final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final repo = context.read<KitchenStationsRepository>();
      await repo.createStation(
        name: name,
        type: _type,
        sortOrder: sort,
        isActive: 1,
      );
      _nameCtrl.clear();
      _sortCtrl.text = '0';
      await _reload();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(KitchenStationRow row, bool value) async {
    try {
      await context
          .read<KitchenStationsRepository>()
          .updateStation(row.id, isActive: value ? 1 : 0);
      await _reload();
    } catch (_) {}
  }

  Future<void> _delete(KitchenStationRow row) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<KitchenStationsRepository>().deleteStation(row.id);
      await _reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeField = DropdownButtonFormField<String>(
      initialValue: _type.isEmpty ? null : _type,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Тип кухни',
        border: OutlineInputBorder(),
      ),
      items: [
        ..._types
          .map(
            (t) => DropdownMenuItem(
              value: t.code,
              child: Text(t.name),
            ),
          ),
        const DropdownMenuItem<String>(
          value: _newTypeValue,
          child: Text('(новый тип)'),
        ),
      ],
      onChanged: _busy
          ? null
          : (v) async {
              if (v == null) return;
              if (v == _newTypeValue) {
                await _createTypeInline();
                return;
              }
              setState(() => _type = v);
            },
    );
    final sortField = TextField(
      controller: _sortCtrl,
      decoration: const InputDecoration(
        labelText: 'Порядок',
        border: OutlineInputBorder(),
      ),
    );
    final addButton = FilledButton(
      onPressed: _busy ? null : _create,
      child: const Text('Добавить'),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SizedBox(
          width: math.min(600, MediaQuery.sizeOf(context).width * 0.96),
          height: math.min(560, MediaQuery.sizeOf(context).height * 0.88),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Кухни',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Название кухни',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: math.min(320, MediaQuery.sizeOf(context).width * 0.8),
                      child: typeField,
                    ),
                    SizedBox(width: 120, child: sortField),
                    addButton,
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _busy && _rows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, i) {
                            final row = _rows[i];
                            return ListTile(
                              title: Text(row.name),
                              subtitle: Text(_typeLabel(row.type)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: row.isActive == 1,
                                    onChanged: (v) => _setActive(row, v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    onPressed: () => _delete(row),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
