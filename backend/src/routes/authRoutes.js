const express = require('express');
const multer = require('multer');

const { supabaseAnon, supabaseAdmin } = require('../supabaseClient');

const router = express.Router();

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

function requireBodyFields(body, fields) {
  for (const f of fields) {
    if (body?.[f] === undefined || body?.[f] === null || body?.[f] === '') return f;
  }
  return null;
}

// POST /api/auth/register
// Soporta multipart/form-data para subir "professionalCard" (opcional).
router.post('/register', upload.single('professionalCard'), async (req, res) => {
  try {
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

    const missing = requireBodyFields(req.body, ['role', 'firstName', 'lastName', 'email', 'password']);
    if (missing) return res.status(400).json({ error: `Missing field: ${missing}` });

    const profileRole = role === 'Especialista' ? 'Especialista' : 'Paciente';
    const safeAge = age ? parseInt(age, 10) : null;

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: false,
    });

    if (createErr) return res.status(400).json({ error: createErr.message });

    const userId = created?.user?.id;

    let professionalCardPath = null;
    if (profileRole === 'Especialista' && req.file) {
      const ext = (req.file.originalname.split('.').pop() || 'bin').toLowerCase();
      const fileExt = ['jpg', 'jpeg', 'png', 'pdf'].includes(ext) ? ext : 'bin';
      professionalCardPath = `${userId}/professional_card.${fileExt}`;

      const contentType = req.file.mimetype || 'application/octet-stream';

      const bucket = process.env.PROFESSIONAL_CARDS_BUCKET || 'professional_cards';
      const { error: uploadErr } = await supabaseAdmin.storage
        .from(bucket)
        .upload(professionalCardPath, req.file.buffer, {
          contentType,
          upsert: true,
        });

      if (uploadErr) return res.status(400).json({ error: uploadErr.message });
    }

    const { error: profileErr } = await supabaseAdmin.from('profiles').insert({
      id: userId,
      role: profileRole,
      first_name: firstName,
      last_name: lastName,
      age: safeAge,
      phone: phone || null,
      professional_title: profileRole === 'Especialista' ? (professionalTitle || null) : null,
      professional_specialty: profileRole === 'Especialista' ? (specialty || null) : null,
      professional_card_path: professionalCardPath,
    });

    if (profileErr) return res.status(400).json({ error: profileErr.message });

    // Iniciar sesión automáticamente para que el cliente pueda navegar al home.
    const { data: signInData, error: signInErr } = await supabaseAnon.auth.signInWithPassword({
      email,
      password,
    });

    if (signInErr) return res.status(400).json({ error: signInErr.message });

    return res.status(201).json({
      access_token: signInData.session?.access_token,
      refresh_token: signInData.session?.refresh_token,
      user: {
        id: signInData.user?.id,
        email,
      },
      role: profileRole,
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/login
// Responde con tokens para que el cliente llame a /api/profile/me
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) return res.status(400).json({ error: 'Missing email or password' });

    const { data, error } = await supabaseAnon.auth.signInWithPassword({
      email,
      password,
    });

    if (error) return res.status(401).json({ error: error.message });

    return res.json({
      access_token: data.session?.access_token,
      refresh_token: data.session?.refresh_token,
      user: {
        id: data.user?.id,
        email: data.user?.email,
      },
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { authRouter: router };

