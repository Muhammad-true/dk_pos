import 'package:dio/dio.dart';

/// Ошибка ответа глобального API лицензий (4xx с телом JSON).
class LicenseApiException implements Exception {
  LicenseApiException(this.message, {this.statusCode = 0, this.code});

  final String message;
  final int statusCode;
  final String? code;

  @override
  String toString() => message;
}

class LicenseGlobalApi {
  LicenseGlobalApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> activate({
    required String licenseKey,
    required String deviceId,
  }) async {
    final res = await _dio.post<dynamic>(
      'api/v1/license/activate',
      data: <String, dynamic>{
        'license_key': licenseKey,
        'device_id': deviceId,
      },
    );
    return _parseSuccess(res);
  }

  Future<Map<String, dynamic>> verify({
    required String licenseKey,
    required String deviceId,
  }) async {
    final res = await _dio.post<dynamic>(
      'api/v1/license/verify',
      data: <String, dynamic>{
        'license_key': licenseKey,
        'device_id': deviceId,
      },
    );
    return _parseSuccess(res);
  }

  Map<String, dynamic> _parseSuccess(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    if (code == 200 && res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
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
