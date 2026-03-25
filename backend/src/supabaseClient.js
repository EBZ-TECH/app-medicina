const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

function mustEnv(name, value) {
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}

const url = mustEnv('SUPABASE_URL', supabaseUrl);
const anonKey = mustEnv('SUPABASE_ANON_KEY', supabaseAnonKey);
const serviceRoleKey = mustEnv('SUPABASE_SERVICE_ROLE_KEY', supabaseServiceRoleKey);

// Cliente para autenticar usuarios con contraseña (login).
// Nunca uses el service role en endpoints públicos.
const supabaseAnon = createClient(url, anonKey, {
  auth: { persistSession: false },
});

// Cliente admin para crear usuarios y escribir en tablas/bucket.
const supabaseAdmin = createClient(url, serviceRoleKey, {
  auth: { persistSession: false },
});

module.exports = { supabaseAnon, supabaseAdmin };

