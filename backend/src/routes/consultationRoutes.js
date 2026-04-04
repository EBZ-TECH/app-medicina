const express = require('express');
const { v4: uuidv4 } = require('uuid');

const { getPool } = require('../db/postgres');
const { verifyAccessToken } = require('../auth/jwt');

const router = express.Router();

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
  const { specialty, description, assignment_mode, specialist_id } = req.body || {};

  if (!specialty || String(specialty).trim() === '') {
    return res.status(400).json({ error: 'Missing specialty' });
  }
  if (!description || String(description).trim().length < 5) {
    return res.status(400).json({ error: 'Describe brevemente tu necesidad (mín. 5 caracteres)' });
  }
  const mode = assignment_mode === 'auto' ? 'auto' : 'manual';
  if (mode === 'manual' && (!specialist_id || String(specialist_id).trim() === '')) {
    return res.status(400).json({ error: 'Selecciona un especialista' });
  }

  const specNorm = String(specialty).trim();

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

  const id = uuidv4();
  const status =
    specialistUserId && specialistLabel ? 'assigned' : 'pending';

  try {
    await pool.query(
      `INSERT INTO consultation_requests (
        id, patient_user_id, specialty, description, assignment_mode,
        specialist_user_id, specialist_label, status
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        patientId,
        String(specialty).trim(),
        String(description).trim(),
        mode,
        specialistUserId,
        specialistLabel,
        status,
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
