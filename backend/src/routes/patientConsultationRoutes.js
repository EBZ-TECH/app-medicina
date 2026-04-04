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

function toIso(v) {
  if (v == null) return null;
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

async function refreshSpecialistAverageRating(pool, specialistUserId) {
  const [rows] = await pool.query(
    `SELECT AVG(rating) AS a FROM specialist_ratings WHERE specialist_user_id = ?`,
    [specialistUserId],
  );
  const avg = rows[0].a != null ? Number(rows[0].a) : null;
  await pool.query(`UPDATE profiles SET average_rating = ? WHERE user_id = ?`, [avg, specialistUserId]);
}

function computeCanRate(row) {
  if (row.my_rating != null && row.my_rating !== undefined) return false;
  if (!row.specialist_user_id) return false;
  const now = Date.now();
  if (row.paid_at) return true;
  if (row.scheduled_at) {
    const t = new Date(row.scheduled_at).getTime();
    return !Number.isNaN(t) && t <= now;
  }
  return false;
}

// GET /api/patient/consultations
router.get('/', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }
  const patientId = payload.sub;

  try {
    const [rows] = await pool.query(
      `SELECT c.id, c.specialty, c.description, c.status, c.assignment_mode,
              c.specialist_user_id, c.specialist_label, c.scheduled_at, c.paid_at, c.created_at,
              sr.rating AS my_rating, sr.comment AS my_comment
       FROM consultation_requests c
       LEFT JOIN specialist_ratings sr ON sr.consultation_request_id = c.id
       WHERE c.patient_user_id = ?
       ORDER BY c.created_at DESC`,
      [patientId],
    );

    const consultations = rows.map((r) => {
      const myRating = r.my_rating != null ? Number.parseInt(String(r.my_rating), 10) : null;
      const row = {
        ...r,
        my_rating: Number.isFinite(myRating) ? myRating : null,
      };
      const canRate = computeCanRate(row);
      return {
        id: r.id,
        specialty: r.specialty,
        description: r.description,
        status: r.status,
        assignment_mode: r.assignment_mode,
        specialist_user_id: r.specialist_user_id,
        specialist_label: r.specialist_label,
        scheduled_at: toIso(r.scheduled_at),
        paid_at: toIso(r.paid_at),
        created_at: toIso(r.created_at),
        my_rating: Number.isFinite(myRating) ? myRating : null,
        my_comment: r.my_comment ? String(r.my_comment) : null,
        can_rate: canRate,
      };
    });

    return res.json({ consultations });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/patient/consultations/:id/pay — pago simulado de tarifa (requiere especialista asignado)
router.post('/:id/pay', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }
  const patientId = payload.sub;
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ error: 'Missing id' });

  try {
    const [rows] = await pool.query(
      `SELECT id, specialist_user_id, paid_at FROM consultation_requests
       WHERE id = ? AND patient_user_id = ? LIMIT 1`,
      [id, patientId],
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Consulta no encontrada' });
    }
    if (!rows[0].specialist_user_id) {
      return res.status(400).json({
        error: 'Aún no hay especialista asignado; no se puede simular el pago.',
      });
    }
    if (rows[0].paid_at) {
      const [again] = await pool.query(
        `SELECT id, specialty, status, specialist_label, scheduled_at, paid_at
         FROM consultation_requests WHERE id = ? LIMIT 1`,
        [id],
      );
      const r = again[0];
      return res.json({
        ok: true,
        already_paid: true,
        consultation: {
          id: r.id,
          specialty: r.specialty,
          status: r.status,
          specialist_label: r.specialist_label,
          scheduled_at: toIso(r.scheduled_at),
          paid_at: toIso(r.paid_at),
        },
      });
    }

    await pool.query(
      `UPDATE consultation_requests SET paid_at = CURRENT_TIMESTAMP WHERE id = ? AND patient_user_id = ?`,
      [id, patientId],
    );

    const [updated] = await pool.query(
      `SELECT id, specialty, status, specialist_label, scheduled_at, paid_at
       FROM consultation_requests WHERE id = ? LIMIT 1`,
      [id],
    );
    const r = updated[0];
    return res.json({
      ok: true,
      consultation: {
        id: r.id,
        specialty: r.specialty,
        status: r.status,
        specialist_label: r.specialist_label,
        scheduled_at: toIso(r.scheduled_at),
        paid_at: toIso(r.paid_at),
      },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/patient/consultations/:id/rate — calificación 1–5 tras la consulta
router.post('/:id/rate', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }
  const patientId = payload.sub;
  const id = String(req.params.id || '').trim();
  const rawRating = req.body?.rating;
  const comment = req.body?.comment != null ? String(req.body.comment).trim().slice(0, 2000) : null;

  if (!id) return res.status(400).json({ error: 'Missing id' });
  const rating = Number.parseInt(String(rawRating), 10);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'La calificación debe ser un entero entre 1 y 5' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT c.id, c.patient_user_id, c.specialist_user_id, c.scheduled_at, c.paid_at
       FROM consultation_requests c
       WHERE c.id = ? AND c.patient_user_id = ? LIMIT 1`,
      [id, patientId],
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'Consulta no encontrada' });
    }
    const c = rows[0];
    if (!c.specialist_user_id) {
      return res.status(400).json({ error: 'No hay especialista asignado' });
    }
    const fakeRow = {
      specialist_user_id: c.specialist_user_id,
      paid_at: c.paid_at,
      scheduled_at: c.scheduled_at,
      my_rating: null,
    };
    if (!computeCanRate(fakeRow)) {
      return res.status(400).json({
        error:
          'Aún no puedes calificar: espera la fecha de la cita o realiza el pago simulado cuando aplique.',
      });
    }

    const [dup] = await pool.query(
      `SELECT id FROM specialist_ratings WHERE consultation_request_id = ? LIMIT 1`,
      [id],
    );
    if (dup.length) {
      return res.status(409).json({ error: 'Ya calificaste esta consulta' });
    }

    const rid = uuidv4();
    await pool.query(
      `INSERT INTO specialist_ratings (id, consultation_request_id, patient_user_id, specialist_user_id, rating, comment)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [rid, id, patientId, c.specialist_user_id, rating, comment || null],
    );

    await refreshSpecialistAverageRating(pool, c.specialist_user_id);

    return res.status(201).json({
      ok: true,
      rating: {
        id: rid,
        consultation_request_id: id,
        rating,
        comment: comment || null,
      },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { patientConsultationRouter: router };
