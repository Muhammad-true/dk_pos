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
