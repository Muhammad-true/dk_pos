import 'package:dio/dio.dart';

import 'package:dk_pos/core/config/app_config.dart';

Dio createDio() {
  final base = AppConfig.apiOrigin;
  return Dio(
    BaseOptions(
      baseUrl: base.endsWith('/') ? base : '$base/',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
}

/// Запросы только к глобальному API лицензий (`GLOBAL_LICENSE_API_BASE_URL`).
Dio createGlobalLicenseDio() {
  final base = AppConfig.globalLicenseApiOrigin;
  if (base == null || base.isEmpty) {
    throw StateError('GLOBAL_LICENSE_API_BASE_URL не задан');
  }
  return Dio(
    BaseOptions(
      baseUrl: base.endsWith('/') ? base : '$base/',
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (_) => true,
    ),
  );
}
