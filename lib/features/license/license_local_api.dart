import 'package:dio/dio.dart';

import 'package:dk_pos/features/license/license_global_api.dart';

/// Локальный API лицензии (`/api/local/license/*`): прокси к глобальному API и БД на backend.
class LicenseLocalApi {
  LicenseLocalApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getStatus() async {
    final res = await _dio.get<Object>(
      'api/local/license/status',
      options: Options(validateStatus: (_) => true),
    );
    final code = res.statusCode ?? 0;
    final data = res.data;
    if (code == 200 && data is Map<String, dynamic>) return data;
    if (code == 200 && data is Map) return Map<String, dynamic>.from(data);
    return _parseSuccess(res);
  }

  Future<Map<String, dynamic>> sync({
    required String licenseKey,
    required String deviceId,
  }) async {
    final res = await _dio.post<Object>(
      'api/local/license/sync',
      data: <String, dynamic>{
        'license_key': licenseKey,
        'device_id': deviceId,
      },
      options: Options(validateStatus: (_) => true),
    );
    return _parseSuccess(res);
  }

  Map<String, dynamic> _parseSuccess(Response<Object?> res) {
    final code = res.statusCode ?? 0;
    if (code == 200 && res.data is Map<String, dynamic>) {
      return res.data! as Map<String, dynamic>;
    }
    if (code == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data! as Map);
    }
    var message = 'Ошибка лицензии (HTTP $code)';
    String? errCode;
    final data = res.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) {
        final m = err['message'];
        if (m is String && m.isNotEmpty) message = m;
        final c = err['code'];
        if (c is String) errCode = c;
      }
    }
    throw LicenseApiException(message, statusCode: code, code: errCode);
  }
}
