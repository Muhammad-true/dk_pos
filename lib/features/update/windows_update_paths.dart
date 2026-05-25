import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Каталог для скачанных установщиков на Windows (без кириллицы в пути пользователя).
Future<Directory> resolveUpdateDownloadDirectory() async {
  if (Platform.isWindows) {
    final programData = Platform.environment['PROGRAMDATA']?.trim();
    if (programData != null && programData.isNotEmpty) {
      final dir = Directory('$programData\\DonerKebab\\updates');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }
  return getTemporaryDirectory();
}

/// Записывает текст в UTF-8 с BOM — PowerShell корректно читает кириллицу в путях.
Future<void> writeUtf8BomFile(File file, String content) async {
  final encoded = utf8.encode(content);
  await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...encoded]);
}

String escapePowerShellSingleQuoted(String value) =>
    value.replaceAll("'", "''");
