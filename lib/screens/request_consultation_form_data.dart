import 'package:flutter/material.dart';

/// Estado mutable del paso 1 (común + campos por especialidad).
class RequestConsultationFormData {
  DateTime? scheduledAt;
  String? modality; // presencial | virtual | domicilio
  String? priority; // baja | media | alta | urgente
  final TextEditingController antecedentes = TextEditingController();

  // Fisioterapia
  final TextEditingController fiMotivo = TextEditingController();
  String? fiTipoLesion;
  final TextEditingController fiTipoLesionOtro = TextEditingController();
  String? fiZona;
  final TextEditingController fiZonaOtro = TextEditingController();
  int? fiNivelDolor;
  String? fiMovilidad;
  String? fiTratamientoPrevio;
  final TextEditingController fiTratamientoDetalle = TextEditingController();
  String? fiObjetivo;
  final TextEditingController fiDetalle = TextEditingController();

  // Terapia ocupacional
  final TextEditingController toMotivo = TextEditingController();
  String? toArea;
  final TextEditingController toAreaOtro = TextEditingController();
  String? toIndependencia;
  final Set<String> toActividades = {};
  final TextEditingController toActividadesOtro = TextEditingController();
  final TextEditingController toDetalle = TextEditingController();

  // Medicina general
  final TextEditingController mgMotivo = TextEditingController();
  final Set<String> mgSintomas = {};
  final TextEditingController mgSintomasOtro = TextEditingController();
  final TextEditingController mgDetalle = TextEditingController();

  // Psicología
  final TextEditingController psMotivo = TextEditingController();
  String? psMotivoPrincipal;
  final TextEditingController psMotivoPrincipalOtro = TextEditingController();
  String? psEstado;
  final TextEditingController psDetalle = TextEditingController();

  void dispose() {
    antecedentes.dispose();
    fiMotivo.dispose();
    fiTipoLesionOtro.dispose();
    fiZonaOtro.dispose();
    fiTratamientoDetalle.dispose();
    fiDetalle.dispose();
    toMotivo.dispose();
    toAreaOtro.dispose();
    toActividadesOtro.dispose();
    toDetalle.dispose();
    mgMotivo.dispose();
    mgSintomasOtro.dispose();
    mgDetalle.dispose();
    psMotivo.dispose();
    psMotivoPrincipalOtro.dispose();
    psDetalle.dispose();
  }

  /// Fecha, modalidad y prioridad (sección 1 del formulario).
  String? validateScheduling() {
    if (scheduledAt == null) return 'Indica fecha y hora preferida';
    if (modality == null) return 'Selecciona la modalidad';
    if (priority == null) return 'Selecciona la prioridad';
    return null;
  }

  /// Solo tipo de consulta (sección 2).
  String? validateSpecialtySelected(String? specialty) {
    if (specialty == null || specialty.isEmpty) return 'Selecciona el tipo de consulta';
    return null;
  }

  /// Campos específicos de la especialidad (sección 3).
  String? validateSpecialtyDetails(String specialty) {
    switch (specialty) {
      case 'Fisioterapia':
        if (fiMotivo.text.trim().length < 2) return 'Indica el motivo de consulta';
        if (fiTipoLesion == null) return 'Selecciona el tipo de lesión';
        if (fiTipoLesion == 'Otro' && fiTipoLesionOtro.text.trim().isEmpty) {
          return 'Especifica el tipo de lesión';
        }
        if (fiZona == null) return 'Selecciona la zona afectada';
        if (fiZona == 'Otro' && fiZonaOtro.text.trim().isEmpty) return 'Especifica la zona afectada';
        if (fiNivelDolor == null) return 'Selecciona el nivel de dolor';
        if (fiMovilidad == null) return 'Selecciona la movilidad';
        if (fiTratamientoPrevio == null) return 'Indica si hubo tratamiento previo';
        if (fiTratamientoPrevio == 'si' && fiTratamientoDetalle.text.trim().length < 2) {
          return 'Describe el tratamiento previo';
        }
        if (fiObjetivo == null) return 'Selecciona el objetivo de la terapia';
        if (fiDetalle.text.trim().length < 10) return 'La descripción detallada debe tener al menos 10 caracteres';
        break;
      case 'Terapia ocupacional':
        if (toMotivo.text.trim().length < 2) return 'Indica el motivo de consulta';
        if (toArea == null) return 'Selecciona el área afectada';
        if (toArea == 'Otro' && toAreaOtro.text.trim().isEmpty) return 'Especifica el área afectada';
        if (toIndependencia == null) return 'Selecciona el nivel de independencia';
        if (toActividades.isEmpty) return 'Selecciona al menos una actividad afectada';
        if (toActividades.contains('Otro') && toActividadesOtro.text.trim().isEmpty) {
          return 'Especifica la actividad (Otro)';
        }
        if (toDetalle.text.trim().length < 10) return 'La descripción detallada debe tener al menos 10 caracteres';
        break;
      case 'Medicina general':
        if (mgMotivo.text.trim().length < 2) return 'Indica el motivo de consulta';
        if (mgSintomas.isEmpty) return 'Selecciona al menos un síntoma';
        if (mgSintomas.contains('Otros') && mgSintomasOtro.text.trim().isEmpty) {
          return 'Especifica los otros síntomas';
        }
        if (mgDetalle.text.trim().length < 10) return 'La descripción detallada debe tener al menos 10 caracteres';
        break;
      case 'Psicología':
        if (psMotivo.text.trim().length < 2) return 'Indica el motivo de consulta';
        if (psMotivoPrincipal == null) return 'Selecciona el motivo principal';
        if (psMotivoPrincipal == 'Otro' && psMotivoPrincipalOtro.text.trim().isEmpty) {
          return 'Especifica el motivo principal';
        }
        if (psEstado == null) return 'Selecciona el estado emocional';
        if (psDetalle.text.trim().length < 10) return 'La descripción detallada debe tener al menos 10 caracteres';
        break;
      default:
        return 'Tipo de consulta no reconocido';
    }
    return null;
  }

