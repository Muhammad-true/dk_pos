class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  factory ApiException.fromHttp(
    int statusCode,
    dynamic body, {
    String fallbackMessage = 'Ошибка запроса',
  }) {
    if (body is Map && body['error'] != null) {
      return ApiException(statusCode, body['error'].toString());
    }
    return ApiException(statusCode, fallbackMessage);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
