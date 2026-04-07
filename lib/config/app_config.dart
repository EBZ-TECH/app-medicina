class AppConfig {
  /// Ref del proyecto Supabase (AppMedicina). La app usa la Edge Function `mediconnect`
  /// como base: `https://<ref>.supabase.co/functions/v1/mediconnect`
  /// (reenvía al backend Node; configura el secreto `API_UPSTREAM` en Supabase).
  static const String supabaseProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'howtdxsbatfgxcmhklfc',
  );

  /// Si no está vacío, sustituye la URL de Supabase (útil para Node local o URL Render directa).
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Sin barra final. Si la URL termina en `/`, sin esto las peticiones quedan
  /// como `...//api/...` y el servidor responde **404** en casi todo.
  static String get apiBaseUrl {
    final override = _apiBaseUrlOverride.trim().replaceAll(RegExp(r'/+$'), '');
    if (override.isNotEmpty) return override;
    final ref = supabaseProjectRef.trim();
    return 'https://$ref.supabase.co/functions/v1/mediconnect'
        .replaceAll(RegExp(r'/+$'), '');
  }
}

