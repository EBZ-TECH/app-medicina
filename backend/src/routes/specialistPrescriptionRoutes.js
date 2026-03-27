const express = require('express');
const { v4: uuidv4 } = require('uuid');

const { getPool } = require('../db/mysql');
const { verifyAccessToken } = require('../auth/jwt');

const router = express.Router();

// GET /api/specialist/prescriptions — fórmulas emitidas por el especialista
router.get('/', async (req, res) => {
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

  try {
    const [rows] = await pool.query(
      `SELECT pr.id, pr.patient_user_id, pr.title, pr.status, pr.estimated_total_cents,
              pr.created_at, pr.paid_at,
              pp.first_name AS patient_first_name, pp.last_name AS patient_last_name
       FROM prescriptions pr
       LEFT JOIN profiles pp ON pp.user_id = pr.patient_user_id
       WHERE pr.specialist_user_id = ?
       ORDER BY pr.created_at DESC`,
      [specialistId],
    );

    const prescriptions = rows.map((r) => ({
      id: r.id,
      patient_user_id: r.patient_user_id,
      patient_first_name: r.patient_first_name ? String(r.patient_first_name) : null,
      patient_last_name: r.patient_last_name ? String(r.patient_last_name) : null,
      title: r.title,
      status: r.status,
      estimated_total_cents: r.estimated_total_cents,
      created_at: r.created_at instanceof Date ? r.created_at.toISOString() : String(r.created_at),
      paid_at: r.paid_at ? (r.paid_at instanceof Date ? r.paid_at.toISOString() : String(r.paid_at)) : null,
    }));

    return res.json({ prescriptions });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

function getBearerToken(req) {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  if (parts[0] !== 'Bearer') return null;
  return parts[1];
}

// POST /api/specialist/prescriptions
router.post('/', async (req, res) => {
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
    return res.status(403).json({ error: 'Solo especialistas pueden registrar fórmulas' });
  }

  const specialistId = payload.sub;
  const body = req.body || {};
  const patientEmail = (body.patient_email ?? '').trim().toLowerCase();
  let patientUserId = (body.patient_user_id ?? '').trim();

  const title = (body.title ?? '').trim() || 'Fórmula médica';
  const items = Array.isArray(body.items) ? body.items : [];

  if (!patientUserId && !patientEmail) {
    return res.status(400).json({ error: 'Indica patient_email o patient_user_id' });
  }
  if (items.length === 0) {
    return res.status(400).json({ error: 'Añade al menos un medicamento' });
  }

  for (let i = 0; i < items.length; i += 1) {
    const it = items[i];
    const drug = (it && it.drug_name ? String(it.drug_name) : '').trim();
    if (!drug) {
      return res.status(400).json({ error: `Medicamento ${i + 1}: nombre requerido` });
    }
  }

  try {
    if (!patientUserId && patientEmail) {
      const [rows] = await pool.query(
        `SELECT u.id FROM users u
         INNER JOIN profiles p ON p.user_id = u.id
         WHERE LOWER(TRIM(u.email)) = ? AND p.role = 'Paciente'`,
        [patientEmail],
      );
      if (!rows.length) {
        return res.status(404).json({ error: 'No hay paciente con ese correo' });
      }
      patientUserId = rows[0].id;
    } else {
      const [rows] = await pool.query(
        `SELECT u.id FROM users u
         INNER JOIN profiles p ON p.user_id = u.id
         WHERE u.id = ? AND p.role = 'Paciente'`,
        [patientUserId],
      );
      if (!rows.length) {
        return res.status(404).json({ error: 'Paciente no encontrado' });
      }
    }

    let estimatedCents = 0;
    if (body.estimated_total_cents != null) {
      const n = Number.parseInt(String(body.estimated_total_cents), 10);
      if (!Number.isNaN(n) && n >= 0) estimatedCents = n;
    } else {
      estimatedCents = items.length * 15000;
    }

    const presId = uuidv4();
    await pool.query(
      `INSERT INTO prescriptions (
        id, patient_user_id, specialist_user_id, title, status, estimated_total_cents
      ) VALUES (?, ?, ?, ?, 'pending_payment', ?)`,
      [presId, patientUserId, specialistId, title, estimatedCents],
    );

    for (let i = 0; i < items.length; i += 1) {
      const it = items[i];
      const drug_name = String(it.drug_name).trim();
      const dosage = it.dosage != null ? String(it.dosage).trim() : null;
      const posology = it.posology != null ? String(it.posology).trim() : null;
      let quantity = null;
      if (it.quantity != null && it.quantity !== '') {
        const q = Number.parseInt(String(it.quantity), 10);
        if (!Number.isNaN(q)) quantity = q;
      }
      await pool.query(
        `INSERT INTO prescription_items (id, prescription_id, drug_name, dosage, posology, quantity, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [uuidv4(), presId, drug_name, dosage || null, posology || null, quantity, i],
      );
    }

    return res.status(201).json({
      id: presId,
      patient_user_id: patientUserId,
      title,
      status: 'pending_payment',
      estimated_total_cents: estimatedCents,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = { specialistPrescriptionRouter: router };
