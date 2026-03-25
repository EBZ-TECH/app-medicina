import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final String? userId;
  final String? email;

  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.email,
  });
}

class RegisterPayload {
  final String role;
  final String firstName;
  final String lastName;
  final String? age;
  final String? phone;
  final String email;
  final String password;
  final String? professionalTitle;
  final String? specialty;
  final PlatformFile? professionalCard;

  RegisterPayload({
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.age,
    this.phone,
    this.professionalTitle,
    this.specialty,
    this.professionalCard,
  });
}

class AuthApiService {
  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  static String _readError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final err = body['error'];
      if (err is String && err.isNotEmpty) return err;
    } catch (_) {}
    return 'Error ${response.statusCode}';
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    return LoginResult(
      accessToken: (body['access_token'] as String?) ?? '',
      refreshToken: (body['refresh_token'] as String?) ?? '',
      userId: user?['id'] as String?,
      email: user?['email'] as String?,
    );
  }

  Future<void> register(RegisterPayload payload) async {
    final request = http.MultipartRequest('POST', _uri('/api/auth/register'));
    request.fields['role'] = payload.role;
    request.fields['firstName'] = payload.firstName;
    request.fields['lastName'] = payload.lastName;
    request.fields['email'] = payload.email;
    request.fields['password'] = payload.password;

    if ((payload.age ?? '').trim().isNotEmpty) request.fields['age'] = payload.age!.trim();
    if ((payload.phone ?? '').trim().isNotEmpty) request.fields['phone'] = payload.phone!.trim();
    if ((payload.professionalTitle ?? '').trim().isNotEmpty) {
      request.fields['professionalTitle'] = payload.professionalTitle!.trim();
    }
    if ((payload.specialty ?? '').trim().isNotEmpty) {
      request.fields['specialty'] = payload.specialty!.trim();
    }

    final file = payload.professionalCard;
    if (file != null) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'professionalCard',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'professionalCard',
            file.bytes!,
            filename: file.name,
          ),
        );
      }
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response));
    }
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await http.get(
      _uri('/api/profile/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_readError(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    return profile ?? <String, dynamic>{};
  }
}

