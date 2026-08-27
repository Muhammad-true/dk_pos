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
  /// Тихий канал только для обязательного foreground-service (без звука и вибрации).
  static const _fgChannelId = 'kitchen_bg_fg_channel';
  static const _fgChannelName = 'Kitchen service';
  static const _fgChannelDesc = 'Фоновый сервис кухни';

  /// Отдельный канал для реальных событий: новый заказ / готовность.
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
  static const _kKnownReadyIds = 'bg_kitchen_known_ready_ids';
  static const _kInitialized = 'bg_kitchen_initialized';
  static const _kKitchenSoundPath = 'bg_kitchen_sound_path';
  static const _kAudioPollCounter = 'bg_kitchen_audio_poll_counter';

  static const _fgStatusIdle = 'Кухня: ожидание заказов';

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
          _fgChannelId,
          _fgChannelName,
          description: _fgChannelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
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
          notificationChannelId: _fgChannelId,
          initialNotificationTitle: 'Doner Kebab Kitchen',
          initialNotificationContent: _fgStatusIdle,
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

  var lastForegroundStatus = await _setServiceStatusIfChanged(
    service,
    KitchenBackgroundService._fgStatusIdle,
    lastForegroundStatus: '',
  );

  Timer.periodic(const Duration(seconds: 35), (_) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(KitchenBackgroundService._kToken)?.trim() ?? '';
    if (token.isEmpty) {
      lastForegroundStatus = await _setServiceStatusIfChanged(
        service,
        'Ожидание авторизации',
        lastForegroundStatus: lastForegroundStatus,
      );
      return;
    }

    final role = _readUserRole(prefs.getString(KitchenBackgroundService._kUserJson));
    if (role != 'warehouse') {
      lastForegroundStatus = await _setServiceStatusIfChanged(
        service,
        'Ожидание входа в роль кухни',
        lastForegroundStatus: lastForegroundStatus,
      );
      return;
    }

    final baseOrigin = (prefs.getString(KitchenBackgroundService._kBgApiOrigin)?.trim().isNotEmpty == true)
        ? prefs.getString(KitchenBackgroundService._kBgApiOrigin)!.trim()
        : (prefs.getString(KitchenBackgroundService._kServerOrigin)?.trim().isNotEmpty == true)
            ? prefs.getString(KitchenBackgroundService._kServerOrigin)!.trim()
            : '';
    if (baseOrigin.isEmpty) {
      lastForegroundStatus = await _setServiceStatusIfChanged(
        service,
        'Нет адреса backend',
        lastForegroundStatus: lastForegroundStatus,
      );
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
      final pollN = (prefs.getInt(KitchenBackgroundService._kAudioPollCounter) ?? 0) + 1;
      await prefs.setInt(KitchenBackgroundService._kAudioPollCounter, pollN);
      if (pollN % 6 == 0) {
        await _refreshCachedKitchenSoundPath(dio, prefs);
      }

      final res = await dio.get('api/local/orders/queue/my');
      final body = res.data;
      if (body is! Map) {
        lastForegroundStatus = await _setServiceStatusIfChanged(
          service,
          'Очередь: некорректный ответ',
          lastForegroundStatus: lastForegroundStatus,
        );
        return;
      }

      final preparingIds = <String>{};
      final preparingNumbers = <String, String>{};
      final preparing = body['preparing'];
      if (preparing is List) {
        for (final row in preparing) {
          if (row is! Map) continue;
          final id = row['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          preparingIds.add(id);
          preparingNumbers[id] = row['number']?.toString().trim() ?? '';
        }
      }

      final readyIds = <String>{};
      final readyNumbers = <String, String>{};
      final ready = body['ready'];
      if (ready is List) {
        for (final row in ready) {
          if (row is! Map) continue;
          final id = row['id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          readyIds.add(id);
          readyNumbers[id] = row['number']?.toString().trim() ?? '';
        }
      }

      final initialized = prefs.getBool(KitchenBackgroundService._kInitialized) == true;
      final knownPreparing =
          (prefs.getStringList(KitchenBackgroundService._kKnownPreparingIds) ?? const <String>[])
              .toSet();
      final knownReady =
          (prefs.getStringList(KitchenBackgroundService._kKnownReadyIds) ?? const <String>[])
              .toSet();

      if (!initialized) {
        await prefs.setBool(KitchenBackgroundService._kInitialized, true);
        await prefs.setStringList(
          KitchenBackgroundService._kKnownPreparingIds,
          preparingIds.toList(),
        );
        await prefs.setStringList(
          KitchenBackgroundService._kKnownReadyIds,
          readyIds.toList(),
        );
        lastForegroundStatus = await _setServiceStatusIfChanged(
          service,
          KitchenBackgroundService._fgStatusIdle,
          lastForegroundStatus: lastForegroundStatus,
        );
        return;
      }

      final newPreparing = preparingIds.difference(knownPreparing);
      if (newPreparing.isNotEmpty) {
        final orderNums = newPreparing
            .map((id) => preparingNumbers[id] ?? '')
            .where((n) => n.isNotEmpty)
            .toList(growable: false);
        final bodyText = orderNums.isEmpty
            ? 'Появился новый заказ в кухне'
            : 'Новые заказы: ${orderNums.join(', ')}';
        await _showKitchenAlert(
          notifications,
          title: 'Кухня: новый заказ',
          body: bodyText,
          ticker: 'Новый заказ',
        );
      }

      final newReady = readyIds.difference(knownReady);
      if (newReady.isNotEmpty) {
        final orderNums = newReady
            .map((id) => readyNumbers[id] ?? '')
            .where((n) => n.isNotEmpty)
            .toList(growable: false);
        final bodyText = orderNums.isEmpty
            ? 'Заказ готов к выдаче'
            : 'Готовы: ${orderNums.join(', ')}';
        await _showKitchenAlert(
          notifications,
          title: 'Кухня: заказ готов',
          body: bodyText,
          ticker: 'Заказ готов',
        );
      }

      await prefs.setStringList(
        KitchenBackgroundService._kKnownPreparingIds,
        preparingIds.toList(),
      );
      await prefs.setStringList(
        KitchenBackgroundService._kKnownReadyIds,
        readyIds.toList(),
      );
      lastForegroundStatus = await _setServiceStatusIfChanged(
        service,
        KitchenBackgroundService._fgStatusIdle,
        lastForegroundStatus: lastForegroundStatus,
      );
    } catch (_) {
      lastForegroundStatus = await _setServiceStatusIfChanged(
        service,
        'Пауза: ошибка сети, повторяем...',
        lastForegroundStatus: lastForegroundStatus,
      );
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

Future<void> _refreshCachedKitchenSoundPath(Dio dio, SharedPreferences prefs) async {
  try {
    final res = await dio.get('api/local/audio-settings');
    final body = res.data;
    if (body is! Map) return;
    final settings = body['settings'];
    if (settings is! Map) return;
    final path = settings['kitchenSoundPath']?.toString().trim() ?? '';
    await prefs.setString(KitchenBackgroundService._kKitchenSoundPath, path);
  } catch (_) {}
}

/// Обновляет постоянное уведомление FGS только при смене текста (без «пульса» каждые 10 с).
Future<String> _setServiceStatusIfChanged(
  ServiceInstance service,
  String text, {
  required String lastForegroundStatus,
}) async {
  if (lastForegroundStatus == text) return lastForegroundStatus;
  await _setServiceStatus(service, text);
  return text;
}

Future<void> _showKitchenAlert(
  FlutterLocalNotificationsPlugin notifications, {
  required String title,
  required String body,
  required String ticker,
}) async {
  await notifications.show(
    KitchenBackgroundService._alertNotifBaseId +
        (DateTime.now().millisecondsSinceEpoch % 900),
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        KitchenBackgroundService._notifChannelId,
        KitchenBackgroundService._notifChannelName,
        channelDescription: KitchenBackgroundService._notifChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        onlyAlertOnce: true,
        ticker: ticker,
      ),
    ),
  );
}

Future<void> _setServiceStatus(ServiceInstance service, String text) async {
  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'Doner Kebab Kitchen',
      content: text,
    );
  }
}
