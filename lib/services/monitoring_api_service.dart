import 'dart:convert';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_http_client.dart';
import 'api_response_helpers.dart';

class MonitoringEntryDto {
  final String id;
  final String category;
  final String title;
  final String? summary;
  final String? detail;
  final String? occurredAt;
  final String? createdAt;
  final String? specialistDisplayName;
  final String? specialistSpecialty;
  final String? referralTargetSpecialty;
  final String? referralTargetSpecialistUserId;
  final String? referralSpecialistDisplayName;
  /// Solo en respuestas del especialista (`/api/specialist/monitoring/entries`).
  final String? patientDisplayName;

  MonitoringEntryDto({
    required this.id,
    required this.category,
    required this.title,
    this.summary,
    this.detail,
    this.occurredAt,
    this.createdAt,
    this.specialistDisplayName,
    this.specialistSpecialty,
    this.referralTargetSpecialty,
    this.referralTargetSpecialistUserId,
    this.referralSpecialistDisplayName,
    this.patientDisplayName,
  });

  factory MonitoringEntryDto.fromJson(Map<String, dynamic> j) {
    return MonitoringEntryDto(
      id: j['id'] as String? ?? '',
      category: j['category'] as String? ?? '',
      title: j['title'] as String? ?? '',
      summary: j['summary'] as String?,
      detail: j['detail'] as String?,
      occurredAt: j['occurred_at'] as String?,
      createdAt: j['created_at'] as String?,
      specialistDisplayName: j['specialist_display_name'] as String?,
      specialistSpecialty: j['specialist_specialty'] as String?,
      referralTargetSpecialty: j['referral_target_specialty'] as String?,
      referralTargetSpecialistUserId: j['referral_target_specialist_user_id'] as String?,
      referralSpecialistDisplayName: j['referral_specialist_display_name'] as String?,
    );
  }
}

class MonitoringApiService {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: query);
  }

  Future<List<MonitoringEntryDto>> fetchEntries({
    required String accessToken,
    String? category,
  }) async {
    final q = <String, String>{};
    if (category != null && category.isNotEmpty) {
      q['category'] = category;
    }
    final uri = _uri('/api/patient/monitoring/entries', q.isEmpty ? null : q);
    final response = await apiGet(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['entries'] as List<dynamic>? ?? [];
    return list
        .map((e) => MonitoringEntryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Entradas de seguimiento creadas por el especialista (1.9).
  Future<List<MonitoringEntryDto>> fetchSpecialistEntries({
    required String accessToken,
    String? category,
  }) async {
    final q = <String, String>{};
    if (category != null && category.isNotEmpty) {
      q['category'] = category;
    }
    final uri = _uri('/api/specialist/monitoring/entries', q.isEmpty ? null : q);
    final response = await apiGet(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['entries'] as List<dynamic>? ?? [];
    return list
        .map((e) => MonitoringEntryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
