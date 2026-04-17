import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:dk_pos/core/error/api_exception.dart';
import 'package:dk_pos/core/network/http_client.dart';

/// Реализация [HttpClient] на Dio — единственное место импорта Dio в приложении.
class DioHttpClient implements HttpClient {
  DioHttpClient(this._dio);

  final Dio _dio;

  String? _token;

  @override
  String? get authToken => _token;

  @override
  void setAuthToken(String? token) {
    _token = token;
  }

  Map<String, dynamic> _headers() {
    final t = _token;
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }

  @override
  Future<HttpResponse> get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(headers: _headers()),
      );
      return HttpResponse(statusCode: res.statusCode ?? 0, body: res.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<HttpResponse> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        path,
        data: body,
        options: Options(headers: _headers()),
      );
      return HttpResponse(statusCode: res.statusCode ?? 0, body: res.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<HttpResponse> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final res = await _dio.patch<dynamic>(
        path,
        data: body,
        options: Options(headers: _headers()),
      );
      return HttpResponse(statusCode: res.statusCode ?? 0, body: res.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<HttpResponse> delete(String path) async {
    try {
      final res = await _dio.delete<dynamic>(
        path,
        options: Options(headers: _headers()),
      );
      return HttpResponse(statusCode: res.statusCode ?? 0, body: res.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<HttpResponse> postMultipart(
    String path, {
    required List<HttpMultipartFile> files,
    Map<String, String>? fields,
    String fieldName = 'file',
  }) async {
    try {
      final form = FormData();
      if (fields != null) {
        for (final e in fields.entries) {
          form.fields.add(MapEntry(e.key, e.value));
        }
      }
      for (final f in files) {
        form.files.add(
          MapEntry(
            fieldName,
            MultipartFile.fromBytes(
              Uint8List.fromList(f.bytes),
              filename: f.filename,
            ),
          ),
        );
      }
      final res = await _dio.post<dynamic>(
        path,
        data: form,
        options: Options(headers: _headers()),
      );
      return HttpResponse(statusCode: res.statusCode ?? 0, body: res.data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    final res = e.response;
    final code = res?.statusCode ?? 0;
    var msg = e.message ?? 'Ошибка сети';
    final data = res?.data;
    if (data is Map && data['error'] != null) {
      msg = data['error'].toString();
    }
    return ApiException(code, msg);
  }
}
