/// Error de API o de red devuelto a la UI (SnackBar, etc.).
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}
