import 'dart:convert';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_http_client.dart';
import 'api_response_helpers.dart';

class PrescriptionItemDto {
  final String id;
  final String drugName;
  final String? dosage;
  final String? posology;
  final int? quantity;
  final int sortOrder;

  PrescriptionItemDto({
    required this.id,
    required this.drugName,
    this.dosage,
    this.posology,
    this.quantity,
    required this.sortOrder,
  });

  factory PrescriptionItemDto.fromJson(Map<String, dynamic> j) {
    return PrescriptionItemDto(
      id: j['id'] as String? ?? '',
      drugName: j['drug_name'] as String? ?? '',
      dosage: j['dosage'] as String?,
      posology: j['posology'] as String?,
      quantity: j['quantity'] as int?,
      sortOrder: j['sort_order'] as int? ?? 0,
    );
  }
}

class PrescriptionSummaryDto {
  final String id;
  final String title;
  final String status;
  final int estimatedTotalCents;
  final String? deliveryAddressLine;
  final String? deliveryCity;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? paidAt;
  final String? shippedAt;
  final String? deliveredAt;
  final String? createdAt;
  final String? specialistDisplayName;
  final String? specialistSpecialty;
  /// Solo listado especialista.
  final String? patientFirstName;
  final String? patientLastName;

  PrescriptionSummaryDto({
    required this.id,
    required this.title,
    required this.status,
    required this.estimatedTotalCents,
    this.deliveryAddressLine,
    this.deliveryCity,
    this.deliveryLat,
    this.deliveryLng,
    this.paidAt,
    this.shippedAt,
    this.deliveredAt,
    this.createdAt,
    this.specialistDisplayName,
    this.specialistSpecialty,
    this.patientFirstName,
    this.patientLastName,
  });

  factory PrescriptionSummaryDto.fromJson(Map<String, dynamic> j) {
    return PrescriptionSummaryDto(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? '',
      estimatedTotalCents: j['estimated_total_cents'] as int? ?? 0,
      deliveryAddressLine: j['delivery_address_line'] as String?,
      deliveryCity: j['delivery_city'] as String?,
      deliveryLat: (j['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (j['delivery_lng'] as num?)?.toDouble(),
      paidAt: j['paid_at'] as String?,
      shippedAt: j['shipped_at'] as String?,
      deliveredAt: j['delivered_at'] as String?,
      createdAt: j['created_at'] as String?,
      specialistDisplayName: j['specialist_display_name'] as String?,
      specialistSpecialty: j['specialist_specialty'] as String?,
    );
  }
}

class PrescriptionDetailDto extends PrescriptionSummaryDto {
  final List<PrescriptionItemDto> items;

  PrescriptionDetailDto({
    required super.id,
    required super.title,
    required super.status,
    required super.estimatedTotalCents,
    super.deliveryAddressLine,
    super.deliveryCity,
    super.deliveryLat,
    super.deliveryLng,
    super.paidAt,
    super.shippedAt,
    super.deliveredAt,
    super.createdAt,
    super.specialistDisplayName,
    super.specialistSpecialty,
    super.patientFirstName,
    super.patientLastName,
    required this.items,
  });

  factory PrescriptionDetailDto.fromJson(Map<String, dynamic> j) {
    final raw = j['items'] as List<dynamic>? ?? [];
    return PrescriptionDetailDto(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? '',
      status: j['status'] as String? ?? '',
      estimatedTotalCents: j['estimated_total_cents'] as int? ?? 0,
      deliveryAddressLine: j['delivery_address_line'] as String?,
      deliveryCity: j['delivery_city'] as String?,
      deliveryLat: (j['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (j['delivery_lng'] as num?)?.toDouble(),
      paidAt: j['paid_at'] as String?,
      shippedAt: j['shipped_at'] as String?,
      deliveredAt: j['delivered_at'] as String?,
      createdAt: j['created_at'] as String?,
      specialistDisplayName: j['specialist_display_name'] as String?,
      specialistSpecialty: j['specialist_specialty'] as String?,
      patientFirstName: j['patient_first_name'] as String?,
      patientLastName: j['patient_last_name'] as String?,
      items: raw.map((e) => PrescriptionItemDto.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class PrescriptionsApiService {
  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<List<PrescriptionSummaryDto>> listSpecialist({required String accessToken}) async {
    final response = await apiGet(
      _uri('/api/specialist/prescriptions'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['prescriptions'] as List<dynamic>? ?? [];
    return list.map((e) => PrescriptionSummaryDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PrescriptionSummaryDto>> listPatient({required String accessToken}) async {
    final response = await apiGet(
      _uri('/api/patient/prescriptions'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = body['prescriptions'] as List<dynamic>? ?? [];
    return list.map((e) => PrescriptionSummaryDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PrescriptionDetailDto> getPatient({
    required String accessToken,
    required String id,
  }) async {
    final response = await apiGet(
      _uri('/api/patient/prescriptions/$id'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final p = body['prescription'] as Map<String, dynamic>?;
    if (p == null) throw ApiException('Respuesta inválida');
    return PrescriptionDetailDto.fromJson(p);
  }

  Future<PrescriptionSummaryDto> patchDelivery({
    required String accessToken,
    required String id,
    String? deliveryAddressLine,
    String? deliveryCity,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final payload = <String, dynamic>{};
    if (deliveryAddressLine != null) payload['delivery_address_line'] = deliveryAddressLine;
    if (deliveryCity != null) payload['delivery_city'] = deliveryCity;
    if (deliveryLat != null) payload['delivery_lat'] = deliveryLat;
    if (deliveryLng != null) payload['delivery_lng'] = deliveryLng;

    final response = await apiPatch(
      _uri('/api/patient/prescriptions/$id/delivery'),
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
    final p = body['prescription'] as Map<String, dynamic>?;
    if (p == null) throw ApiException('Respuesta inválida');
    return PrescriptionSummaryDto.fromJson(p);
  }

  Future<PrescriptionSummaryDto> payPatient({
    required String accessToken,
    required String id,
  }) async {
    final response = await apiPost(
      _uri('/api/patient/prescriptions/$id/pay'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final p = body['prescription'] as Map<String, dynamic>?;
    if (p == null) throw ApiException('Respuesta inválida');
    return PrescriptionSummaryDto.fromJson(p);
  }

  Future<PrescriptionSummaryDto> shipPatient({
    required String accessToken,
    required String id,
  }) async {
    final response = await apiPost(
      _uri('/api/patient/prescriptions/$id/ship'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final p = body['prescription'] as Map<String, dynamic>?;
    if (p == null) throw ApiException('Respuesta inválida');
    return PrescriptionSummaryDto.fromJson(p);
  }

  Future<PrescriptionSummaryDto> deliverPatient({
    required String accessToken,
    required String id,
  }) async {
    final response = await apiPost(
      _uri('/api/patient/prescriptions/$id/deliver'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final p = body['prescription'] as Map<String, dynamic>?;
    if (p == null) throw ApiException('Respuesta inválida');
    return PrescriptionSummaryDto.fromJson(p);
  }

  Future<Map<String, dynamic>> createSpecialist({
    required String accessToken,
    required String patientEmail,
    required String title,
    required List<Map<String, dynamic>> items,
    int? estimatedTotalCents,
  }) async {
    final payload = <String, dynamic>{
      'patient_email': patientEmail.trim(),
      'title': title.trim(),
      'items': items,
    };
    if (estimatedTotalCents != null) {
      payload['estimated_total_cents'] = estimatedTotalCents;
    }

    final response = await apiPost(
      _uri('/api/specialist/prescriptions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(parseApiErrorResponse(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
