/// Error raised by any Yandex API call. [statusCode] is 0 for network errors.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const ApiException(this.statusCode, this.message, {this.code});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNetwork => statusCode == 0;

  @override
  String toString() => statusCode == 0 ? message : '$message ($statusCode)';
}
