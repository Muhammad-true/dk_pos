/// Файл для multipart (например POST /api/upload, поле [fieldName]).
class HttpMultipartFile {
  const HttpMultipartFile({
    required this.bytes,
    required this.filename,
  });

  final List<int> bytes;
  final String filename;
}

/// Абстракция HTTP-клиента (реализация с Dio — только в data-слое).
abstract class HttpClient {
  String? get authToken;

  void setAuthToken(String? token);

  Future<HttpResponse> get(
    String path, {
    Map<String, String>? query,
  });

  Future<HttpResponse> post(
    String path, {
    Map<String, dynamic>? body,
  });

  Future<HttpResponse> patch(
    String path, {
    Map<String, dynamic>? body,
  });

  Future<HttpResponse> delete(String path);

  /// multipart/form-data (поле файла по умолчанию `file`, как у multer).
  Future<HttpResponse> postMultipart(
    String path, {
    required List<HttpMultipartFile> files,
    Map<String, String>? fields,
    String fieldName = 'file',
  });
}

class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    this.body,
  });

  final int statusCode;
  final dynamic body;
}
