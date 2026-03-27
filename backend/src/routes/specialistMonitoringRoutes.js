const express = require('express');

const { getPool } = require('../db/mysql');
const { verifyAccessToken } = require('../auth/jwt');

const router = express.Router();

const CATEGORIES = new Set([
  'therapy_result',
  'evolution',
  'authorization',
  'recommendation',
  'referral',
]);

function getBearerToken(req) {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  if (parts[0] !== 'Bearer') return null;
  return parts[1];
}

function formatPatientName(row) {
  if (!row || !row.patient_first_name) return null;
  return `${row.patient_first_name} ${row.patient_last_name || ''}`.trim();
}

function fmtDateOnly(d) {
  if (!d) return null;
  if (d instanceof Date) return d.toISOString().slice(0, 10);
  const s = String(d);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

// GET /api/specialist/monitoring/entries?category=referral
router.get('/entries', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }

  if (payload.role && payload.role !== 'Especialista') {
    return res.status(403).json({ error: 'Solo especialistas' });
  }

  const specialistId = payload.sub;
  const category = (req.query.category || '').trim();

  let sql = `
    SELECT
      e.id,
      e.category,
      e.title,
      e.summary,
      e.detail,
      e.occurred_at,
      e.patient_user_id,
      e.referral_target_specialty,
      e.referral_target_specialist_user_id,
      e.created_at,
      pp.first_name AS patient_first_name,
      pp.last_name AS patient_last_name,
      rp.first_name AS referral_specialist_first_name,
      rp.last_name AS referral_specialist_last_name
    FROM patient_care_entries e
    LEFT JOIN profiles pp ON pp.user_id = e.patient_user_id
    LEFT JOIN profiles rp ON rp.user_id = e.referral_target_specialist_user_id
    WHERE e.specialist_user_id = ?
  `;
  const params = [specialistId];

  if (category && CATEGORIES.has(category)) {
    sql += ' AND e.category = ?';
    params.push(category);
  }

  sql += ' ORDER BY e.created_at DESC';

  try {
    const [rows] = await pool.query(sql, params);
    const entries = rows.map((r) => ({
      id: r.id,
      category: r.category,
      title: r.title,
      summary: r.summary,
      detail: r.detail,
      occurred_at: fmtDateOnly(r.occurred_at),
      created_at: fmtDateOnly(r.created_at),
      patient_user_id: r.patient_user_id,
      patient_display_name: formatPatientName(r),
      referral_target_specialty: r.referral_target_specialty,
      referral_target_specialist_user_id: r.referral_target_specialist_user_id,
      referral_specialist_display_name: formatPatientName({
        patient_first_name: r.referral_specialist_first_name,
        patient_last_name: r.referral_specialist_last_name,
      }),
    }));

    return res.json({ entries });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = { specialistMonitoringRouter: router };
