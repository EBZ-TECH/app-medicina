import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// Render u otros hosts pueden tardar >45s en el primer request (cold start).
const Duration _kApiTimeout = Duration(seconds: 90);

String _connectionHint([String? detail]) {
  final u = AppConfig.apiBaseUrl;
  final parsed = Uri.parse(u);
  final port = parsed.hasPort ? parsed.port : (u.startsWith('https') ? 443 : 80);
  final d = detail != null && detail.isNotEmpty ? ' ($detail)' : '';
  return 'Sin conexión con el API en $u$d.\n'
      '1) Comprueba que el servicio en Render esté arriba y /health responda {"ok":true}.\n'
      '2) Por defecto la app usa https://appmedicina-api.onrender.com (override con --dart-define=API_BASE_URL=...).\n'
      '3) Backend local: cd backend → npm run dev y flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000';
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
