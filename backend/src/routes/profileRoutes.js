const express = require('express');

const { supabaseAnon, supabaseAdmin } = require('../supabaseClient');

const router = express.Router();

function getBearerToken(req) {
  const auth = req.headers.authorization || '';
  const parts = auth.split(' ');
  if (parts.length !== 2) return null;
  if (parts[0] !== 'Bearer') return null;
  return parts[1];
}

// GET /api/profile/me
// Requiere Authorization: Bearer <access_token>
router.get('/me', async (req, res) => {
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ error: 'Missing bearer token' });

    const { data: userData, error: userErr } = await supabaseAnon.auth.getUser(token);
    if (userErr) return res.status(401).json({ error: userErr.message });

    const userId = userData?.user?.id;
    if (!userId) return res.status(401).json({ error: 'Invalid token' });

    const { data: profile, error: profileErr } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single();

    if (profileErr) return res.status(400).json({ error: profileErr.message });

    return res.json({ profile });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = { profileRouter: router };

