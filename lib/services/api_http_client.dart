import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// Render u otros hosts pueden tardar >45s en el primer request (cold start).
const Duration _kApiTimeout = Duration(seconds: 90);

String _connectionHint([String? detail]) {
  final u = AppConfig.apiBaseUrl;
  final d = detail != null && detail.isNotEmpty ? ' ($detail)' : '';
  final dnsEmulator = detail != null &&
          (detail.contains('Failed host lookup') ||
              detail.contains('nodename nor servname'))
      ? 'En emulador Android, "Failed host lookup" suele ser DNS/red: reinicia el '
          'emulador, comprueba internet en el PC, o usa backend local: '
          '`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000` con `npm run dev` en backend.\n\n'
      : '';
  return 'Sin conexión con el API en $u$d.\n'
      '$dnsEmulator'
      '1) Proxy Supabase → Render. Prueba en el navegador: $u/health\n'
      '2) Si ves "Failed host lookup" en el emulador, arregla DNS del AVD (ver README del equipo) '
      'o usa temporalmente: --dart-define=API_BASE_URL=http://10.0.2.2:3000 con npm run dev.\n'
      '3) Render directo: --dart-define=API_BASE_URL=https://appmedicina-api.onrender.com';
}

Future<http.Response> apiGet(Uri url, {Map<String, String>? headers}) async {
  try {
    return await http.get(url, headers: headers).timeout(_kApiTimeout);
  } on TimeoutException {
    throw ApiException(_connectionHint('Tiempo de espera'));
  } on http.ClientException catch (e) {
    throw ApiException(_connectionHint(e.message));
  }
}

Future<http.Response> apiPost(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
}) async {
  try {
    return await http.post(url, headers: headers, body: body).timeout(_kApiTimeout);
  } on TimeoutException {
    throw ApiException(_connectionHint('Tiempo de espera'));
  } on http.ClientException catch (e) {
    throw ApiException(_connectionHint(e.message));
  }
}

Future<http.Response> apiPatch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
}) async {
  try {
    return await http.patch(url, headers: headers, body: body).timeout(_kApiTimeout);
  } on TimeoutException {
    throw ApiException(_connectionHint('Tiempo de espera'));
  } on http.ClientException catch (e) {
    throw ApiException(_connectionHint(e.message));
  }
}

/// Multipart (registro, foto de perfil, etc.).
Future<http.Response> apiSendMultipart(http.MultipartRequest request) async {
  try {
    final streamed = await request.send().timeout(_kApiTimeout);
    return await http.Response.fromStream(streamed);
  } on TimeoutException {
    throw ApiException(_connectionHint('Tiempo de espera'));
  } on http.ClientException catch (e) {
    throw ApiException(_connectionHint(e.message));
  }
}