  /// Validación completa antes de paso “especialista” (por si cambian datos entre secciones).
  String? validateStep1(String? specialty) {
    return validateScheduling() ??
        validateSpecialtySelected(specialty) ??
        (specialty != null ? validateSpecialtyDetails(specialty) : 'Selecciona el tipo de consulta');
  }

  Map<String, dynamic> buildDetailsJson(String specialty) {
    switch (specialty) {
      case 'Fisioterapia':
        return {
          'motivo_consulta': fiMotivo.text.trim(),
          'tipo_lesion': fiTipoLesion,
          if (fiTipoLesion == 'Otro') 'tipo_lesion_otro': fiTipoLesionOtro.text.trim(),
          'zona_afectada': fiZona,
          if (fiZona == 'Otro') 'zona_afectada_otro': fiZonaOtro.text.trim(),
          'nivel_dolor': fiNivelDolor,
          'movilidad': fiMovilidad,
          'tratamiento_previo': fiTratamientoPrevio,
          if (fiTratamientoPrevio == 'si') 'tratamiento_previo_detalle': fiTratamientoDetalle.text.trim(),
          'objetivo_terapia': fiObjetivo,
          'descripcion_detallada': fiDetalle.text.trim(),
        };
      case 'Terapia ocupacional':
        return {
          'motivo_consulta': toMotivo.text.trim(),
          'area_afectada': toArea,
          if (toArea == 'Otro') 'area_afectada_otro': toAreaOtro.text.trim(),
          'nivel_independencia': toIndependencia,
          'actividades_afectadas': toActividades.toList(),
          if (toActividades.contains('Otro')) 'actividades_afectadas_otro': toActividadesOtro.text.trim(),
          'descripcion_detallada': toDetalle.text.trim(),
        };
      case 'Medicina general':
        return {
          'motivo_consulta': mgMotivo.text.trim(),
          'sintomas_principales': mgSintomas.toList(),
          if (mgSintomas.contains('Otros')) 'sintomas_otros_texto': mgSintomasOtro.text.trim(),
          'descripcion_detallada': mgDetalle.text.trim(),
        };
      case 'Psicología':
        return {
          'motivo_consulta': psMotivo.text.trim(),
          'motivo_principal': psMotivoPrincipal,
          if (psMotivoPrincipal == 'Otro') 'motivo_principal_otro': psMotivoPrincipalOtro.text.trim(),
          'estado_emocional': psEstado,
          'descripcion_detallada': psDetalle.text.trim(),
        };
      default:
        return {};
    }
  }

  static List<String> get modalidades => const ['presencial', 'virtual', 'domicilio'];
  static List<String> get prioridades => const ['baja', 'media', 'alta', 'urgente'];

  static String labelModalidad(String code) {
    switch (code) {
      case 'presencial':
        return 'Presencial';
      case 'virtual':
        return 'Virtual';
      case 'domicilio':
        return 'Domicilio';
      default:
        return code;
    }
  }

  static String labelPrioridad(String code) {
    switch (code) {
      case 'baja':
        return 'Baja';
      case 'media':
        return 'Media';
      case 'alta':
        return 'Alta';
      case 'urgente':
        return 'Urgente';
      default:
        return code;
    }
  }
}
