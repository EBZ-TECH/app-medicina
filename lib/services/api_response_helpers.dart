import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Convierte respuestas de error HTTP en texto útil para el usuario.
/// Express suele devolver 404 como texto plano (`Cannot GET /ruta`), no JSON;
/// sin esto solo se veía "Error 404".
String parseApiErrorResponse(http.Response response) {
  final code = response.statusCode;
  final raw = response.body.trim();
  if (raw.isEmpty) {
    return 'Error $code. Sin respuesta. Arranca el backend (carpeta backend → npm run dev) y prueba en el PC: '
        '${_localhostHealthHint()}';
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final err = decoded['error'] ?? decoded['message'];
      if (err is String && err.isNotEmpty) return err;
    }
  } catch (_) {}
  final snippet = raw.length > 280 ? '${raw.substring(0, 280)}…' : raw;
  if (snippet.toLowerCase().contains('<html') || snippet.contains('<!DOCTYPE')) {
    final base = AppConfig.apiBaseUrl;
    return 'Error $code: el servidor devolvió HTML en lugar del API MediConnect (JSON). '
        'Suele ser URL incorrecta o otro programa en el mismo puerto. '
        'Emulador Android: la app debe usar http://10.0.2.2:PUERTO (no localhost del PC). '
        'URL actual configurada: $base. Arranca el backend (cd backend → npm run dev) y en el PC abre ${_localhostHealthHint()}.';
  }
  return 'Error $code: $snippet';
}

String _localhostHealthHint() {
  final u = Uri.parse(AppConfig.apiBaseUrl);
  final port = u.hasPort ? u.port : 3000;
  return 'http://localhost:$port/health';
}
