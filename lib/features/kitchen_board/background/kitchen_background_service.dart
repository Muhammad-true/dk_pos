import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dk_pos/core/config/app_config.dart';

class KitchenBackgroundService {
  static const _notifChannelId = 'kitchen_bg_channel';
  static const _notifChannelName = 'Kitchen Background Alerts';
  static const _notifChannelDesc = 'Уведомления о новых заказах кухни';
  static const _serviceNotifId = 8041;
  static const _alertNotifBaseId = 8100;

  static const _kToken = 'pos_auth_token';
  static const _kUserJson = 'pos_user_json';
  static const _kServerOrigin = 'server_api_origin';
  static const _kBgApiOrigin = 'bg_kitchen_api_origin';
  static const _kKnownPreparingIds = 'bg_kitchen_known_preparing_ids';
  static const _kInitialized = 'bg_kitchen_initialized';

  /// Остановить foreground-сервис (например после выхода кассира с устройства).
  static Future<void> stopAndroidKitchenService() async {
    if (!Platform.isAndroid) return;
    try {
      final svc = FlutterBackgroundService();
      if (await svc.isRunning()) {
        svc.invoke('stopService');
      }
    } catch (_) {}
  }

  /// Только для роли [warehouse] (экран кухни). Касса/официант — без разрешений и без FGS.
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = _readUserRole(prefs.getString(_kUserJson));
      if (role != 'warehouse') {
        await stopAndroidKitchenService();
        return;
      }

      await _syncApiOrigin();

      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final android = notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _notifChannelId,
          _notifChannelName,
          description: _notifChannelDesc,
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
      // Сразу после «Разрешить» система ещё закрывает диалог — старт FGS в этот момент даёт краш.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final notificationsEnabled = await android?.areNotificationsEnabled();
      if (notificationsEnabled == false) {
        // На Android 13+ запуск foreground-service без разрешения уведомлений
        // может приводить к аварийному завершению процесса.
        return;
      }

      final service = FlutterBackgroundService();
      final running = await service.isRunning();
      if (running) return;

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onServiceStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: _notifChannelId,
          initialNotificationTitle: 'Doner Kebab Kitchen',
          initialNotificationContent: 'Фоновый мониторинг заказов кухни',
          foregroundServiceNotificationId: _serviceNotifId,
          // Android 14+ (API 34): без типа FGS старт из Dart может падать / давать SecurityException.
          foregroundServiceTypes: const [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onServiceStart,
        ),
      );
      await service.startService();
    } catch (_) {
      // Фоновый сервис не должен ломать запуск POS.
    }
  }

  static Future<void> _syncApiOrigin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kServerOrigin)?.trim();
    final origin = (saved == null || saved.isEmpty) ? AppConfig.apiOrigin : saved;
    await prefs.setString(_kBgApiOrigin, origin);
  }
}

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((_) async {
    await service.stopSelf();
  });

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  Timer.periodic(const Duration(seconds: 10), (_) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(KitchenBackgroundService._kToken)?.trim() ?? '';
    if (token.isEmpty) {
      await _setServiceStatus(service, 'Ожидание авторизации');
      return;
    }

    final role = _readUserRole(prefs.getString(KitchenBackgroundService._kUserJson));
    if (role != 'warehouse') {
      await _setServiceStatus(service, 'Ожидание входа в роль кухни');
      return;
    }

    final baseOrigin = (prefs.getString(KitchenBackgroundService._kBgApiOrigin)?.trim().isNotEmpty == true)
        ? prefs.getString(KitchenBackgroundService._kBgApiOrigin)!.trim()
        : (prefs.getString(KitchenBackgroundService._kServerOrigin)?.trim().isNotEmpty == true)
            ? prefs.getString(KitchenBackgroundService._kServerOrigin)!.trim()
            : '';
    if (baseOrigin.isEmpty) {
      await _setServiceStatus(service, 'Нет адреса backend');
      return;
    }

    final apiBase = baseOrigin.endsWith('/') ? baseOrigin : '$baseOrigin/';
    final dio = Dio(
      BaseOptions(
        baseUrl: apiBase,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    try {
      final res = await dio.get('api/local/orders/queue/my');
      final body = res.data;
      if (body is! Map) {
        await _setServiceStatus(service, 'Очередь: некорректный ответ');
        return;
      }
      final preparing = body['preparing'];
      if (preparing is! List) {
        await _setServiceStatus(service, 'Очередь: нет данных');
        return;
      }

      final ids = <String>{};
      final numbers = <String, String>{};
      for (final row in preparing) {
        if (row is! Map) continue;
        final id = row['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        ids.add(id);
        numbers[id] = row['number']?.toString().trim() ?? '';
      }

      final initialized = prefs.getBool(KitchenBackgroundService._kInitialized) == true;
      final knownList = prefs.getStringList(KitchenBackgroundService._kKnownPreparingIds) ?? const <String>[];
      final known = knownList.toSet();

      if (!initialized) {
        await prefs.setBool(KitchenBackgroundService._kInitialized, true);
        await prefs.setStringList(KitchenBackgroundService._kKnownPreparingIds, ids.toList());
        await _setServiceStatus(service, 'Мониторинг активен (${ids.length} в работе)');
        return;
      }

      final newIds = ids.difference(known);
      if (newIds.isNotEmpty) {
        final orderNums = newIds
            .map((id) => numbers[id] ?? '')
            .where((n) => n.isNotEmpty)
            .toList(growable: false);
        final bodyText = orderNums.isEmpty
            ? 'Появился новый заказ в кухне'
            : 'Новые заказы: ${orderNums.join(', ')}';
        await notifications.show(
          KitchenBackgroundService._alertNotifBaseId +
              (DateTime.now().millisecondsSinceEpoch % 900),
          'Кухня: новый заказ',
          bodyText,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              KitchenBackgroundService._notifChannelId,
              KitchenBackgroundService._notifChannelName,
              channelDescription: KitchenBackgroundService._notifChannelDesc,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }

      await prefs.setStringList(KitchenBackgroundService._kKnownPreparingIds, ids.toList());
      await _setServiceStatus(service, 'Мониторинг активен (${ids.length} в работе)');
    } catch (_) {
      await _setServiceStatus(service, 'Пауза: ошибка сети, повторяем...');
    } finally {
      dio.close(force: true);
    }
  });
}

String _readUserRole(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded['role']?.toString().trim().toLowerCase() ?? '';
    }
  } catch (_) {}
  return '';
}

Future<void> _setServiceStatus(ServiceInstance service, String text) async {
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'Doner Kebab Kitchen',
      content: text,
    );
  }
}
