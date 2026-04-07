import 'dart:convert';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_http_client.dart';
import 'api_response_helpers.dart';

String? specialistProfilePhotoUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  var p = relativePath.replaceAll(r'\', '/').replaceFirst(RegExp(r'^/+'), '');
  if (p.startsWith('uploads/')) {
    p = p.substring('uploads/'.length);
  }
  final base = AppConfig.apiBaseUrl;
  return '$base/uploads/$p';
}

class SpecialistDto {
  final String id;
  final String firstName;
  final String lastName;
  final String specialty;
  final double? rating;
  final bool hasRating;
  final String bio;
  final String? profilePhotoPath;
  final int? yearsExperience;
  final bool availableForAssignments;

  SpecialistDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialty,
    required this.rating,
    required this.hasRating,
    required this.bio,
    required this.profilePhotoPath,
    this.yearsExperience,
    this.availableForAssignments = true,
  });

  factory SpecialistDto.fromJson(Map<String, dynamic> j) {
    double? r;
    if (j['rating'] != null && j['rating'] is num) {
      r = (j['rating'] as num).toDouble();
    }
    final has = j['has_rating'] == true || r != null;
    int? years;
    if (j['years_experience'] != null) {
      years = (j['years_experience'] as num?)?.toInt();
    }
    final afa = j['available_for_assignments'];
    bool accepting = true;
    if (afa is bool) {
      accepting = afa;
    } else if (afa is num) {
      accepting = afa != 0;
    }
    return SpecialistDto(
      id: j['id'] as String? ?? '',
      firstName: j['first_name'] as String? ?? '',
      lastName: j['last_name'] as String? ?? '',
      specialty: j['specialty'] as String? ?? '',
      rating: r,
      hasRating: has,
      bio: j['bio'] as String? ?? '',
      profilePhotoPath: j['profile_photo_path'] as String?,
      yearsExperience: years,
      availableForAssignments: accepting,
    );
  }

  String? get photoUrl => specialistProfilePhotoUrl(profilePhotoPath);

  String get displayName {
    final prefix = firstName.startsWith('Dr') ? '' : 'Dr. ';
    return '$prefix$firstName $lastName';
  }
}

class ConsultationCreated {
  final String id;
  final String status;
  final String message;
  final String? specialistLabel;
  final int? estimatedResponseMinutes;

  ConsultationCreated({
    required this.id,
    required this.status,
    required this.message,
    this.specialistLabel,
    this.estimatedResponseMinutes,
  });
}

/// Resumen de consulta (paciente): recordatorios, calificación 1.7, etc.
class ConsultationSummaryDto {
  final String id;
  final String specialty;
  final String status;
  final String? scheduledAt;
  final String? specialistLabel;
  final String? paidAt;
  final int? myRating;
  final String? myComment;
  final bool canRate;

  ConsultationSummaryDto({
    required this.id,
    required this.specialty,
    required this.status,
    this.scheduledAt,
    this.specialistLabel,
    this.paidAt,
    this.myRating,
    this.myComment,
    this.canRate = false,
  });

  factory ConsultationSummaryDto.fromJson(Map<String, dynamic> j) {
    final mr = j['my_rating'];
    return ConsultationSummaryDto(
      id: j['id'] as String? ?? '',
      specialty: j['specialty'] as String? ?? '',
      status: j['status'] as String? ?? '',
      scheduledAt: j['scheduled_at'] as String?,
      specialistLabel: j['specialist_label'] as String?,
      paidAt: j['paid_at'] as String?,
      myRating: mr is num ? mr.toInt() : int.tryParse('$mr'),
      myComment: j['my_comment'] as String?,
      canRate: j['can_rate'] == true,
    );
  }
}

/// Consulta en vista del especialista (1.9).
class SpecialistConsultationDto {
  final String id;
  final String patientUserId;
  final String? patientFirstName;
  final String? patientLastName;
  final int? patientAge;
  final String specialty;
  final String description;
  final String status;
  final String? scheduledAt;
  final String? paidAt;
  final int? patientRating;

  SpecialistConsultationDto({
    required this.id,
    required this.patientUserId,
    this.patientFirstName,
    this.patientLastName,
    this.patientAge,
    required this.specialty,
    this.description = '',
    required this.status,
    this.scheduledAt,
    this.paidAt,
    this.patientRating,
  });

  factory SpecialistConsultationDto.fromJson(Map<String, dynamic> j) {
    final pr = j['patient_rating'];
    return SpecialistConsultationDto(
      id: j['id'] as String? ?? '',
      patientUserId: j['patient_user_id'] as String? ?? '',
      patientFirstName: j['patient_first_name'] as String?,
      patientLastName: j['patient_last_name'] as String?,
      patientAge: (j['patient_age'] as num?)?.toInt(),
      specialty: j['specialty'] as String? ?? '',
      description: j['description'] as String? ?? '',
      status: j['status'] as String? ?? '',
      scheduledAt: j['scheduled_at'] as String?,
      paidAt: j['paid_at'] as String?,
      patientRating: pr is num ? pr.toInt() : int.tryParse('$pr'),
    );
  }

  String get patientDisplayName {
    final a = patientFirstName ?? '';
    final b = patientLastName ?? '';
    final s = '$a $b'.trim();
    return s.isEmpty ? 'Paciente' : s;
  }
}

class ConsultationApiService {
  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<SpecialistDto>> fetchSpecialists({
    required String accessToken,
    required String specialty,
  }) async {
    final uri = _uri('/api/consultations/specialists').replace(
      queryParameters: {'specialty': specialty},
    );
    final response = await apiGet(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['specialists'] as List<dynamic>? ?? [];
    return list
        .map((e) => SpecialistDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ConsultationSummaryDto>> fetchPatientConsultations({
    required String accessToken,
  }) async {
    final response = await apiGet(
      _uri('/api/patient/consultations'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['consultations'] as List<dynamic>? ?? [];
    return list
        .map((e) => ConsultationSummaryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> rateConsultation({
    required String accessToken,
    required String consultationId,
    required int rating,
    String? comment,
  }) async {
    final response = await apiPost(
      _uri('/api/patient/consultations/$consultationId/rate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
  }

  Future<List<SpecialistConsultationDto>> fetchSpecialistConsultations({
    required String accessToken,
  }) async {
    final response = await apiGet(
      _uri('/api/specialist/consultations'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['consultations'] as List<dynamic>? ?? [];
    return list
        .map((e) => SpecialistConsultationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConsultationCreated> createRequest({
    required String accessToken,
    required String specialty,
    required String description,
    required bool automaticAssignment,
    String? specialistId,
  }) async {
    final body = <String, dynamic>{
      'specialty': specialty,
      'description': description,
      'assignment_mode': automaticAssignment ? 'auto' : 'manual',
    };
    if (!automaticAssignment && specialistId != null && specialistId.isNotEmpty) {
      body['specialist_id'] = specialistId;
    }

    final response = await apiPost(
      _uri('/api/consultations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final est = j['estimated_response_minutes'];
    return ConsultationCreated(
      id: j['id'] as String? ?? '',
      status: j['status'] as String? ?? '',
      message: j['message'] as String? ?? '',
      specialistLabel: j['specialist_label'] as String?,
      estimatedResponseMinutes: est is int ? est : int.tryParse('$est'),
    );
  }
}
