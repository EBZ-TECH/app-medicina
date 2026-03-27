const express = require('express');

const { getPool } = require('../db/mysql');
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

// GET /api/specialist/consultations
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
  if (payload.role && payload.role !== 'Especialista') {
    return res.status(403).json({ error: 'Solo especialistas' });
  }
  const specialistId = payload.sub;

  try {
    const [rows] = await pool.query(
      `SELECT c.id, c.patient_user_id, c.specialty, c.description, c.status, c.assignment_mode,
              c.specialist_label, c.scheduled_at, c.paid_at, c.created_at,
              pp.first_name AS patient_first_name, pp.last_name AS patient_last_name, pp.age AS patient_age,
              sr.rating AS patient_rating
       FROM consultation_requests c
       LEFT JOIN profiles pp ON pp.user_id = c.patient_user_id
       LEFT JOIN specialist_ratings sr ON sr.consultation_request_id = c.id
       WHERE c.specialist_user_id = ?
       ORDER BY c.created_at DESC`,
      [specialistId],
    );

    const consultations = rows.map((r) => ({
      id: r.id,
      patient_user_id: r.patient_user_id,
      patient_first_name: r.patient_first_name ? String(r.patient_first_name) : null,
      patient_last_name: r.patient_last_name ? String(r.patient_last_name) : null,
      patient_age: r.patient_age != null ? Number(r.patient_age) : null,
      specialty: r.specialty,
      description: r.description,
      status: r.status,
      assignment_mode: r.assignment_mode,
      specialist_label: r.specialist_label,
      scheduled_at: toIso(r.scheduled_at),
      paid_at: toIso(r.paid_at),
      created_at: toIso(r.created_at),
      patient_rating:
        r.patient_rating != null ? Number.parseInt(String(r.patient_rating), 10) : null,
    }));

    return res.json({ consultations });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/specialist/consultations/:id  — programar cita (scheduled_at ISO)
router.patch('/:id', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (payload.role && payload.role !== 'Especialista') {
    return res.status(403).json({ error: 'Solo especialistas' });
  }
  const specialistId = payload.sub;
  const id = String(req.params.id || '').trim();
  const { scheduled_at: scheduledAtRaw } = req.body || {};
  if (!id) return res.status(400).json({ error: 'Missing id' });
  if (scheduledAtRaw == null || String(scheduledAtRaw).trim() === '') {
    return res.status(400).json({ error: 'Indica scheduled_at (ISO 8601)' });
  }

  let scheduledAt;
  try {
    scheduledAt = new Date(scheduledAtRaw);
    if (Number.isNaN(scheduledAt.getTime())) {
      return res.status(400).json({ error: 'scheduled_at no válido' });
    }
  } catch {
    return res.status(400).json({ error: 'scheduled_at no válido' });
  }

  try {
    const [result] = await pool.query(
      `UPDATE consultation_requests
       SET scheduled_at = ?
       WHERE id = ? AND specialist_user_id = ?`,
      [scheduledAt, id, specialistId],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Consulta no encontrada o no asignada a ti' });
    }
    const [rows] = await pool.query(
      `SELECT id, patient_user_id, specialty, status, scheduled_at, paid_at, specialist_label
       FROM consultation_requests WHERE id = ? LIMIT 1`,
      [id],
    );
    const r = rows[0];
    return res.json({
      consultation: {
        id: r.id,
        patient_user_id: r.patient_user_id,
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

module.exports = { specialistConsultationRouter: router };
