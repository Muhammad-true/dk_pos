class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.rawBody});

  final int statusCode;
  final String message;
  final dynamic rawBody;

  factory ApiException.fromHttp(
    int statusCode,
    dynamic body, {
    String fallbackMessage = 'Ошибка запроса',
  }) {
    if (body is Map) {
      final map = body;
      final err = map['error'];
      if (err != null) {
        if (err is Map && err['message'] != null) {
          return ApiException(statusCode, err['message'].toString(), rawBody: body);
        }
        return ApiException(statusCode, err.toString(), rawBody: body);
      }
      final reason = map['reason']?.toString().trim();
      final detail = map['detail']?.toString().trim();
      final parts = <String>[];
      if (reason != null && reason.isNotEmpty) parts.add(reason);
      if (detail != null && detail.isNotEmpty) parts.add(detail);
      if (parts.isNotEmpty) {
        return ApiException(statusCode, parts.join(' — '), rawBody: body);
      }
      final msg = map['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) {
        return ApiException(statusCode, msg, rawBody: body);
      }
    }
    return ApiException(statusCode, fallbackMessage, rawBody: body);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
