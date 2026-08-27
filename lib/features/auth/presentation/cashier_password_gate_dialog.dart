import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/features/auth/bloc/auth_bloc.dart';
import 'package:dk_pos/features/auth/data/auth_repository.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Запрос пароля кассира/админа перед чувствительными экранами.
Future<bool> showCashierPasswordGate(
  BuildContext context, {
  String title = 'Введите пароль',
  String? subtitle,
  bool withKeypad = false,
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
      withKeypad: withKeypad,
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
    this.withKeypad = false,
  });

  final String title;
  final String? subtitle;
  final String initialUsername;
  final bool lockUsername;
  final bool withKeypad;

  @override
  State<_CashierPasswordGateDialog> createState() =>
      _CashierPasswordGateDialogState();
}

class _CashierPasswordGateDialogState
    extends State<_CashierPasswordGateDialog> {
  final _passwordCtrl = TextEditingController();
  late String _username;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _username = widget.initialUsername;
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _appendDigit(String d) {
    if (_loading) return;
    if (!RegExp(r'^[0-9]$').hasMatch(d)) return;
    if (_passwordCtrl.text.length >= 12) return;
    setState(() {
      _error = null;
      _passwordCtrl.text = '${_passwordCtrl.text}$d';
    });
  }

  void _backspace() {
    if (_loading) return;
    final t = _passwordCtrl.text;
    if (t.isEmpty) return;
    setState(() {
      _error = null;
      _passwordCtrl.text = t.substring(0, t.length - 1);
    });
  }

  void _clear() {
    if (_loading) return;
    setState(() {
      _error = null;
      _passwordCtrl.clear();
    });
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
        child: SingleChildScrollView(
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
                        .where((u) => u.role == 'cashier' || u.role == 'admin')
                        .toList(growable: false);
                    if (users.isEmpty) {
                      return TextField(
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Кассир'),
                        controller: TextEditingController(text: _username),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: users.any((u) => u.username == _username)
                          ? _username
                          : users.first.username,
                      dropdownColor: scheme.surfaceContainerHigh,
                      style: fieldStyle,
                      decoration: const InputDecoration(labelText: 'Кассир'),
                      items: users
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.username,
                              child: Text(u.username, style: fieldStyle),
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
                obscureText: _obscure,
                enabled: !_loading,
                style: fieldStyle,
                keyboardType: widget.withKeypad
                    ? TextInputType.none
                    : TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Пароль / PIN',
                  errorText: _error,
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (widget.withKeypad) ...[
                const SizedBox(height: 10),
                PosNumericKeypad(
                  showDot: false,
                  presetLabel: 'OK',
                  onDigit: _appendDigit,
                  onBackspace: _backspace,
                  onPreset: _loading ? null : _submit,
                  onClear: _clear,
                ),
              ],
            ],
          ),
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
