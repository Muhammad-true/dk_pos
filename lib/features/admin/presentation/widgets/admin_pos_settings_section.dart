import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dk_pos/app/pos_board_layout/pos_board_layout_cubit.dart';
import 'package:dk_pos/features/admin/data/local_pos_settings_repository.dart';
import 'package:dk_pos/features/pos/presentation/widgets/pos_board_layout_settings_editor.dart';

class AdminPosSettingsSection extends StatefulWidget {
  const AdminPosSettingsSection({super.key});

  @override
  State<AdminPosSettingsSection> createState() =>
      _AdminPosSettingsSectionState();
}

class _AdminPosSettingsSectionState extends State<AdminPosSettingsSection> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _allowManualDiscount = false;
  bool _freeTableOnPayment = false;
  bool _courierDeliveryEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalPosSettingsRepository>();
      final s = await repo.fetch();
      if (!mounted) return;
      setState(() {
        _allowManualDiscount = s.allowManualDiscount;
        _freeTableOnPayment = s.freeTableOnPayment;
        _courierDeliveryEnabled = s.courierDeliveryEnabled;
        _loading = false;
      });
      unawaited(context.read<PosBoardLayoutCubit>().refresh());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveDiscount(bool allow) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalPosSettingsRepository>();
      final s = await repo.update(allowManualDiscount: allow);
      if (!mounted) return;
      setState(() {
        _allowManualDiscount = s.allowManualDiscount;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки кассы сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _saveFreeTableOnPayment(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = context.read<LocalPosSettingsRepository>();
      final s = await repo.update(freeTableOnPayment: enabled);
      if (!mounted) return;
      setState(() {
        _freeTableOnPayment = s.freeTableOnPayment;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки кассы сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _saveCourierDelivery(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final s = await context.read<LocalPosSettingsRepository>().update(
        courierDeliveryEnabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _courierDeliveryEnabled = s.courierDeliveryEnabled;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки кассы сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Ошибка: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Разрешить ручную скидку на кассе'),
              subtitle: const Text(
                'Если включено, кассир сможет вводить любую сумму скидки при оформлении заказа.',
              ),
              value: _allowManualDiscount,
              onChanged: _saving ? null : _saveDiscount,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Освобождать стол при оплате'),
              subtitle: const Text(
                'Сейчас всегда: после оплаты стол на карте кассы свободен '
                '(занят только неоплаченный счёт), а номер стола остаётся на заказе '
                'для кухни и истории. Переключатель сохранён для совместимости.',
              ),
              value: _freeTableOnPayment,
              onChanged: _saving ? null : _saveFreeTableOnPayment,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Курьеры сегодня работают'),
              subtitle: const Text(
                'Если выключено, доставка помечается «по счётчику» и не появится у курьеров.',
              ),
              value: _courierDeliveryEnabled,
              onChanged: _saving ? null : _saveCourierDelivery,
            ),
            const Divider(height: 28),
            const PosBoardLayoutSettingsEditor(),
            const SizedBox(height: 8),
            Text(
              'Те же переключатели есть в «Настройки» на кассе — кассир может менять сам.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
