import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/update/windows_update_paths.dart';
import 'package:dk_pos/features/update/silent_update_platform.dart';
import 'package:dk_pos/features/update/silent_update_platform_stub.dart'
    if (dart.library.io) 'package:dk_pos/features/update/silent_update_platform_io.dart';
import 'package:dk_pos/features/update/silent_update_result.dart';

/// Скачивание и тихая установка backend / POS Windows / POS Android.
class SilentUpdateService {
  SilentUpdateService({
    HttpClient? http,
    SilentUpdatePlatform? platform,
    Dio? downloadDio,
  })  : _http = http,
        _platform = platform ?? createSilentUpdatePlatform(),
        _downloadDio = downloadDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 20),
                followRedirects: true,
                validateStatus: (s) => s != null && s < 500,
              ),
            );

  final HttpClient? _http;
  final SilentUpdatePlatform _platform;
  final Dio _downloadDio;

  static SilentUpdateTarget targetForAppKey(String appKey) {
    final key = appKey.trim().toLowerCase();
    if (key == 'server') return SilentUpdateTarget.server;
    if (key == 'pos_android') return SilentUpdateTarget.posAndroid;
    if (key == 'digital_menu') return SilentUpdateTarget.posAndroid;
    if (key == 'pos') {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return SilentUpdateTarget.posAndroid;
      }
      return SilentUpdateTarget.posWindows;
    }
    return SilentUpdateTarget.posWindows;
  }

  bool canSilentInstall(SilentUpdateTarget target) =>
      _platform.supportsTarget(target);

  /// Backend: через локальный API (скачивание на сервере, затем detached Inno).
  Future<SilentUpdateResult> silentInstallServer({
    required HttpClient http,
    String? downloadUrl,
  }) async {
    final body = <String, dynamic>{};
    if (downloadUrl != null && downloadUrl.trim().isNotEmpty) {
      body['downloadUrl'] = downloadUrl.trim();
    }
    final res = await http.post(
      'api/versions/server/silent-install',
      body: body,
    );
    if (res.statusCode != 200) {
      final err = res.body is Map ? res.body['error']?.toString() : null;
      return SilentUpdateResult(
        ok: false,
        message: err ??
            'Ошибка тихой установки backend (HTTP ${res.statusCode})',
      );
    }
    final data = res.body;
    if (data is Map && data['message'] != null) {
      return SilentUpdateResult(
        ok: data['ok'] == true,
        message: data['message'].toString(),
      );
    }
    return const SilentUpdateResult(
      ok: true,
      message:
          'Установщик backend запущен. Служба перезапустится через 1–3 минуты.',
    );
  }

  Future<SilentUpdateResult> silentInstallFromUrl({
    required String downloadUrl,
    required SilentUpdateTarget target,
    void Function(int received, int? total)? onProgress,
  }) async {
    final url = downloadUrl.trim();
    if (url.isEmpty) {
      return const SilentUpdateResult(
        ok: false,
        message: 'Пустая ссылка на установщик',
      );
    }
    if (!canSilentInstall(target)) {
      return SilentUpdateResult(
        ok: false,
        message:
            'Тихая установка недоступна для ${target.name} на этом устройстве',
      );
    }

    final localPath = await _downloadToCache(url, target, onProgress);
    return _platform.installDownloadedArtifact(
      localPath: localPath,
      target: target,
    );
  }

  Future<SilentUpdateResult> silentInstallAppKey({
    required String appKey,
    required String downloadUrl,
    HttpClient? http,
    void Function(int received, int? total)? onProgress,
  }) async {
    final target = targetForAppKey(appKey);
    if (target == SilentUpdateTarget.server) {
      final client = http ?? _http;
      if (client == null) {
        return const SilentUpdateResult(
          ok: false,
          message: 'Нет HTTP-клиента для установки backend',
        );
      }
      return silentInstallServer(http: client, downloadUrl: downloadUrl);
    }
    return silentInstallFromUrl(
      downloadUrl: downloadUrl,
      target: target,
      onProgress: onProgress,
    );
  }

  /// Путь к уже скачанному установщику (если есть).
  Future<String?> findCachedInstaller({
    required String appKey,
    required String downloadUrl,
  }) async {
    if (kIsWeb) return null;
    final target = targetForAppKey(appKey);
    final dest = await _resolveCachePath(downloadUrl, target);
    if (await File(dest).exists()) return dest;
    return null;
  }

  /// Тихое скачивание в кэш без установки.
  Future<String> prefetchToCache({
    required String appKey,
    required String downloadUrl,
    void Function(int received, int? total)? onProgress,
  }) async {
    final target = targetForAppKey(appKey);
    return _downloadToCache(downloadUrl, target, onProgress);
  }

  /// Удалить старые установщики этого компонента (перед скачиванием новой версии).
  Future<void> clearCachedInstallersForAppKey(String appKey) async {
    if (kIsWeb) return;
    final target = targetForAppKey(appKey);
    final base = await resolveUpdateDownloadDirectory();
    final prefix = 'dk_pos_updates_${target.name}_';
    if (!await base.exists()) return;
    await for (final entity in base.list()) {
      if (entity is! File) continue;
      if (entity.path.contains(prefix)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  /// Установка из уже скачанного файла (без повторного скачивания).
  Future<SilentUpdateResult> installCached({
    required String appKey,
    required String localPath,
  }) async {
    final target = targetForAppKey(appKey);
    if (!canSilentInstall(target)) {
      return SilentUpdateResult(
        ok: false,
        message:
            'Тихая установка недоступна для ${target.name} на этом устройстве',
      );
    }
    return _platform.installDownloadedArtifact(
      localPath: localPath,
      target: target,
    );
  }

  Future<String> _downloadToCache(
    String url,
    SilentUpdateTarget target,
    void Function(int received, int? total)? onProgress,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError('Скачивание установщика недоступно в web');
    }
    final dest = await _resolveCachePath(url, target);
    await _downloadDio.download(
      url,
      dest,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );
    return dest;
  }

  Future<String> _resolveCachePath(String url, SilentUpdateTarget target) async {
    final base = await resolveUpdateDownloadDirectory();
    final fileName = _fileNameFromUrl(url, target);
    final sep = Platform.pathSeparator;
    return '${base.path}${sep}dk_pos_updates_${target.name}_$fileName';
  }

  String _fileNameFromUrl(String url, SilentUpdateTarget target) {
    final uri = Uri.tryParse(url);
    final last =
        uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    if (last.isNotEmpty &&
        RegExp(r'\.(exe|apk)$', caseSensitive: false).hasMatch(last)) {
      return last;
    }
    return switch (target) {
      SilentUpdateTarget.server => 'doner-kebab-backend-setup.exe',
      SilentUpdateTarget.posWindows => 'doner-kebab-pos-setup.exe',
      SilentUpdateTarget.posAndroid => 'doner-kebab-pos.apk',
    };
  }
}
