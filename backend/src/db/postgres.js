const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');

let nativePool;

function toPgSql(sql) {
  let n = 0;
  return sql.replace(/\?/g, () => `$${++n}`);
}

function isSelectLike(sql) {
  const s = sql.trim().replace(/^\(/, '').trim();
  const word = s.split(/\s+/)[0].toUpperCase();
  return word === 'SELECT' || word === 'WITH' || word === 'SHOW' || word === 'DESCRIBE';
}

function formatQueryResult(res, sql) {
  if (isSelectLike(sql)) {
    return [res.rows];
  }
  return [{ affectedRows: res.rowCount ?? 0, insertId: 0 }];
}

function wrapPool(pool) {
  return {
    query: async (sql, params = []) => {
      const res = await pool.query(toPgSql(sql), params);
      return formatQueryResult(res, sql);
    },
    getConnection: async () => {
      const client = await pool.connect();
      return {
        query: async (sql, params = []) => {
          const res = await client.query(toPgSql(sql), params);
          return formatQueryResult(res, sql);
        },
        beginTransaction: async () => {
          await client.query('BEGIN');
        },
        commit: async () => {
          await client.query('COMMIT');
        },
        rollback: async () => {
          await client.query('ROLLBACK');
        },
        release: () => client.release(),
      };
    },
  };
}

let wrappedPool;

async function runBootstrap(client) {
  const run = (q) => client.query(q);

  await run(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS profiles (
      id UUID PRIMARY KEY,
      user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      role VARCHAR(20) NOT NULL CHECK (role IN ('Paciente','Especialista')),
      first_name VARCHAR(120) NOT NULL,
      last_name VARCHAR(120) NOT NULL,
      age INT NULL,
      phone VARCHAR(40) NULL,
      professional_title VARCHAR(255) NULL,
      professional_specialty VARCHAR(255) NULL,
      professional_card_path VARCHAR(512) NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      payment_plan VARCHAR(40) NOT NULL DEFAULT 'pay_per_consult'
        CHECK (payment_plan IN ('pay_per_consult','monthly_subscription')),
      bio_short VARCHAR(600) NULL,
      profile_photo_path VARCHAR(512) NULL,
      average_rating DECIMAL(3,2) NULL,
      years_experience INT NULL,
      available_for_assignments BOOLEAN NOT NULL DEFAULT TRUE
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS consultation_requests (
      id UUID PRIMARY KEY,
      patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      specialty VARCHAR(120) NOT NULL,
      description TEXT NOT NULL,
      assignment_mode VARCHAR(20) NOT NULL CHECK (assignment_mode IN ('manual','auto')),
      specialist_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
      specialist_label VARCHAR(255) NULL,
      status VARCHAR(64) NOT NULL DEFAULT 'pending',
      scheduled_at TIMESTAMPTZ NULL,
      paid_at TIMESTAMPTZ NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      modality VARCHAR(20) NULL,
      priority VARCHAR(20) NULL,
      antecedentes TEXT NULL,
      details_json JSONB NULL
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS specialist_ratings (
      id UUID PRIMARY KEY,
      consultation_request_id UUID NOT NULL UNIQUE REFERENCES consultation_requests(id) ON DELETE CASCADE,
      patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      specialist_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS patient_care_entries (
      id UUID PRIMARY KEY,
      patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      category VARCHAR(40) NOT NULL CHECK (category IN (
        'therapy_result','evolution','authorization','recommendation','referral'
      )),
      title VARCHAR(255) NOT NULL,
      summary TEXT NULL,
      detail TEXT NULL,
      occurred_at DATE NULL,
      specialist_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
      referral_target_specialty VARCHAR(255) NULL,
      referral_target_specialist_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS prescriptions (
      id UUID PRIMARY KEY,
      patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      specialist_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
      title VARCHAR(255) NOT NULL DEFAULT 'Fórmula médica',
      status VARCHAR(32) NOT NULL DEFAULT 'pending_payment' CHECK (status IN (
        'pending_payment','paid','shipping','delivered','cancelled'
      )),
      estimated_total_cents INT NOT NULL DEFAULT 0,
      delivery_address_line VARCHAR(512) NULL,
      delivery_city VARCHAR(120) NULL,
      delivery_lat DECIMAL(10,7) NULL,
      delivery_lng DECIMAL(10,7) NULL,
      paid_at TIMESTAMPTZ NULL,
      shipped_at TIMESTAMPTZ NULL,
      delivered_at TIMESTAMPTZ NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS prescription_items (
      id UUID PRIMARY KEY,
      prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
      drug_name VARCHAR(255) NOT NULL,
      dosage VARCHAR(120) NULL,
      posology VARCHAR(255) NULL,
      quantity INT NULL,
      sort_order INT NOT NULL DEFAULT 0
    );
  `);

  await run(
    'CREATE INDEX IF NOT EXISTS ix_consultation_patient ON consultation_requests(patient_user_id);',
  );
  await run(
    'CREATE INDEX IF NOT EXISTS ix_consultation_specialist ON consultation_requests(specialist_user_id);',
  );
  await run('CREATE INDEX IF NOT EXISTS ix_prescriptions_patient ON prescriptions(patient_user_id);');
  await run(
    'CREATE INDEX IF NOT EXISTS ix_prescriptions_specialist ON prescriptions(specialist_user_id);',
  );
  await run('CREATE INDEX IF NOT EXISTS ix_pi_prescription ON prescription_items(prescription_id);');
  await run(
    'CREATE INDEX IF NOT EXISTS ix_sr_specialist ON specialist_ratings(specialist_user_id);',
  );
}

async function migrateConsultationRequestsColumns(client) {
  const run = (q) => client.query(q);
  await run(
    `ALTER TABLE consultation_requests ADD COLUMN IF NOT EXISTS modality VARCHAR(20)`,
  );
  await run(
    `ALTER TABLE consultation_requests ADD COLUMN IF NOT EXISTS priority VARCHAR(20)`,
  );
  await run(
    `ALTER TABLE consultation_requests ADD COLUMN IF NOT EXISTS antecedentes TEXT`,
  );
  await run(
    `ALTER TABLE consultation_requests ADD COLUMN IF NOT EXISTS details_json JSONB`,
  );
}

async function seedDemoPrescription(client) {
  try {
    const { rows: countRows } = await client.query('SELECT COUNT(*)::int AS c FROM prescriptions');
    if (countRows[0].c > 0) return;
    const { rows: patients } = await client.query(
      `SELECT u.id FROM users u INNER JOIN profiles p ON p.user_id = u.id WHERE p.role = 'Paciente' LIMIT 1`,
    );
    if (!patients.length) return;
    const patientId = patients[0].id;
    const { rows: specs } = await client.query(
      `SELECT u.id FROM users u INNER JOIN profiles p ON p.user_id = u.id WHERE p.role = 'Especialista' LIMIT 1`,
    );
    const specId = specs.length ? specs[0].id : null;
    const presId = uuidv4();
    await client.query(
      `INSERT INTO prescriptions (id, patient_user_id, specialist_user_id, title, status, estimated_total_cents)
       VALUES ($1, $2, $3, $4, 'pending_payment', 45000)`,
      [presId, patientId, specId, 'Fórmula — ejemplo MediConnect'],
    );
    const itemRows = [
      [uuidv4(), presId, 'Acetaminofén 500 mg', '500 mg', 'Cada 8 horas con alimentos', 20, 0],
      [uuidv4(), presId, 'Ibuprofeno', '400 mg', 'Solo si hay dolor', 10, 1],
    ];
    for (const it of itemRows) {
      await client.query(
        `INSERT INTO prescription_items (id, prescription_id, drug_name, dosage, posology, quantity, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        it,
      );
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('seedDemoPrescription:', e.message || e);
  }
}

async function initDb() {
  const connectionString = (process.env.DATABASE_URL || '').trim();
  if (!connectionString) {
    throw new Error(
      'DATABASE_URL vacia o ausente. En backend/.env pon la URI de Supabase y guarda el archivo (Ctrl+S) antes de npm run dev.',
    );
  }

  const urlLooksRemote =
    /supabase\.co|pooler\.supabase|neon\.tech|render\.com|railway\.app/i.test(connectionString);
  let ssl = false;
  if (process.env.DATABASE_SSL === 'true' || urlLooksRemote) {
    ssl = { rejectUnauthorized: process.env.DATABASE_SSL_STRICT === 'true' };
  }
  if (process.env.DATABASE_SSL === 'false') {
    ssl = false;
  }

  nativePool = new Pool({
    connectionString,
    max: Number.parseInt(process.env.PG_POOL_MAX || '10', 10),
    ssl,
  });

  const client = await nativePool.connect();
  try {
    await runBootstrap(client);
    await migrateConsultationRequestsColumns(client);
    await seedDemoPrescription(client);
  } finally {
    client.release();
  }

  wrappedPool = wrapPool(nativePool);
}

function getPool() {
  if (!wrappedPool) {
    throw new Error('Database not initialized. Call initDb() first.');
  }
  return wrappedPool;
}

async function closePool() {
  if (!nativePool) return;
  const p = nativePool;
  nativePool = null;
  wrappedPool = null;
  await p.end();
}

module.exports = { initDb, getPool, closePool, toPgSql };
