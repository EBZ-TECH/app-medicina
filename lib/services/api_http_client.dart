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
      ? 'Si ves "Failed host lookup": Render y Supabase suelen estar bien; el emulador no resuelve DNS. '
          'Prueba cold boot del AVD, otra red en el PC, o un teléfono físico.\n\n'
      : '';
  return 'Sin conexión con el API en $u$d.\n'
      '$dnsEmulator'
      '1) Navegador (PC): https://appmedicina-api.onrender.com/health y el /health del proxy Supabase → {"ok":true}.\n'
      '2) Render directo (si supabase.co falla en tu red): '
      '--dart-define=API_BASE_URL=https://appmedicina-api.onrender.com\n'
      '3) Tras cambiar URL: flutter run de nuevo (o flutter clean si hace falta).';
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
