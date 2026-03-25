class AppConfig {
  // Para Android emulator en local: http://10.0.2.2:3000
  // Para produccion Railway: https://tu-backend.up.railway.app
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}

