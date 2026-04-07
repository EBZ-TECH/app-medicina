class AppConfig {
  /// Ref del proyecto Supabase (por si enlazas el proxy `mediconnect` vía [apiBaseUrl]).
  static const String supabaseProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'howtdxsbatfgxcmhklfc',
  );

  /// Si no está vacío, sustituye la base del API (prioridad máxima).
  /// Ej.: backend local `http://10.0.2.2:3000` o proxy
  /// `https://<ref>.supabase.co/functions/v1/mediconnect`.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// URL HTTPS del Node en Render (`render.yaml` → `appmedicina-api`).
  /// Sustituible con `--dart-define=API_RENDER_URL=https://tu-servicio.onrender.com`.
  static const String _renderApiUrl = String.fromEnvironment(
    'API_RENDER_URL',
    defaultValue: 'https://appmedicina-api.onrender.com',
  );

  /// Sin barra final. Si la URL termina en `/`, sin esto las peticiones quedan
  /// como `...//api/...` y el servidor responde **404** en casi todo.
  ///
  /// Por defecto: **Render** (misma API que producción). Para Node local,
  /// usa `--dart-define=API_BASE_URL=http://10.0.2.2:3000`.
  static String get apiBaseUrl {
    final override = _apiBaseUrlOverride.trim().replaceAll(RegExp(r'/+$'), '');
    if (override.isNotEmpty) return override;
    return _renderApiUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
