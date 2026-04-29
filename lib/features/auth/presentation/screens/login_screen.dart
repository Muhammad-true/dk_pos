import 'package:auto_route/auto_route.dart';
import 'package:dk_pos/app/locale/locale_bloc.dart';
import 'package:dk_pos/app/locale/locale_event.dart';
import 'package:dk_pos/core/layout/window_layout.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/bloc/auth_event.dart';
import 'package:dk_pos/features/auth/bloc/auth_state.dart';
import 'package:dk_pos/features/auth/data/auth_remote_data_source.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';
import 'package:dk_pos/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<LoginUserOption> _users = const [];
  String? _selectedUsername;
  bool _usersLoading = true;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    _loadLoginUsers();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLoginUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final repo = context.read<AuthRepository>();
      final users = await repo.fetchLoginUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _selectedUsername = users.isNotEmpty ? users.first.username : null;
        _usersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _selectedUsername = null;
        _usersLoading = false;
        _usersError = e.toString();
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final username = _selectedUsername?.trim() ?? '';
    if (username.isEmpty) return;
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: username,
        password: _passCtrl.text,
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'warehouse':
        return 'Кухня';
      case 'cashier':
        return 'Касса';
      case 'expeditor':
        return 'Экспедитор';
      case 'waiter':
        return 'Официант';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appL10n;

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          p.loginError != c.loginError && c.loginError != null,
      listener: (context, state) {
        final msg = state.loginError;
        if (msg != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (p, c) =>
            p.status != c.status || p.loginError != c.loginError,
        builder: (context, state) {
          final loading = state.status == AuthStatus.authenticating;
          final scheme = Theme.of(context).colorScheme;
          final btnStyle = FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          );
          return Scaffold(
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = WindowLayout(width: constraints.maxWidth);
                    final form = Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!layout.loginSplitHero) ...[
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/img/icon_logo.PNG',
                                    height: layout.isCompact ? 104 : 128,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  SizedBox(height: layout.isCompact ? 12 : 16),
                                  Text(
                                    l10n.loginSubtitle,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: layout.isCompact ? 24 : 32),
                          ],
                          Text(
                            l10n.loginFormIntro,
                            textAlign: layout.loginSplitHero
                                ? TextAlign.start
                                : TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                          SizedBox(height: layout.isCompact ? 16 : 20),
                          if (_usersLoading)
                            DropdownButtonFormField<String>(
                              initialValue: null,
                              onChanged: null,
                              decoration: InputDecoration(
                                labelText: l10n.fieldUsername,
                                border: const OutlineInputBorder(),
                              ),
                              hint: const Text('Загрузка пользователей...'),
                              items: const [],
                            )
                          else
                            DropdownButtonFormField<String>(
                              key: ValueKey<String?>('login-user-${_selectedUsername ?? "none"}'),
                              initialValue: _selectedUsername,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: l10n.fieldUsername,
                                border: const OutlineInputBorder(),
                              ),
                              items: _users
                                  .map(
                                    (u) => DropdownMenuItem<String>(
                                      value: u.username,
                                      child: Text('${u.username} (${_roleLabel(u.role)})'),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: loading
                                  ? null
                                  : (v) => setState(() => _selectedUsername = v),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.fieldUsernameError
                                  : null,
                            ),
                          if (_usersError != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Не удалось загрузить список логинов',
                                    style: TextStyle(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadLoginUsers,
                                  child: const Text('Повторить'),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: true,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: l10n.fieldPassword,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? l10n.fieldPasswordError
                                : null,
                          ),
                          SizedBox(height: layout.isCompact ? 24 : 28),
                          FilledButton(
                            style: btnStyle,
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.login_rounded, size: 22),
                                      const SizedBox(width: 10),
                                      Text(l10n.actionSignIn),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );

                    final padH = layout.loginComfortableHorizontalPadding
                        ? 40.0
                        : 20.0;
                    final maxFormW = layout.isCompact
                        ? 400.0
                        : layout.loginSplitHero
                        ? 420.0
                        : 460.0;

                    if (layout.loginSplitHero) {
                      return Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.primary,
                                    Color.lerp(
                                          scheme.primary,
                                          scheme.surface,
                                          0.25,
                                        ) ??
                                        scheme.primary,
                                  ],
                                ),
                              ),
                              child: SafeArea(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/img/icon_logo.PNG',
                                        height: 260,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      const SizedBox(height: 28),
                                      Text(
                                        l10n.loginSubtitle,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: scheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: padH,
                                  vertical: 24,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: maxFormW,
                                  ),
                                  child: form,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: padH,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxFormW),
                          child: form,
                        ),
                      ),
                    );
                  },
                ),
                SafeArea(
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
                      child: PopupMenuButton<Locale>(
                        icon: const Icon(Icons.language_rounded),
                        onSelected: (loc) {
                          context.read<LocaleBloc>().add(LocaleChanged(loc));
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: const Locale('ru'),
                            child: Text(l10n.languageRu),
                          ),
                          PopupMenuItem(
                            value: const Locale('en'),
                            child: Text(l10n.languageEn),
                          ),
                          PopupMenuItem(
                            value: const Locale('tg'),
                            child: Text(l10n.languageTg),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
