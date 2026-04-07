import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'request_consultation_form_data.dart';

/// Campos dinámicos del paso 1 según especialidad.
class RequestConsultationStep1Fields extends StatelessWidget {
  final String? specialty;
  final RequestConsultationFormData fd;
  final VoidCallback onChanged;

  const RequestConsultationStep1Fields({
    super.key,
    required this.specialty,
    required this.fd,
    required this.onChanged,
  });

  static const _blue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    if (specialty == null) return const SizedBox.shrink();
    switch (specialty!) {
      case 'Fisioterapia':
        return _fisioterapia();
      case 'Terapia ocupacional':
        return _terapiaOcupacional();
      case 'Medicina general':
        return _medicinaGeneral();
      case 'Psicología':
        return _psicologia();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        t,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _fisioterapia() {
    const tipos = ['Muscular', 'Articular', 'Neurológica', 'Postquirúrgica', 'Otro', 'Ninguno'];
    const zonas = ['Cuello', 'Espalda', 'Hombro', 'Rodilla', 'Tobillo', 'Otro', 'Ninguno'];
    const mov = ['Normal', 'Reducida', 'Limitada'];
    const obj = ['Recuperación', 'Rehabilitación', 'Mantenimiento'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Fisioterapia — recuperación física'),
        TextField(
          controller: fd.fiMotivo,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Motivo de consulta (breve)'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Tipo de lesión'),
        DropdownButtonFormField<String>(
          value: fd.fiTipoLesion,
          decoration: _decoration('Selecciona'),
          items: tipos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.fiTipoLesion = v;
            onChanged();
          },
        ),
        if (fd.fiTipoLesion == 'Otro') ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.fiTipoLesionOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe el tipo de lesión'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Zona afectada'),
        DropdownButtonFormField<String>(
          value: fd.fiZona,
          decoration: _decoration('Selecciona'),
          items: zonas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.fiZona = v;
            onChanged();
          },
        ),
        if (fd.fiZona == 'Otro') ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.fiZonaOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe la zona'),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Nivel de dolor: ${fd.fiDolor.round()} / 10',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.navy),
        ),
        Slider(
          value: fd.fiDolor,
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: _blue,
          onChanged: (v) {
            fd.fiDolor = v;
            onChanged();
          },
        ),
        _sectionTitle('Movilidad'),
        DropdownButtonFormField<String>(
          value: fd.fiMovilidad,
          decoration: _decoration('Selecciona'),
          items: mov.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.fiMovilidad = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _sectionTitle('Tratamiento previo'),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Sí'),
                selected: fd.fiTratamientoPrevio == 'si',
                onSelected: (_) {
                  fd.fiTratamientoPrevio = 'si';
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('No'),
                selected: fd.fiTratamientoPrevio == 'no',
                onSelected: (_) {
                  fd.fiTratamientoPrevio = 'no';
                  onChanged();
                },
              ),
            ),
          ],
        ),
        if (fd.fiTratamientoPrevio == 'si') ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.fiTratamientoDetalle,
            maxLines: 2,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Detalle del tratamiento previo'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Objetivo de la terapia'),
        DropdownButtonFormField<String>(
          value: fd.fiObjetivo,
          decoration: _decoration('Selecciona'),
          items: obj.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.fiObjetivo = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _sectionTitle('Descripción detallada'),
        TextField(
          controller: fd.fiDetalle,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Describe tu situación con el mayor detalle posible'),
        ),
      ],
    );
  }

  Widget _terapiaOcupacional() {
    const areas = ['Motricidad fina', 'Motricidad gruesa', 'Cognitiva', 'Sensorial', 'Otro'];
    const indep = ['Independiente', 'Semi-dependiente', 'Dependiente'];
    const acts = ['Vestirse', 'Comer', 'Escribir', 'Trabajar', 'Otro', 'Ninguno'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Terapia ocupacional'),
        TextField(
          controller: fd.toMotivo,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Motivo de consulta (breve)'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Área afectada'),
        DropdownButtonFormField<String>(
          value: fd.toArea,
          decoration: _decoration('Selecciona'),
          items: areas.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.toArea = v;
            onChanged();
          },
        ),
        if (fd.toArea == 'Otro') ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.toAreaOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe el área'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Nivel de independencia'),
        DropdownButtonFormField<String>(
          value: fd.toIndependencia,
          decoration: _decoration('Selecciona'),
          items: indep.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.toIndependencia = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _sectionTitle('Actividades afectadas'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: acts.map((a) {
            final sel = fd.toActividades.contains(a);
            return FilterChip(
              label: Text(a),
              selected: sel,
              onSelected: (v) {
                if (v) {
                  fd.toActividades.add(a);
                } else {
                  fd.toActividades.remove(a);
                }
                onChanged();
              },
            );
          }).toList(),
        ),
        if (fd.toActividades.contains('Otro')) ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.toActividadesOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe la actividad (Otro)'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Descripción detallada'),
        TextField(
          controller: fd.toDetalle,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Describe tu situación con el mayor detalle posible'),
        ),
      ],
    );
  }

  Widget _medicinaGeneral() {
    const sint = ['Fiebre', 'Dolor', 'Tos', 'Fatiga', 'Otros'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Medicina general'),
        TextField(
          controller: fd.mgMotivo,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Motivo de consulta (breve)'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Síntomas principales'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sint.map((a) {
            final sel = fd.mgSintomas.contains(a);
            return FilterChip(
              label: Text(a),
              selected: sel,
              onSelected: (v) {
                if (v) {
                  fd.mgSintomas.add(a);
                } else {
                  fd.mgSintomas.remove(a);
                }
                onChanged();
              },
            );
          }).toList(),
        ),
        if (fd.mgSintomas.contains('Otros')) ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.mgSintomasOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe otros síntomas'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Descripción detallada'),
        TextField(
          controller: fd.mgDetalle,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Describe tu situación con el mayor detalle posible'),
        ),
      ],
    );
  }

  Widget _psicologia() {
    const motivos = [
      'Ansiedad',
      'Depresión',
      'Estrés',
      'Problemas familiares',
      'Problemas de pareja',
      'Otro',
    ];
    const estados = ['Estable', 'Ansioso', 'Deprimido', 'Irritable'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Psicología'),
        TextField(
          controller: fd.psMotivo,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Motivo de consulta (breve)'),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Motivo principal'),
        DropdownButtonFormField<String>(
          value: fd.psMotivoPrincipal,
          decoration: _decoration('Selecciona'),
          items: motivos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.psMotivoPrincipal = v;
            onChanged();
          },
        ),
        if (fd.psMotivoPrincipal == 'Otro') ...[
          const SizedBox(height: 8),
          TextField(
            controller: fd.psMotivoPrincipalOtro,
            onChanged: (_) => onChanged(),
            decoration: _decoration('Describe el motivo'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionTitle('Estado emocional'),
        DropdownButtonFormField<String>(
          value: fd.psEstado,
          decoration: _decoration('Selecciona'),
          items: estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            fd.psEstado = v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _sectionTitle('Descripción detallada'),
        TextField(
          controller: fd.psDetalle,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          decoration: _decoration('Describe tu situación con el mayor detalle posible'),
        ),
      ],
    );
  }
}
