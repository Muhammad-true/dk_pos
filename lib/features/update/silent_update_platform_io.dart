import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import 'package:dk_pos/features/update/silent_update_platform.dart';
import 'package:dk_pos/features/update/silent_update_result.dart';
import 'package:dk_pos/features/update/windows_update_paths.dart';

const _channel = MethodChannel('dk_pos/silent_update');

class SilentUpdatePlatformImpl implements SilentUpdatePlatform {
  @override
  bool supportsTarget(SilentUpdateTarget target) {
    if (kIsWeb) return false;
    return switch (target) {
      SilentUpdateTarget.server => Platform.isWindows,
      SilentUpdateTarget.posWindows => Platform.isWindows,
      SilentUpdateTarget.posAndroid => Platform.isAndroid,
    };
  }

  @override
  Future<SilentUpdateResult> installDownloadedArtifact({
    required String localPath,
    required SilentUpdateTarget target,
  }) async {
    if (!supportsTarget(target)) {
      return const SilentUpdateResult(
        ok: false,
        message: 'Тихая установка недоступна на этой платформе',
      );
    }

    if (Platform.isAndroid && target == SilentUpdateTarget.posAndroid) {
      try {
        final ok = await _channel.invokeMethod<bool>(
          'installApk',
          <String, dynamic>{'path': localPath},
        );
        if (ok == true) {
          return const SilentUpdateResult(
            ok: true,
            message:
                'Установка APK запущена. Подтвердите установку в системном диалоге (один раз).',
            needsUserAction: true,
          );
        }
        return const SilentUpdateResult(
          ok: false,
          message: 'Не удалось запустить установку APK',
        );
      } on PlatformException catch (e) {
        return SilentUpdateResult(
          ok: false,
          message: e.message ?? 'Ошибка установки APK',
        );
      }
    }

    if (Platform.isWindows) {
      return _installWindowsInno(localPath, target);
    }

    return const SilentUpdateResult(
      ok: false,
      message: 'Платформа не поддерживается',
    );
  }

  Future<SilentUpdateResult> _installWindowsInno(
    String installerPath,
    SilentUpdateTarget target,
  ) async {
    const silentArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS';
    final file = File(installerPath);
    if (!await file.exists()) {
      return SilentUpdateResult(
        ok: false,
        message: 'Файл не найден: $installerPath',
      );
    }

    if (target == SilentUpdateTarget.posWindows) {
      final exe = Platform.resolvedExecutable;
      final psPath = '${Directory.systemTemp.path}\\dk_pos_silent_update.ps1';
      final installer = escapePowerShellSingleQuoted(file.path);
      final exePath = escapePowerShellSingleQuoted(exe);
      await writeUtf8BomFile(
        File(psPath),
        r"$ErrorActionPreference = 'SilentlyContinue'" '\n'
        'Stop-Process -Name dk_pos -Force -ErrorAction SilentlyContinue\n'
        'Start-Sleep -Seconds 3\n'
        "Start-Process -FilePath '$installer' "
        "-ArgumentList '$silentArgs' -Wait\n"
        "Start-Process -FilePath '$exePath'\n",
      );
      await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          psPath,
        ],
        mode: ProcessStartMode.detached,
      );
      return const SilentUpdateResult(
        ok: true,
        message: 'Обновление POS запущено. Касса перезапустится через 1–3 минуты.',
        restartApp: true,
      );
    }

    try {
      await _launchWindowsInstallerDetached(file.path, silentArgs);
      return const SilentUpdateResult(
        ok: true,
        message:
            'Установщик backend запущен в тихом режиме. Служба перезапустится через 1–3 минуты.',
      );
    } catch (e) {
      return SilentUpdateResult(
        ok: false,
        message: 'Не удалось запустить установщик: $e',
        needsUserAction: true,
      );
    }
  }
}

Future<void> _launchWindowsInstallerDetached(
  String installerPath,
  String silentArgs,
) async {
  final installer = escapePowerShellSingleQuoted(installerPath);
  final psPath = '${Directory.systemTemp.path}\\dk_pos_launch_installer.ps1';
  await writeUtf8BomFile(
    File(psPath),
    "Start-Process -FilePath '$installer' "
    "-ArgumentList '$silentArgs'\n",
  );
  await Process.start(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psPath],
    mode: ProcessStartMode.detached,
  );
}

SilentUpdatePlatform createSilentUpdatePlatform() =>
    SilentUpdatePlatformImpl();

bool get silentUpdateOnThisDevice {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.android;
}
