import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';

/// Запрос пароля кассира/админа перед чувствительными экранами.
Future<bool> showCashierPasswordGate(
  BuildContext context, {
  String title = 'Введите пароль',
  String? subtitle,
}) async {
  final user = context.read<AuthBloc>().state.user;
  if (user == null) return false;
  final role = user.role.toLowerCase();
  if (role != 'cashier' && role != 'admin') return false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CashierPasswordGateDialog(
      title: title,
      subtitle: subtitle,
      initialUsername: user.username,
      lockUsername: role == 'cashier',
    ),
  );
  return ok == true;
}

class _CashierPasswordGateDialog extends StatefulWidget {
  const _CashierPasswordGateDialog({
    required this.title,
    required this.initialUsername,
    required this.lockUsername,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String initialUsername;
  final bool lockUsername;

  @override
  State<_CashierPasswordGateDialog> createState() =>
      _CashierPasswordGateDialogState();
}

class _CashierPasswordGateDialogState extends State<_CashierPasswordGateDialog> {
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  late String _username;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username = widget.initialUsername;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _passwordFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordCtrl.text;
    if (password.trim().isEmpty) {
      setState(() => _error = 'Введите пароль');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthRepository>().verifyPassword(
            password: password,
            username: widget.lockUsername ? widget.initialUsername : _username,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      _passwordCtrl.clear();
      _passwordFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка проверки: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldStyle = theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurface,
    );
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subtitle != null) ...[
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.lockUsername)
              FutureBuilder(
                future: context.read<AuthRepository>().fetchLoginUsers(),
                builder: (context, snap) {
                  final users = (snap.data ?? const [])
                      .where(
                        (u) =>
                            u.role == 'cashier' || u.role == 'admin',
                      )
                      .toList(growable: false);
                  if (users.isEmpty) {
                    return TextField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Кассир',
                      ),
                      controller: TextEditingController(text: _username),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: users.any((u) => u.username == _username)
                        ? _username
                        : users.first.username,
                    dropdownColor: scheme.surfaceContainerHigh,
                    style: fieldStyle,
                    decoration: const InputDecoration(labelText: 'Кассир'),
                    items: users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u.username,
                            child: Text(
                              u.username,
                              style: fieldStyle,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _loading
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => _username = v);
                          },
                  );
                },
              )
            else
              TextField(
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Кассир'),
                controller: TextEditingController(text: _username),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              enabled: !_loading,
              style: fieldStyle,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Пароль',
                errorText: _error,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Войти'),
        ),
      ],
    );
  }
}
