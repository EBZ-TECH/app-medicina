const path = require('path');
const fs = require('fs');

const express = require('express');
const multer = require('multer');

const { getPool } = require('../db/mysql');
const { verifyAccessToken } = require('../auth/jwt');

const uploadsBase = process.env.UPLOADS_DIR || path.join(__dirname, '..', '..', 'uploads');
const profilePhotosDir = path.join(uploadsBase, 'profile_photos');
fs.mkdirSync(profilePhotosDir, { recursive: true });

const uploadProfilePhoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

const router = express.Router();

function getBearerToken(req) {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  if (parts[0] !== 'Bearer') return null;
  return parts[1];
}

// GET /api/profile/me
router.get('/me', async (req, res) => {
  const pool = getPool();
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: 'Missing bearer token' });

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const userId = payload.sub;
    if (!userId) return res.status(401).json({ error: 'Invalid token' });

    const [rows] = await pool.query(`SELECT * FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    if (!rows.length) return res.status(404).json({ error: 'Profile not found' });

    let ratingCount = null;
    if (rows[0].role === 'Especialista') {
      const [cnt] = await pool.query(
        `SELECT COUNT(*) AS c FROM specialist_ratings WHERE specialist_user_id = ?`,
        [userId],
      );
      ratingCount = cnt[0].c;
    }

    return res.json({ profile: rows[0], rating_count: ratingCount });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// PATCH /api/profile/specialist-profile  { "bio_short": "...", "years_experience": 10 }
router.patch('/specialist-profile', async (req, res) => {
  const pool = getPool();
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: 'Token requerido' });

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch {
      return res.status(401).json({ error: 'Token inválido' });
    }

    const userId = payload.sub;
    if (!userId) return res.status(401).json({ error: 'Token inválido' });

    const [prows] = await pool.query(`SELECT role FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    if (!prows.length) return res.status(404).json({ error: 'Perfil no encontrado' });
    if (prows[0].role !== 'Especialista') {
      return res.status(403).json({ error: 'Solo especialistas pueden editar este perfil' });
    }

    const body = req.body || {};
    if (body.bio_short !== undefined) {
      const t = String(body.bio_short ?? '').trim().slice(0, 600);
      await pool.query(`UPDATE profiles SET bio_short = ? WHERE user_id = ?`, [t.length ? t : null, userId]);
    }
    if (body.years_experience !== undefined) {
      if (body.years_experience === null || body.years_experience === '') {
        await pool.query(`UPDATE profiles SET years_experience = NULL WHERE user_id = ?`, [userId]);
      } else {
        const n = Number.parseInt(String(body.years_experience), 10);
        if (Number.isNaN(n) || n < 0 || n > 80) {
          return res.status(400).json({ error: 'years_experience debe ser entre 0 y 80' });
        }
        await pool.query(`UPDATE profiles SET years_experience = ? WHERE user_id = ?`, [n, userId]);
      }
    }

    const [rows] = await pool.query(`SELECT * FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    const [cnt] = await pool.query(
      `SELECT COUNT(*) AS c FROM specialist_ratings WHERE specialist_user_id = ?`,
      [userId],
    );
    return res.json({ profile: rows[0], rating_count: cnt[0].c });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

const ALLOWED_PAYMENT_PLANS = new Set(['pay_per_consult', 'monthly_subscription']);

// PATCH /api/profile/payment-plan  { "payment_plan": "pay_per_consult" | "monthly_subscription" }
router.patch('/payment-plan', async (req, res) => {
  const pool = getPool();
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: 'Token requerido' });

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch {
      return res.status(401).json({ error: 'Token inválido' });
    }

    const userId = payload.sub;
    if (!userId) return res.status(401).json({ error: 'Token inválido' });

    const paymentPlan = req.body?.payment_plan;
    if (!paymentPlan || !ALLOWED_PAYMENT_PLANS.has(String(paymentPlan))) {
      return res.status(400).json({ error: 'Modalidad de pago no válida' });
    }

    const [prows] = await pool.query(`SELECT role FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    if (!prows.length) return res.status(404).json({ error: 'Perfil no encontrado' });
    if (prows[0].role !== 'Paciente') {
      return res.status(403).json({ error: 'Solo los pacientes pueden gestionar el plan de pago' });
    }

    await pool.query(`UPDATE profiles SET payment_plan = ? WHERE user_id = ?`, [paymentPlan, userId]);

    const [rows] = await pool.query(`SELECT * FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    return res.json({ profile: rows[0] });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// PATCH /api/profile/specialist-public  (multipart: bio_short, profilePhoto opcional)
router.patch('/specialist-public', uploadProfilePhoto.single('profilePhoto'), async (req, res) => {
  const pool = getPool();
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: 'Token requerido' });

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch {
      return res.status(401).json({ error: 'Token inválido' });
    }

    const userId = payload.sub;
    if (!userId) return res.status(401).json({ error: 'Token inválido' });

    const [prows] = await pool.query(`SELECT role FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    if (!prows.length) return res.status(404).json({ error: 'Perfil no encontrado' });
    if (prows[0].role !== 'Especialista') {
      return res.status(403).json({ error: 'Solo especialistas pueden editar este perfil' });
    }

    const rawBio = req.body?.bio_short;
    if (rawBio !== undefined && rawBio !== null) {
      const t = String(rawBio).trim().slice(0, 600);
      await pool.query(`UPDATE profiles SET bio_short = ? WHERE user_id = ?`, [t.length ? t : null, userId]);
    }

    if (req.file) {
      const ext = (req.file.originalname.split('.').pop() || 'jpg').toLowerCase();
      const fileExt = ['jpg', 'jpeg', 'png', 'webp'].includes(ext) ? ext : 'jpg';
      const rel = `profile_photos/${userId}.${fileExt}`;
      const diskPath = path.join(uploadsBase, rel);
      await fs.promises.writeFile(diskPath, req.file.buffer);
      await pool.query(`UPDATE profiles SET profile_photo_path = ? WHERE user_id = ?`, [rel, userId]);
    }

    const [rows] = await pool.query(`SELECT * FROM profiles WHERE user_id = ? LIMIT 1`, [userId]);
    return res.json({ profile: rows[0] });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
});

module.exports = { profileRouter: router };
