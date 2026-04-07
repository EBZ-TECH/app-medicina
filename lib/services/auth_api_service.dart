import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_http_client.dart';
import 'api_response_helpers.dart';

export 'api_exception.dart';

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final String? userId;
  final String? email;
  final String? role;

  LoginResult({
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.email,
    this.role,
  });
}

class RegisterPayload {
  final String role;
  final String firstName;
  final String lastName;
  final String age;
  final String phone;
  final String email;
  final String password;
  final String? professionalTitle;
  final String? specialty;
  final PlatformFile? professionalCard;

  RegisterPayload({
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.phone,
    required this.email,
    required this.password,
    this.professionalTitle,
    this.specialty,
    this.professionalCard,
  });
}

class AuthApiService {
  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await apiPost(
      _uri('/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    return LoginResult(
      accessToken: (body['access_token'] as String?) ?? '',
      refreshToken: (body['refresh_token'] as String?) ?? '',
      userId: user?['id'] as String?,
      email: user?['email'] as String?,
      role: body['role'] as String?,
    );
  }

  Future<LoginResult> register(RegisterPayload payload) async {
    final request = http.MultipartRequest('POST', _uri('/api/auth/register'));
    request.fields['role'] = payload.role;
    request.fields['firstName'] = payload.firstName;
    request.fields['lastName'] = payload.lastName;
    request.fields['email'] = payload.email;
    request.fields['password'] = payload.password;
    request.fields['age'] = payload.age.trim();
    request.fields['phone'] = payload.phone.trim();
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

    final response = await apiSendMultipart(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    return LoginResult(
      accessToken: (body['access_token'] as String?) ?? '',
      refreshToken: (body['refresh_token'] as String?) ?? '',
      userId: user?['id'] as String?,
      email: user?['email'] as String?,
      role: body['role'] as String?,
    );
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await apiGet(
      _uri('/api/profile/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    final out = Map<String, dynamic>.from(profile ?? {});
    if (body['rating_count'] != null) {
      out['rating_count'] = body['rating_count'];
    }
    return out;
  }

  /// Especialista: bio corta y años de experiencia (JSON).
  Future<Map<String, dynamic>> patchSpecialistProfile({
    required String accessToken,
    String? bioShort,
    int? yearsExperience,
    bool clearYearsExperience = false,
    bool? availableForAssignments,
  }) async {
    final payload = <String, dynamic>{};
    if (bioShort != null) payload['bio_short'] = bioShort;
    if (clearYearsExperience) {
      payload['years_experience'] = null;
    } else if (yearsExperience != null) {
      payload['years_experience'] = yearsExperience;
    }
    if (availableForAssignments != null) {
      payload['available_for_assignments'] = availableForAssignments;
    }

    final response = await apiPost(
      _uri('/api/profile/specialist-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    final out = Map<String, dynamic>.from(profile ?? {});
    if (body['rating_count'] != null) {
      out['rating_count'] = body['rating_count'];
    }
    return out;
  }

  /// Especialista: foto y bio (multipart; mismo endpoint que registro avanzado).
  Future<Map<String, dynamic>> patchSpecialistPublic({
    required String accessToken,
    String? bioShort,
    PlatformFile? profilePhoto,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/profile/specialist-public'));
    request.headers['Authorization'] = 'Bearer $accessToken';
    if (bioShort != null) request.fields['bio_short'] = bioShort;
    final file = profilePhoto;
    if (file != null) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePhoto',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePhoto',
            file.bytes!,
            filename: file.name,
          ),
        );
      }
    }

    final response = await apiSendMultipart(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    return profile ?? <String, dynamic>{};
  }

  /// Solo pacientes (`pay_per_consult` | `monthly_subscription`).
  Future<Map<String, dynamic>> patchPaymentPlan({
    required String accessToken,
    required String paymentPlan,
  }) async {
    final response = await apiPatch(
      _uri('/api/profile/payment-plan'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'payment_plan': paymentPlan}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    return profile ?? <String, dynamic>{};
  }

  /// Paciente: celular y foto de perfil (multipart).
  Future<Map<String, dynamic>> patchPatientPublic({
    required String accessToken,
    String? phone,
    PlatformFile? profilePhoto,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/profile/patient-public'));
    request.headers['Authorization'] = 'Bearer $accessToken';
    if (phone != null) request.fields['phone'] = phone.trim();

    final file = profilePhoto;
    if (file != null) {
      if (file.path != null && file.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePhoto',
            file.path!,
            filename: file.name,
          ),
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePhoto',
            file.bytes!,
            filename: file.name,
          ),
        );
      }
    }

    final response = await apiSendMultipart(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final profile = body['profile'] as Map<String, dynamic>?;
    return profile ?? <String, dynamic>{};
  }
}

