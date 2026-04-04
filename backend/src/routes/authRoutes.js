const path = require('path');
const fs = require('fs');

const express = require('express');
const multer = require('multer');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');

const { getPool } = require('../db/postgres');
const { signAccessToken } = require('../auth/jwt');

const router = express.Router();

const uploadsDir = path.join(
  process.env.UPLOADS_DIR || path.join(__dirname, '..', '..', 'uploads'),
  'professional_cards',
);

fs.mkdirSync(uploadsDir, { recursive: true });

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

function requireBodyFields(body, fields) {
  for (const f of fields) {
    if (body?.[f] === undefined || body?.[f] === null || body?.[f] === '') return f;
  }
  return null;
}

function parseAge(ageStr) {
  const n = parseInt(String(ageStr).trim(), 10);
  if (!Number.isFinite(n) || n < 1 || n > 120) return null;
  return n;
}

function isValidPhone(phoneStr) {
  const s = String(phoneStr).trim();
  if (s.length < 8) return false;
  const digits = s.replace(/\D/g, '');
  return digits.length >= 7;
}

function buildAuthResponse({ userId, email, role }) {
  const payload = { sub: userId, email, role };
  const accessToken = signAccessToken(payload);
  return {
    access_token: accessToken,
    refresh_token: accessToken,
    user: {
      id: userId,
      email,
    },
    role,
  };
}

// POST /api/auth/register
router.post('/register', upload.single('professionalCard'), async (req, res) => {
  const pool = getPool();
  const {
    role,
    firstName,
    lastName,
    age,
    phone,
    email,
    password,
    professionalTitle,
    specialty,
  } = req.body || {};

  try {
    const missing = requireBodyFields(req.body, [
      'role',
      'firstName',
      'lastName',
      'email',
      'password',
      'age',
      'phone',
    ]);
    if (missing) {
      return res.status(400).json({ error: 'Faltan datos obligatorios del registro' });
    }

    const profileRole = role === 'Especialista' ? 'Especialista' : 'Paciente';
    const safeAge = parseAge(age);
    if (safeAge === null) {
      return res.status(400).json({ error: 'Indica una edad válida (entre 1 y 120 años)' });
    }
    if (!isValidPhone(phone)) {
      return res.status(400).json({ error: 'Indica un número de celular válido' });
    }
    const phoneTrim = String(phone).trim();
    const emailNorm = String(email).trim().toLowerCase();

    if (profileRole === 'Especialista') {
      const titleOk = professionalTitle && String(professionalTitle).trim();
      const specOk = specialty && String(specialty).trim();
      if (!titleOk) {
        return res.status(400).json({ error: 'El título profesional es obligatorio' });
      }
      if (!specOk) {
        return res.status(400).json({ error: 'Debes seleccionar un tipo de especialista' });
      }
      if (!req.file) {
        return res.status(400).json({ error: 'Debes adjuntar la tarjeta profesional (imagen o PDF)' });
      }
    }

    const passwordHash = await bcrypt.hash(String(password), 10);
    const userId = uuidv4();

    let professionalCardPath = null;
    if (profileRole === 'Especialista' && req.file) {
      const ext = (req.file.originalname.split('.').pop() || 'bin').toLowerCase();
      const fileExt = ['jpg', 'jpeg', 'png', 'pdf'].includes(ext) ? ext : 'bin';
      const filename = `${userId}_professional_card.${fileExt}`;
      const diskPath = path.join(uploadsDir, filename);
      await fs.promises.writeFile(diskPath, req.file.buffer);
      professionalCardPath = path.relative(path.join(__dirname, '..', '..'), diskPath).replace(/\\/g, '/');
    }

    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();

      await conn.query(
        `INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)`,
        [userId, emailNorm, passwordHash],
      );

      await conn.query(
        `INSERT INTO profiles (
          id, user_id, role, first_name, last_name, age, phone,
          professional_title, professional_specialty, professional_card_path
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          userId,
          userId,
          profileRole,
          String(firstName).trim(),
          String(lastName).trim(),
          safeAge,
          phoneTrim,
          profileRole === 'Especialista' ? (professionalTitle ? String(professionalTitle).trim() : null) : null,
          profileRole === 'Especialista' ? (specialty ? String(specialty).trim() : null) : null,
          professionalCardPath,
        ],
      );

      await conn.commit();
    } catch (e) {
      await conn.rollback();
      if (e && (e.code === '23505' || e.code === 'ER_DUP_ENTRY')) {
        return res.status(400).json({ error: 'Este correo ya está registrado' });
      }
      throw e;
    } finally {
      conn.release();
    }

    return res.status(201).json(buildAuthResponse({ userId, email: emailNorm, role: profileRole }));
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const pool = getPool();
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Correo y contraseña son obligatorios' });
  }

  try {
    const emailNorm = String(email).trim().toLowerCase();
    const [rows] = await pool.query(
      `SELECT u.id, u.password_hash, p.role
       FROM users u
       JOIN profiles p ON p.user_id = u.id
       WHERE u.email = ?
       LIMIT 1`,
      [emailNorm],
    );

    if (!rows.length) return res.status(401).json({ error: 'Correo o contraseña incorrectos' });

    const row = rows[0];
    const ok = await bcrypt.compare(String(password), row.password_hash);
    if (!ok) return res.status(401).json({ error: 'Correo o contraseña incorrectos' });

    return res.json(buildAuthResponse({ userId: row.id, email: emailNorm, role: row.role }));
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { authRouter: router };
