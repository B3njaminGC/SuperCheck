/// Excepciones de dominio: la UI muestra [message] y nunca ve errores crudos de red.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sin conexión, timeout o fallo de DNS.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// La API respondió con un error (5xx u otro código inesperado).
class RemoteServiceException extends AppException {
  const RemoteServiceException(super.message, {this.statusCode, super.cause});

  final int? statusCode;
}

/// Demasiadas consultas (HTTP 429). Open Food Facts limita sobre todo la búsqueda.
class RateLimitException extends AppException {
  const RateLimitException(super.message, {super.cause});
}

/// La respuesta no tiene el formato esperado.
class DataParsingException extends AppException {
  const DataParsingException(super.message, {super.cause});
}

/// Texto apto para mostrar al usuario a partir de cualquier error.
String messageOf(Object error) {
  return error is AppException ? error.message : 'Ocurrió un error inesperado.';
}
