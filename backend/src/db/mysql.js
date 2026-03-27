const mysql = require('mysql2/promise');
const { v4: uuidv4 } = require('uuid');

let pool;

async function columnExists(poolConn, table, column) {
  const [rows] = await poolConn.query(
    `SELECT COUNT(*) AS c
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column],
  );
  return rows[0].c > 0;
}

async function migrateLegacyProfiles(poolConn) {
  const hasUserId = await columnExists(poolConn, 'profiles', 'user_id');
  if (hasUserId) return;

  await poolConn.query(`ALTER TABLE profiles ADD COLUMN user_id CHAR(36) NULL AFTER id`);
  await poolConn.query(`UPDATE profiles SET user_id = id WHERE user_id IS NULL`);
  await poolConn.query(`DELETE FROM profiles WHERE user_id NOT IN (SELECT id FROM users)`);
  await poolConn.query(`ALTER TABLE profiles MODIFY user_id CHAR(36) NOT NULL`);
  await poolConn.query(`CREATE UNIQUE INDEX ux_profiles_user_id ON profiles (user_id)`);

  const [fkRows] = await poolConn.query(
    `SELECT CONSTRAINT_NAME
     FROM information_schema.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'profiles'
       AND CONSTRAINT_TYPE = 'FOREIGN KEY'
       AND CONSTRAINT_NAME = 'fk_profiles_user'`,
  );
  if (!fkRows.length) {
    await poolConn.query(
      `ALTER TABLE profiles
       ADD CONSTRAINT fk_profiles_user
       FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`,
    );
  }
}

async function migratePaymentPlanColumn(poolConn) {
  if (await columnExists(poolConn, 'profiles', 'payment_plan')) return;
  await poolConn.query(`
    ALTER TABLE profiles
    ADD COLUMN payment_plan ENUM('pay_per_consult','monthly_subscription') NOT NULL DEFAULT 'pay_per_consult'
    AFTER professional_card_path
  `);
}

async function migrateConsultationScheduleColumns(poolConn) {
  if (!(await columnExists(poolConn, 'consultation_requests', 'scheduled_at'))) {
    await poolConn.query(
      `ALTER TABLE consultation_requests ADD COLUMN scheduled_at DATETIME NULL AFTER status`,
    );
  }
  if (!(await columnExists(poolConn, 'consultation_requests', 'paid_at'))) {
    await poolConn.query(
      `ALTER TABLE consultation_requests ADD COLUMN paid_at DATETIME NULL AFTER scheduled_at`,
    );
  }
}

async function migrateSpecialistPublicProfile(poolConn) {
  const afterBio = (await columnExists(poolConn, 'profiles', 'payment_plan'))
    ? 'payment_plan'
    : 'professional_card_path';

  if (!(await columnExists(poolConn, 'profiles', 'bio_short'))) {
    await poolConn.query(
      `ALTER TABLE profiles ADD COLUMN bio_short VARCHAR(600) NULL AFTER ${afterBio}`,
    );
  }
  if (!(await columnExists(poolConn, 'profiles', 'profile_photo_path'))) {
    await poolConn.query(
      `ALTER TABLE profiles ADD COLUMN profile_photo_path VARCHAR(512) NULL AFTER bio_short`,
    );
  }
  if (!(await columnExists(poolConn, 'profiles', 'average_rating'))) {
    await poolConn.query(
      `ALTER TABLE profiles ADD COLUMN average_rating DECIMAL(3,2) NULL AFTER profile_photo_path`,
    );
  }
  if (!(await columnExists(poolConn, 'profiles', 'years_experience'))) {
    await poolConn.query(
      `ALTER TABLE profiles ADD COLUMN years_experience INT NULL AFTER average_rating`,
    );
  }
}

async function migrateSpecialistRatingsTable(poolConn) {
  await poolConn.query(`
    CREATE TABLE IF NOT EXISTS specialist_ratings (
      id CHAR(36) PRIMARY KEY,
      consultation_request_id CHAR(36) NOT NULL,
      patient_user_id CHAR(36) NOT NULL,
      specialist_user_id CHAR(36) NOT NULL,
      rating TINYINT NOT NULL,
      comment TEXT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY ux_ratings_consultation (consultation_request_id),
      CONSTRAINT fk_sr_consultation FOREIGN KEY (consultation_request_id) REFERENCES consultation_requests(id) ON DELETE CASCADE,
      CONSTRAINT fk_sr_patient FOREIGN KEY (patient_user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT fk_sr_specialist FOREIGN KEY (specialist_user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);
}

async function initDb() {
  const host = process.env.MYSQL_HOST || '127.0.0.1';
  const port = parseInt(process.env.MYSQL_PORT || '3306', 10);
  const user = process.env.MYSQL_USER || 'root';
  const password = process.env.MYSQL_PASSWORD || '';
  const database = process.env.MYSQL_DATABASE || 'appmedicina';

  const bootstrap = await mysql.createConnection({ host, port, user, password });
  await bootstrap.query(`CREATE DATABASE IF NOT EXISTS \`${database}\`;`);
  await bootstrap.end();

  pool = mysql.createPool({
    host,
    port,
    user,
    password,
    database,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id CHAR(36) PRIMARY KEY,
      email VARCHAR(255) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS profiles (
      id CHAR(36) PRIMARY KEY,
      user_id CHAR(36) NOT NULL UNIQUE,
      role ENUM('Paciente','Especialista') NOT NULL,
      first_name VARCHAR(120) NOT NULL,
      last_name VARCHAR(120) NOT NULL,
      age INT NULL,
      phone VARCHAR(40) NULL,
      professional_title VARCHAR(255) NULL,
      professional_specialty VARCHAR(255) NULL,
      professional_card_path VARCHAR(512) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  await migrateLegacyProfiles(pool);
  await migratePaymentPlanColumn(pool);
  await migrateSpecialistPublicProfile(pool);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS consultation_requests (
      id CHAR(36) PRIMARY KEY,
      patient_user_id CHAR(36) NOT NULL,
      specialty VARCHAR(120) NOT NULL,
      description TEXT NOT NULL,
      assignment_mode ENUM('manual','auto') NOT NULL,
      specialist_user_id CHAR(36) NULL,
      specialist_label VARCHAR(255) NULL,
      status VARCHAR(64) NOT NULL DEFAULT 'pending',
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_consultation_patient FOREIGN KEY (patient_user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT fk_consultation_specialist FOREIGN KEY (specialist_user_id) REFERENCES users(id) ON DELETE SET NULL
    );
  `);

  await migrateConsultationScheduleColumns(pool);
  await migrateSpecialistRatingsTable(pool);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS patient_care_entries (
      id CHAR(36) PRIMARY KEY,
      patient_user_id CHAR(36) NOT NULL,
      category ENUM(
        'therapy_result',
        'evolution',
        'authorization',
        'recommendation',
        'referral'
      ) NOT NULL,
      title VARCHAR(255) NOT NULL,
      summary TEXT NULL,
      detail TEXT NULL,
      occurred_at DATE NULL,
      specialist_user_id CHAR(36) NULL,
      referral_target_specialty VARCHAR(255) NULL,
      referral_target_specialist_user_id CHAR(36) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_pce_patient FOREIGN KEY (patient_user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT fk_pce_specialist FOREIGN KEY (specialist_user_id) REFERENCES users(id) ON DELETE SET NULL,
      CONSTRAINT fk_pce_ref_specialist FOREIGN KEY (referral_target_specialist_user_id) REFERENCES users(id) ON DELETE SET NULL
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS prescriptions (
      id CHAR(36) PRIMARY KEY,
      patient_user_id CHAR(36) NOT NULL,
      specialist_user_id CHAR(36) NULL,
      title VARCHAR(255) NOT NULL DEFAULT 'Fórmula médica',
      status ENUM('pending_payment','paid','shipping','delivered','cancelled') NOT NULL DEFAULT 'pending_payment',
      estimated_total_cents INT NOT NULL DEFAULT 0,
      delivery_address_line VARCHAR(512) NULL,
      delivery_city VARCHAR(120) NULL,
      delivery_lat DECIMAL(10,7) NULL,
      delivery_lng DECIMAL(10,7) NULL,
      paid_at TIMESTAMP NULL,
      shipped_at TIMESTAMP NULL,
      delivered_at TIMESTAMP NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_pres_patient FOREIGN KEY (patient_user_id) REFERENCES users(id) ON DELETE CASCADE,
      CONSTRAINT fk_pres_specialist FOREIGN KEY (specialist_user_id) REFERENCES users(id) ON DELETE SET NULL
    );
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS prescription_items (
      id CHAR(36) PRIMARY KEY,
      prescription_id CHAR(36) NOT NULL,
      drug_name VARCHAR(255) NOT NULL,
      dosage VARCHAR(120) NULL,
      posology VARCHAR(255) NULL,
      quantity INT NULL,
      sort_order INT NOT NULL DEFAULT 0,
      CONSTRAINT fk_pi_pres FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE
    );
  `);

  await seedDemoPrescription(pool);
}

async function seedDemoPrescription(poolConn) {
  try {
    const [countRows] = await poolConn.query('SELECT COUNT(*) AS c FROM prescriptions');
    if (countRows[0].c > 0) return;
    const [patients] = await poolConn.query(
      `SELECT u.id FROM users u INNER JOIN profiles p ON p.user_id = u.id WHERE p.role = 'Paciente' LIMIT 1`,
    );
    if (!patients.length) return;
    const patientId = patients[0].id;
    const [specs] = await poolConn.query(
      `SELECT u.id FROM users u INNER JOIN profiles p ON p.user_id = u.id WHERE p.role = 'Especialista' LIMIT 1`,
    );
    const specId = specs.length ? specs[0].id : null;
    const presId = uuidv4();
    await poolConn.query(
      `INSERT INTO prescriptions (id, patient_user_id, specialist_user_id, title, status, estimated_total_cents)
       VALUES (?, ?, ?, ?, 'pending_payment', 45000)`,
      [presId, patientId, specId, 'Fórmula — ejemplo MediConnect'],
    );
    const itemRows = [
      [uuidv4(), presId, 'Acetaminofén 500 mg', '500 mg', 'Cada 8 horas con alimentos', 20, 0],
      [uuidv4(), presId, 'Ibuprofeno', '400 mg', 'Solo si hay dolor', 10, 1],
    ];
    for (const it of itemRows) {
      await poolConn.query(
        `INSERT INTO prescription_items (id, prescription_id, drug_name, dosage, posology, quantity, sort_order)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        it,
      );
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('seedDemoPrescription:', e.message || e);
  }
}

function getPool() {
  if (!pool) {
    throw new Error('Database not initialized. Call initDb() first.');
  }
  return pool;
}

async function closePool() {
  if (!pool) return;
  const p = pool;
  pool = null;
  await p.end();
}

module.exports = { initDb, getPool, closePool };

