const express = require('express');

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

function fmtDateTime(d) {
  if (!d) return null;
  if (d instanceof Date) return d.toISOString().slice(0, 19).replace('T', ' ');
  return String(d);
}

function fmtDateOnly(d) {
  if (!d) return null;
  if (d instanceof Date) return d.toISOString().slice(0, 10);
  const s = String(d);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

function formatSpecialistName(row) {
  if (!row || !row.first_name) return null;
  return `Dr(a). ${row.first_name} ${row.last_name}`;
}

async function loadPrescriptionRow(pool, id, patientId) {
  const [rows] = await pool.query(
    `SELECT
      pr.id,
      pr.patient_user_id,
      pr.specialist_user_id,
      pr.title,
      pr.status,
      pr.estimated_total_cents,
      pr.delivery_address_line,
      pr.delivery_city,
      pr.delivery_lat,
      pr.delivery_lng,
      pr.paid_at,
      pr.shipped_at,
      pr.delivered_at,
      pr.created_at,
      sp.first_name AS specialist_first_name,
      sp.last_name AS specialist_last_name,
      sp.professional_specialty AS specialist_specialty
    FROM prescriptions pr
    LEFT JOIN profiles sp ON sp.user_id = pr.specialist_user_id
    WHERE pr.id = ? AND pr.patient_user_id = ?`,
    [id, patientId],
  );
  return rows[0] || null;
}

function mapPrescription(r) {
  return {
    id: r.id,
    title: r.title,
    status: r.status,
    estimated_total_cents: r.estimated_total_cents,
    delivery_address_line: r.delivery_address_line,
    delivery_city: r.delivery_city,
    delivery_lat: r.delivery_lat != null ? Number(r.delivery_lat) : null,
    delivery_lng: r.delivery_lng != null ? Number(r.delivery_lng) : null,
    paid_at: fmtDateTime(r.paid_at),
    shipped_at: fmtDateTime(r.shipped_at),
    delivered_at: fmtDateTime(r.delivered_at),
    created_at: fmtDateOnly(r.created_at),
    specialist_display_name: formatSpecialistName({
      first_name: r.specialist_first_name,
      last_name: r.specialist_last_name,
    }),
    specialist_specialty: r.specialist_specialty,
  };
}

// GET /api/patient/prescriptions
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
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;

  try {
    const [rows] = await pool.query(
      `SELECT
        pr.id,
        pr.title,
        pr.status,
        pr.estimated_total_cents,
        pr.delivery_address_line,
        pr.delivery_city,
        pr.delivery_lat,
        pr.delivery_lng,
        pr.paid_at,
        pr.shipped_at,
        pr.delivered_at,
        pr.created_at,
        sp.first_name AS specialist_first_name,
        sp.last_name AS specialist_last_name,
        sp.professional_specialty AS specialist_specialty
      FROM prescriptions pr
      LEFT JOIN profiles sp ON sp.user_id = pr.specialist_user_id
      WHERE pr.patient_user_id = ?
      ORDER BY pr.created_at DESC`,
      [patientId],
    );

    const prescriptions = rows.map((r) => mapPrescription(r));
    return res.json({ prescriptions });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// GET /api/patient/prescriptions/:id
router.get('/:id', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;
  const { id } = req.params;

  try {
    const row = await loadPrescriptionRow(pool, id, patientId);
    if (!row) return res.status(404).json({ error: 'Fórmula no encontrada' });

    const [items] = await pool.query(
      `SELECT id, drug_name, dosage, posology, quantity, sort_order
       FROM prescription_items
       WHERE prescription_id = ?
       ORDER BY sort_order ASC, drug_name ASC`,
      [id],
    );

    const prescription = mapPrescription(row);
    prescription.items = items.map((it) => ({
      id: it.id,
      drug_name: it.drug_name,
      dosage: it.dosage,
      posology: it.posology,
      quantity: it.quantity,
      sort_order: it.sort_order,
    }));

    return res.json({ prescription });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PATCH /api/patient/prescriptions/:id/delivery
router.patch('/:id/delivery', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;
  const { id } = req.params;
  const body = req.body || {};

  const sets = [];
  const params = [];

  if (Object.prototype.hasOwnProperty.call(body, 'delivery_address_line')) {
    const v = (body.delivery_address_line ?? '').trim() || null;
    sets.push('delivery_address_line = ?');
    params.push(v);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'delivery_city')) {
    const v = (body.delivery_city ?? '').trim() || null;
    sets.push('delivery_city = ?');
    params.push(v);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'delivery_lat')) {
    let v = body.delivery_lat;
    if (v != null && typeof v === 'string') v = Number.parseFloat(v);
    if (v != null && Number.isNaN(v)) v = null;
    sets.push('delivery_lat = ?');
    params.push(v);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'delivery_lng')) {
    let v = body.delivery_lng;
    if (v != null && typeof v === 'string') v = Number.parseFloat(v);
    if (v != null && Number.isNaN(v)) v = null;
    sets.push('delivery_lng = ?');
    params.push(v);
  }

  try {
    const row = await loadPrescriptionRow(pool, id, patientId);
    if (!row) return res.status(404).json({ error: 'Fórmula no encontrada' });

    if (sets.length === 0) {
      return res.status(400).json({ error: 'Nada que actualizar' });
    }

    params.push(id, patientId);
    await pool.query(
      `UPDATE prescriptions SET ${sets.join(', ')} WHERE id = ? AND patient_user_id = ?`,
      params,
    );

    const updated = await loadPrescriptionRow(pool, id, patientId);
    return res.json({ prescription: mapPrescription(updated) });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/patient/prescriptions/:id/pay  (simulación de pago)
router.post('/:id/pay', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;
  const { id } = req.params;

  try {
    const row = await loadPrescriptionRow(pool, id, patientId);
    if (!row) return res.status(404).json({ error: 'Fórmula no encontrada' });
    if (row.status !== 'pending_payment') {
      return res.status(400).json({ error: 'Esta fórmula no está pendiente de pago' });
    }

    await pool.query(
      `UPDATE prescriptions SET status = 'paid', paid_at = CURRENT_TIMESTAMP WHERE id = ? AND patient_user_id = ?`,
      [id, patientId],
    );

    const updated = await loadPrescriptionRow(pool, id, patientId);
    return res.json({ prescription: mapPrescription(updated) });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/patient/prescriptions/:id/ship  (pasa a envío; requiere dirección)
router.post('/:id/ship', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;
  const { id } = req.params;

  try {
    const row = await loadPrescriptionRow(pool, id, patientId);
    if (!row) return res.status(404).json({ error: 'Fórmula no encontrada' });
    if (row.status !== 'paid') {
      return res.status(400).json({ error: 'Solo pedidos pagados pueden pasar a envío' });
    }
    const addrLine = row.delivery_address_line && String(row.delivery_address_line).trim();
    const city = row.delivery_city && String(row.delivery_city).trim();
    if (!addrLine && !city) {
      return res.status(400).json({ error: 'Indica una dirección de entrega antes de enviar' });
    }

    await pool.query(
      `UPDATE prescriptions SET status = 'shipping', shipped_at = CURRENT_TIMESTAMP WHERE id = ? AND patient_user_id = ?`,
      [id, patientId],
    );

    const updated = await loadPrescriptionRow(pool, id, patientId);
    return res.json({ prescription: mapPrescription(updated) });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// POST /api/patient/prescriptions/:id/deliver
router.post('/:id/deliver', async (req, res) => {
  const pool = getPool();
  const token = getBearerToken(req);
  if (!token) return res.status(401).json({ error: 'Token requerido' });

  let payload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
  if (payload.role && payload.role !== 'Paciente') {
    return res.status(403).json({ error: 'Solo pacientes' });
  }

  const patientId = payload.sub;
  const { id } = req.params;

  try {
    const row = await loadPrescriptionRow(pool, id, patientId);
    if (!row) return res.status(404).json({ error: 'Fórmula no encontrada' });
    if (row.status !== 'shipping') {
      return res.status(400).json({ error: 'Solo pedidos en envío pueden marcarse como entregados' });
    }

    await pool.query(
      `UPDATE prescriptions SET status = 'delivered', delivered_at = CURRENT_TIMESTAMP WHERE id = ? AND patient_user_id = ?`,
      [id, patientId],
    );

    const updated = await loadPrescriptionRow(pool, id, patientId);
    return res.json({ prescription: mapPrescription(updated) });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = { patientPrescriptionRouter: router };
