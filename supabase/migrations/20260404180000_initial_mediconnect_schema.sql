-- Espejo de la migración aplicada vía Supabase MCP (AppMedicina).
-- Tablas MediConnect: usuarios JWT propios, perfiles, consultas, fórmulas, seguimiento.

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS specialist_ratings (
  id UUID PRIMARY KEY,
  consultation_request_id UUID NOT NULL UNIQUE REFERENCES consultation_requests(id) ON DELETE CASCADE,
  patient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  specialist_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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

CREATE TABLE IF NOT EXISTS prescription_items (
  id UUID PRIMARY KEY,
  prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  drug_name VARCHAR(255) NOT NULL,
  dosage VARCHAR(120) NULL,
  posology VARCHAR(255) NULL,
  quantity INT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS ix_consultation_patient ON consultation_requests(patient_user_id);
CREATE INDEX IF NOT EXISTS ix_consultation_specialist ON consultation_requests(specialist_user_id);
CREATE INDEX IF NOT EXISTS ix_prescriptions_patient ON prescriptions(patient_user_id);
CREATE INDEX IF NOT EXISTS ix_prescriptions_specialist ON prescriptions(specialist_user_id);
CREATE INDEX IF NOT EXISTS ix_pi_prescription ON prescription_items(prescription_id);
CREATE INDEX IF NOT EXISTS ix_sr_specialist ON specialist_ratings(specialist_user_id);
