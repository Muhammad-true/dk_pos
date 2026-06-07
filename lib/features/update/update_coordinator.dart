import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:dk_pos/app/app_update_info.dart';
import 'package:dk_pos/core/network/http_client.dart';
import 'package:dk_pos/features/admin/data/app_version_row.dart';
import 'package:dk_pos/features/admin/data/app_versions_repository.dart';
import 'package:dk_pos/features/update/pending_app_update.dart';
import 'package:dk_pos/features/update/silent_update_result.dart';
import 'package:dk_pos/features/update/silent_update_service.dart';

/// Фоновая проверка релизов, тихое скачивание и очередь готовых обновлений.
///
/// «Позже» скрывает панель только до перезапуска приложения.
/// Если вышла более новая версия — панель снова показывается (без «Позже»).
class UpdateCoordinator extends ChangeNotifier {
  UpdateCoordinator({
    SilentUpdateService? silentUpdate,
  }) : _silentUpdate = silentUpdate ?? SilentUpdateService();

  final SilentUpdateService _silentUpdate;

  HttpClient? _http;
  AppVersionsRepository? _versionsRepo;
  Timer? _pollTimer;

  bool _checking = false;
  bool _installing = false;
  String? _installedVersionText;
  final List<PendingAppUpdate> _readyQueue = [];

  /// appKey → версия, которую пользователь отложил в этой сессии.
  final Map<String, String> _sessionDismissedVersion = {};
  final Set<String> _downloadingKeys = {};

  PendingAppUpdate? get currentReady {
    for (final item in _readyQueue) {
      if (_isVisibleAfterDismiss(item)) return item;
    }
    return null;
  }

  /// Можно ли скрыть текущее обновление кнопкой «Позже».
  bool get canDismissCurrent {
    final current = currentReady;
    if (current == null) return false;
    final key = current.appKey.trim().toLowerCase();
    final dismissed = (_sessionDismissedVersion[key] ?? '').trim();
    if (dismissed.isEmpty) return true;
    // Более новая версия — только «Установить».
    return compareVersions(dismissed, current.targetVersion) >= 0;
  }

  bool get isInstalling => _installing;
  bool get isChecking => _checking;

