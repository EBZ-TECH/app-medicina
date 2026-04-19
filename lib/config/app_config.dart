class AppConfig {
  /// Ref del proyecto Supabase. Edge Function `mediconnect` → Render (`API_UPSTREAM`).
  static const String supabaseProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'howtdxsbatfgxcmhklfc',
  );

  /// Si no está vacío, sustituye la base del API (prioridad máxima).
  /// Ej. Render directo: `https://appmedicina-api.onrender.com`
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Por defecto: **proxy Supabase** → mismo Node en Render (`API_UPSTREAM` en Supabase).
  /// Render sin proxy: `--dart-define=API_BASE_URL=https://appmedicina-api.onrender.com`
  static String get apiBaseUrl {
    final override = _apiBaseUrlOverride.trim().replaceAll(RegExp(r'/+$'), '');
    if (override.isNotEmpty) return override;
    final ref = supabaseProjectRef.trim();
    return 'https://$ref.supabase.co/functions/v1/mediconnect'
        .replaceAll(RegExp(r'/+$'), '');
  }
}
