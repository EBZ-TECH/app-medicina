const express = require('express');
const { v4: uuidv4 } = require('uuid');

const { getPool } = require('../db/postgres');
const { verifyAccessToken } = require('../auth/jwt');

const router = express.Router();

const ALLOWED_MODALITY = new Set(['presencial', 'virtual', 'domicilio']);
const ALLOWED_PRIORITY = new Set(['baja', 'media', 'alta', 'urgente']);

function specialtySlug(spec) {
  const s = String(spec || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
  if (s === 'fisioterapia') return 'fisioterapia';
  if (s === 'terapia ocupacional') return 'terapia_ocupacional';
  if (s === 'medicina general') return 'medicina_general';
  if (s === 'psicologia') return 'psicologia';
  return null;
}

function validateConsultationDetails(specialty, details) {
  const slug = specialtySlug(specialty);
  if (!slug) return { ok: false, error: 'Tipo de consulta no reconocido' };
  const d = details && typeof details === 'object' ? details : {};
  const req = (k) => {
    const v = d[k];
    return v !== undefined && v !== null && String(v).trim() !== '';
  };

  const longOk = req('descripcion_detallada') && String(d.descripcion_detallada).trim().length >= 10;
  if (!longOk) {
    return { ok: false, error: 'La descripción detallada debe tener al menos 10 caracteres' };
  }
  if (!req('motivo_consulta') || String(d.motivo_consulta).trim().length < 2) {
    return { ok: false, error: 'Indica el motivo de consulta' };
  }

  if (slug === 'fisioterapia') {
    if (!req('tipo_lesion')) return { ok: false, error: 'Selecciona el tipo de lesión' };
    if (d.tipo_lesion === 'Otro' && !req('tipo_lesion_otro')) {
      return { ok: false, error: 'Especifica el tipo de lesión (Otro)' };
    }
    if (!req('zona_afectada')) return { ok: false, error: 'Selecciona la zona afectada' };
    if (d.zona_afectada === 'Otro' && !req('zona_afectada_otro')) {
      return { ok: false, error: 'Especifica la zona afectada (Otro)' };
    }
    const n = Number.parseInt(String(d.nivel_dolor), 10);
    if (!Number.isFinite(n) || n < 1 || n > 10) {
      return { ok: false, error: 'Indica el nivel de dolor (1–10)' };
    }
    if (!req('movilidad')) return { ok: false, error: 'Selecciona la movilidad' };
    if (!req('tratamiento_previo')) return { ok: false, error: 'Indica si hubo tratamiento previo' };
    if (String(d.tratamiento_previo).toLowerCase() === 'si' && !req('tratamiento_previo_detalle')) {
      return { ok: false, error: 'Describe el tratamiento previo' };
    }
    if (!req('objetivo_terapia')) return { ok: false, error: 'Selecciona el objetivo de la terapia' };
  }

  if (slug === 'terapia_ocupacional') {
    if (!req('area_afectada')) return { ok: false, error: 'Selecciona el área afectada' };
    if (d.area_afectada === 'Otro' && !req('area_afectada_otro')) {
      return { ok: false, error: 'Especifica el área afectada (Otro)' };
    }
    if (!req('nivel_independencia')) return { ok: false, error: 'Selecciona el nivel de independencia' };
    const acts = d.actividades_afectadas;
    if (!Array.isArray(acts) || acts.length === 0) {
      return { ok: false, error: 'Selecciona al menos una actividad afectada' };
    }
    if (acts.includes('Otro') && !req('actividades_afectadas_otro')) {
      return { ok: false, error: 'Especifica la actividad afectada (Otro)' };
    }
  }

  if (slug === 'medicina_general') {
    const sint = d.sintomas_principales;
    if (!Array.isArray(sint) || sint.length === 0) {
      return { ok: false, error: 'Selecciona al menos un síntoma principal' };
    }
    if (sint.includes('Otros') && !req('sintomas_otros_texto')) {
      return { ok: false, error: 'Especifica los otros síntomas' };
    }
  }

  if (slug === 'psicologia') {
    if (!req('motivo_principal')) return { ok: false, error: 'Selecciona el motivo principal' };
    if (d.motivo_principal === 'Otro' && !req('motivo_principal_otro')) {
      return { ok: false, error: 'Especifica el motivo principal (Otro)' };
    }
    if (!req('estado_emocional')) return { ok: false, error: 'Selecciona el estado emocional' };
  }

  return { ok: true, slug, details: d };
}

function formatDetailsReadable(specialty, details) {
  const slug = specialtySlug(specialty);
  const d = details && typeof details === 'object' ? details : {};
  const lines = [];
  if (slug === 'fisioterapia') {
    lines.push(`Motivo de consulta: ${d.motivo_consulta || '—'}`);
    lines.push(`Tipo de lesión: ${d.tipo_lesion || '—'}${d.tipo_lesion === 'Otro' ? ` (${d.tipo_lesion_otro || ''})` : ''}`);
    lines.push(`Zona afectada: ${d.zona_afectada || '—'}${d.zona_afectada === 'Otro' ? ` (${d.zona_afectada_otro || ''})` : ''}`);
    lines.push(`Nivel de dolor: ${d.nivel_dolor ?? '—'} / 10`);
    lines.push(`Movilidad: ${d.movilidad || '—'}`);
    lines.push(
      `Tratamiento previo: ${d.tratamiento_previo || '—'}${String(d.tratamiento_previo).toLowerCase() === 'si' ? ` — ${d.tratamiento_previo_detalle || ''}` : ''}`,
    );
    lines.push(`Objetivo de la terapia: ${d.objetivo_terapia || '—'}`);
    lines.push('');
    lines.push('Descripción detallada:');
    lines.push(String(d.descripcion_detallada || '').trim());
  } else if (slug === 'terapia_ocupacional') {
    lines.push(`Motivo de consulta: ${d.motivo_consulta || '—'}`);
    lines.push(`Área afectada: ${d.area_afectada || '—'}${d.area_afectada === 'Otro' ? ` (${d.area_afectada_otro || ''})` : ''}`);
    lines.push(`Nivel de independencia: ${d.nivel_independencia || '—'}`);
    lines.push(`Actividades afectadas: ${Array.isArray(d.actividades_afectadas) ? d.actividades_afectadas.join(', ') : '—'}`);
    if (Array.isArray(d.actividades_afectadas) && d.actividades_afectadas.includes('Otro')) {
      lines.push(`Detalle actividades (Otro): ${d.actividades_afectadas_otro || '—'}`);
    }
    lines.push('');
    lines.push('Descripción detallada:');
    lines.push(String(d.descripcion_detallada || '').trim());
  } else if (slug === 'medicina_general') {
    lines.push(`Motivo de consulta: ${d.motivo_consulta || '—'}`);
    lines.push(`Síntomas principales: ${Array.isArray(d.sintomas_principales) ? d.sintomas_principales.join(', ') : '—'}`);
    if (Array.isArray(d.sintomas_principales) && d.sintomas_principales.includes('Otros')) {
      lines.push(`Detalle otros síntomas: ${d.sintomas_otros_texto || '—'}`);
    }
    lines.push('');
    lines.push('Descripción detallada:');
    lines.push(String(d.descripcion_detallada || '').trim());
  } else if (slug === 'psicologia') {
    lines.push(`Motivo de consulta: ${d.motivo_consulta || '—'}`);
    lines.push(`Motivo principal: ${d.motivo_principal || '—'}${d.motivo_principal === 'Otro' ? ` (${d.motivo_principal_otro || ''})` : ''}`);
    lines.push(`Estado emocional: ${d.estado_emocional || '—'}`);
    lines.push('');
    lines.push('Descripción detallada:');
    lines.push(String(d.descripcion_detallada || '').trim());
  } else {
    lines.push(JSON.stringify(d, null, 2));
  }
  return lines.join('\n');
}

function buildConsultationDescription({
  specialty,
  patientRow,
  scheduledAtIso,
  modality,
  priority,
  antecedentes,
  detailsFormatted,
}) {
  const lines = [];
  lines.push('=== Datos del paciente (autocompletados) ===');
  const fn = patientRow?.first_name ? String(patientRow.first_name).trim() : '';
  const ln = patientRow?.last_name ? String(patientRow.last_name).trim() : '';
  lines.push(`Nombre: ${`${fn} ${ln}`.trim() || '—'}`);
  if (patientRow?.phone) lines.push(`Teléfono: ${String(patientRow.phone).trim()}`);
  if (patientRow?.age != null && patientRow.age !== '') lines.push(`Edad: ${patientRow.age}`);
  lines.push('');
  lines.push('=== Solicitud ===');
  lines.push(`Tipo de consulta: ${specialty}`);
  lines.push(
    `Fecha y hora preferida: ${scheduledAtIso ? new Date(scheduledAtIso).toLocaleString('es-CO', { dateStyle: 'medium', timeStyle: 'short' }) : '—'}`,
  );
  lines.push(`Modalidad: ${modality}`);
  lines.push(`Prioridad: ${priority}`);
  if (antecedentes && String(antecedentes).trim()) {
    lines.push('Antecedentes relevantes:');
    lines.push(String(antecedentes).trim());
  }
  lines.push('');
  lines.push(detailsFormatted);
  return lines.join('\n');
}

function getBearerToken(req) {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  if (parts[0] !== 'Bearer') return null;
  return parts[1];
}

function requirePatient(payload) {
  if (payload.role && payload.role !== 'Paciente') {
    return { ok: false, status: 403, error: 'Solo pacientes pueden solicitar consultas' };
  }
  return { ok: true };
}

// GET /api/consultations/specialists?specialty=Fisioterapia
router.get('/specialists', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  const check = requirePatient(payload);
  if (!check.ok) return res.status(check.status).json({ error: check.error });

  const specialty = (req.query.specialty || '').trim();
  if (!specialty) return res.status(400).json({ error: 'Missing specialty' });

  try {
    const [rows] = await pool.query(
      `SELECT u.id AS specialist_user_id, p.first_name, p.last_name, p.professional_specialty AS specialty,
              p.bio_short, p.profile_photo_path, p.average_rating, p.years_experience,
              COALESCE(p.available_for_assignments, TRUE) AS available_for_assignments
       FROM profiles p
       INNER JOIN users u ON u.id = p.user_id
       WHERE p.role = 'Especialista'
         AND p.professional_specialty IS NOT NULL
         AND TRIM(p.professional_specialty) <> ''
         AND LOWER(TRIM(p.professional_specialty)) = LOWER(TRIM(?))
       ORDER BY p.last_name ASC, p.first_name ASC`,
      [specialty],
    );

    const defaultBio = 'Profesional verificado en MediConnect.';
    const specialists = rows.map((r) => {
      const bio = r.bio_short && String(r.bio_short).trim() ? String(r.bio_short).trim() : defaultBio;
      const ar = r.average_rating != null ? Number.parseFloat(String(r.average_rating)) : NaN;
      const rating = Number.isFinite(ar) ? Math.min(5, Math.max(0, ar)) : null;
      const years =
        r.years_experience != null && r.years_experience !== ''
          ? Number.parseInt(String(r.years_experience), 10)
          : null;
      const accepting =
        r.available_for_assignments === undefined || r.available_for_assignments === null
          ? true
          : Number(r.available_for_assignments) === 1;
      return {
        id: r.specialist_user_id,
        first_name: r.first_name,
        last_name: r.last_name,
        specialty: r.specialty,
        rating,
        has_rating: rating != null,
        bio,
        profile_photo_path: r.profile_photo_path ? String(r.profile_photo_path).trim() : null,
        years_experience: Number.isFinite(years) ? years : null,
        available_for_assignments: accepting,
        source: 'db',
      };
    });

    return res.json({ specialists });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/consultations  (solicitud / asignación)
router.post('/', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  const check = requirePatient(payload);
  if (!check.ok) return res.status(check.status).json({ error: check.error });

  const patientId = payload.sub;
  const body = req.body || {};
  const {
    specialty,
    assignment_mode,
    specialist_id,
    scheduled_at,
    modality,
    priority,
    antecedentes,
    details,
  } = body;

  if (!specialty || String(specialty).trim() === '') {
    return res.status(400).json({ error: 'Missing specialty' });
  }

  if (!scheduled_at || String(scheduled_at).trim() === '') {
    return res.status(400).json({ error: 'Indica fecha y hora preferida' });
  }
  const schedDate = new Date(String(scheduled_at));
  if (Number.isNaN(schedDate.getTime())) {
    return res.status(400).json({ error: 'Fecha y hora no válidas' });
  }

  const mod = String(modality || '')
    .trim()
    .toLowerCase();
  if (!ALLOWED_MODALITY.has(mod)) {
    return res.status(400).json({ error: 'Selecciona modalidad (presencial, virtual o domicilio)' });
  }

  const pri = String(priority || '')
    .trim()
    .toLowerCase();
  if (!ALLOWED_PRIORITY.has(pri)) {
    return res.status(400).json({ error: 'Selecciona prioridad (baja, media, alta o urgente)' });
  }

  let detailsObj = details;
  if (typeof detailsObj === 'string') {
    try {
      detailsObj = JSON.parse(detailsObj);
    } catch {
      return res.status(400).json({ error: 'Formato de detalle inválido' });
    }
  }

  const specNorm = String(specialty).trim();
  const v = validateConsultationDetails(specNorm, detailsObj);
  if (!v.ok) return res.status(400).json({ error: v.error });

  const mode = assignment_mode === 'auto' ? 'auto' : 'manual';
  if (mode === 'manual' && (!specialist_id || String(specialist_id).trim() === '')) {
    return res.status(400).json({ error: 'Selecciona un especialista' });
  }

  let specialistUserId = null;
  let specialistLabel = null;

  if (mode === 'auto') {
    const [cands] = await pool.query(
      `SELECT u.id AS specialist_user_id, p.first_name, p.last_name, p.professional_specialty
       FROM profiles p
       INNER JOIN users u ON u.id = p.user_id
       WHERE p.role = 'Especialista'
         AND p.professional_specialty IS NOT NULL
         AND TRIM(p.professional_specialty) <> ''
         AND LOWER(TRIM(p.professional_specialty)) = LOWER(TRIM(?))`,
      [specNorm],
    );
    if (!cands.length) {
      return res.status(400).json({
        error:
          'No hay especialistas disponibles para esta especialidad. Prueba otra especialidad o más tarde.',
      });
    }
    const pick = cands[Math.floor(Math.random() * cands.length)];
    specialistUserId = pick.specialist_user_id;
    specialistLabel = `Dr(a). ${pick.first_name} ${pick.last_name} — ${pick.professional_specialty}`;
  } else if (mode === 'manual' && specialist_id) {
    specialistUserId = String(specialist_id).trim();
    const [prow] = await pool.query(
      `SELECT p.first_name, p.last_name, p.professional_specialty
       FROM profiles p
       WHERE p.user_id = ?
         AND p.role = 'Especialista'
         AND p.professional_specialty IS NOT NULL
         AND LOWER(TRIM(p.professional_specialty)) = LOWER(TRIM(?))
       LIMIT 1`,
      [specialistUserId, specNorm],
    );
    if (!prow.length) {
      return res.status(400).json({
        error:
          'El especialista no existe o no coincide con el tipo de consulta seleccionado.',
      });
    }
    specialistLabel = `Dr(a). ${prow[0].first_name} ${prow[0].last_name} — ${prow[0].professional_specialty}`;
  }

  const [pRows] = await pool.query(
    `SELECT first_name, last_name, age, phone FROM profiles WHERE user_id = ? LIMIT 1`,
    [patientId],
  );
  const patientRow = pRows.length ? pRows[0] : null;

  const antText = antecedentes != null ? String(antecedentes).trim() : '';
  const detailsFormatted = formatDetailsReadable(specNorm, v.details);
  const descriptionText = buildConsultationDescription({
    specialty: specNorm,
    patientRow,
    scheduledAtIso: schedDate.toISOString(),
    modality: mod,
    priority: pri,
    antecedentes: antText,
    detailsFormatted,
  });

  const id = uuidv4();
  const status = specialistUserId && specialistLabel ? 'assigned' : 'pending';

  try {
    await pool.query(
      `INSERT INTO consultation_requests (
        id, patient_user_id, specialty, description, assignment_mode,
        specialist_user_id, specialist_label, status,
        scheduled_at, modality, priority, antecedentes, details_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)`,
      [
        id,
        patientId,
        specNorm,
        descriptionText,
        mode,
        specialistUserId,
        specialistLabel,
        status,
        schedDate.toISOString(),
        mod,
        pri,
        antText || null,
        JSON.stringify(v.details),
      ],
    );

    const baseMsg =
      mode === 'auto'
        ? `Solicitud registrada. Te hemos asignado a ${specialistLabel}. Tiempo estimado de primera respuesta: menos de 1 minuto.`
        : 'Solicitud registrada correctamente.';

    return res.status(201).json({
      id,
      status,
      assignment_mode: mode,
      specialist_label: specialistLabel,
      estimated_response_minutes: 1,
      message: baseMsg,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { consultationRouter: router };