  void bind({
    required HttpClient http,
    required AppVersionsRepository versionsRepo,
  }) {
    if (_http == http && _versionsRepo == versionsRepo) return;
    _http = http;
    _versionsRepo = versionsRepo;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(refresh());
    });
    Future<void>.delayed(const Duration(seconds: 4), () {
      unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void dismissCurrent() {
    if (!canDismissCurrent) return;
    final current = currentReady;
    if (current == null) return;
    _sessionDismissedVersion[current.appKey.trim().toLowerCase()] =
        current.targetVersion;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_checking || !_supportsUpdates) return;
    final http = _http;
    final repo = _versionsRepo;
    if (http == null || repo == null) return;

    _checking = true;
    try {
      await _reportInstalledVersions(http);
      final versions = await repo.fetchVersions();
      final pending = _collectPending(versions);
      _pruneStaleDismissals(pending);
      for (final row in pending) {
        await _prefetchIfNeeded(row);
      }
      await _rebuildReadyQueue(pending);
      notifyListeners();
    } catch (_) {
      // Тихо — повторим при следующем опросе.
    } finally {
      _checking = false;
    }
  }

  Future<SilentUpdateResult?> installCurrent() async {
    final item = currentReady;
    if (item == null || _installing) return null;
    _installing = true;
    notifyListeners();
    SilentUpdateResult? result;
    try {
      result = await _silentUpdate.installCached(
        appKey: item.appKey,
        localPath: item.localPath,
      );
      if (result.ok) {
        _readyQueue.removeWhere(
          (e) =>
              e.appKey == item.appKey &&
              e.targetVersion == item.targetVersion,
        );
        _sessionDismissedVersion.remove(item.appKey.trim().toLowerCase());
      }
      notifyListeners();
      return result;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  bool _isVisibleAfterDismiss(PendingAppUpdate item) {
    final key = item.appKey.trim().toLowerCase();
    final dismissed = (_sessionDismissedVersion[key] ?? '').trim();
    if (dismissed.isEmpty) return true;
    return compareVersions(dismissed, item.targetVersion) < 0;
  }

  /// Если на сервере target вырос — сбрасываем отложенную старую версию.
  void _pruneStaleDismissals(List<AppVersionRow> pending) {
    for (final row in pending) {
      final key = row.appKey.trim().toLowerCase();
      final dismissed = (_sessionDismissedVersion[key] ?? '').trim();
      final target = (row.targetVersion ?? '').trim();
      if (dismissed.isEmpty || target.isEmpty) continue;
      if (compareVersions(dismissed, target) < 0) {
        _sessionDismissedVersion.remove(key);
      }
    }
  }

  bool get _supportsUpdates {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isAndroid;
  }

  List<String> _applicableAppKeys() {
    if (kIsWeb) return const [];
    if (Platform.isAndroid) return const ['pos_android'];
    if (Platform.isWindows) return const ['server', 'pos'];
    return const [];
  }

  Future<void> _reportInstalledVersions(HttpClient http) async {
    final info = await PackageInfo.fromPlatform();
    final versionText = '${info.version}+${info.buildNumber}';
    _installedVersionText = versionText;

    final keys = _applicableAppKeys();
    for (final key in keys) {
      if (key == 'server') continue;
      try {
        await http.post(
          'api/versions/report',
          body: {
            'appKey': key,
            'displayName': key == 'pos_android' ? 'dk_pos Android' : 'dk_pos',
            'currentVersion': versionText,
          },
        );
      } catch (_) {}
    }
  }

  List<AppVersionRow> _collectPending(List<AppVersionRow> versions) {
    final keys = _applicableAppKeys().toSet();
    final out = <AppVersionRow>[];
    for (final row in versions) {
      final key = row.appKey.trim().toLowerCase();
      if (!keys.contains(key)) continue;
      final target = (row.targetVersion ?? '').trim();
      final url = (row.downloadUrl ?? '').trim();
      if (target.isEmpty || url.isEmpty) continue;

      final current = key == 'server'
          ? (row.currentVersion ?? '').trim()
          : (_installedVersionText ?? row.currentVersion ?? '').trim();
      if (compareVersions(current, target) >= 0) continue;
      if (!_silentUpdate.canSilentInstall(
        SilentUpdateService.targetForAppKey(key),
      )) {
        continue;
      }
      out.add(row);
    }
    out.sort(
      (a, b) => _priority(a.appKey).compareTo(_priority(b.appKey)),
    );
    return out;
  }

  int _priority(String appKey) => switch (appKey.trim().toLowerCase()) {
        'server' => 0,
        'pos' => 1,
        'pos_android' => 2,
        'digital_menu' => 3,
        _ => 9,
      };

  Future<void> _prefetchIfNeeded(AppVersionRow row) async {
    final key = row.appKey.trim().toLowerCase();
    if (_downloadingKeys.contains(key)) return;

    final url = row.downloadUrl!.trim();
    final cached = await _silentUpdate.findCachedInstaller(
      appKey: key,
      downloadUrl: url,
    );
    if (cached != null) return;

    _downloadingKeys.add(key);
    try {
      await _silentUpdate.clearCachedInstallersForAppKey(key);
      await _silentUpdate.prefetchToCache(appKey: key, downloadUrl: url);
    } catch (_) {
      // Нет сети — попробуем позже.
    } finally {
      _downloadingKeys.remove(key);
    }
  }

  Future<void> _rebuildReadyQueue(List<AppVersionRow> pending) async {
    final ready = <PendingAppUpdate>[];
    for (final row in pending) {
      final key = row.appKey.trim().toLowerCase();
      final url = row.downloadUrl!.trim();
      final target = row.targetVersion!.trim();
      final path = await _silentUpdate.findCachedInstaller(
        appKey: key,
        downloadUrl: url,
      );
      if (path == null) continue;
      ready.add(
        PendingAppUpdate(
          appKey: key,
          displayName: _displayName(key, row.displayName),
          targetVersion: target,
          downloadUrl: url,
          localPath: path,
          isMandatory: row.isMandatory,
        ),
      );
    }
    ready.sort((a, b) => a.priority.compareTo(b.priority));
    _readyQueue
      ..clear()
      ..addAll(ready);
  }

  String _displayName(String appKey, String fallback) {
    return switch (appKey) {
      'server' => 'DK сервер',
      'pos' => 'DK POS касса',
      'pos_android' => 'DK POS Android',
      'digital_menu' => 'DK TV меню',
      _ => fallback.trim().isNotEmpty ? fallback : appKey,
    };
  }
}
