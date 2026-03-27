const path = require('path');

const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { initDb, closePool } = require('./src/db/mysql');
const { authRouter } = require('./src/routes/authRoutes');
const { profileRouter } = require('./src/routes/profileRoutes');
const { consultationRouter } = require('./src/routes/consultationRoutes');
const { billingRouter } = require('./src/routes/billingRoutes');
const { patientMonitoringRouter } = require('./src/routes/patientMonitoringRoutes');
const { patientPrescriptionRouter } = require('./src/routes/patientPrescriptionRoutes');
const { specialistPrescriptionRouter } = require('./src/routes/specialistPrescriptionRoutes');
const { patientConsultationRouter } = require('./src/routes/patientConsultationRoutes');
const { specialistConsultationRouter } = require('./src/routes/specialistConsultationRoutes');
const { specialistMonitoringRouter } = require('./src/routes/specialistMonitoringRoutes');

const app = express();

const corsOrigin = process.env.CORS_ORIGIN || '*';
app.use(
  cors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(',').map((s) => s.trim()),
  }),
);
app.use(express.json({ limit: '1mb' }));

const uploadsRoot = process.env.UPLOADS_DIR || path.join(__dirname, 'uploads');
app.use('/uploads', express.static(uploadsRoot));

function healthPayload() {
  return { ok: true };
}

app.get('/health', (req, res) => {
  res.json(healthPayload());
});

// Alias por error tipográfico común ("healt" sin segunda h)
app.get('/healt', (req, res) => {
  res.json(healthPayload());
});

app.use('/api/auth', authRouter);
app.use('/api/profile', profileRouter);
app.use('/api/consultations', consultationRouter);
app.use('/api/billing', billingRouter);
app.use('/api/patient/monitoring', patientMonitoringRouter);
app.use('/api/patient/prescriptions', patientPrescriptionRouter);
app.use('/api/specialist/prescriptions', specialistPrescriptionRouter);
app.use('/api/patient/consultations', patientConsultationRouter);
app.use('/api/specialist/consultations', specialistConsultationRouter);
app.use('/api/specialist/monitoring', specialistMonitoringRouter);

const port = Number.parseInt(process.env.PORT || '3000', 10);

let server;

async function shutdown(signal) {
  // eslint-disable-next-line no-console
  console.log(`\nCerrando backend (${signal})…`);
  try {
    if (server) {
      await new Promise((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    }
    await closePool();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
  }
  process.exit(0);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

(async () => {
  try {
    await initDb();
    // eslint-disable-next-line no-console
    console.log(`MySQL ready (uploads: ${uploadsRoot})`);
    server = app.listen(port, () => {
      // eslint-disable-next-line no-console
      console.log(`Backend running on port ${port}`);
    });
    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        // eslint-disable-next-line no-console
        console.error(
          `El puerto ${port} ya está en uso. Cierra el otro proceso (p. ej. otra ventana de Node) o define PORT distinto en .env`,
        );
      } else {
        // eslint-disable-next-line no-console
        console.error(err);
      }
      process.exit(1);
    });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to start:', e.message || e);
    if (e.code === 'ECONNREFUSED') {
      // eslint-disable-next-line no-console
      console.error(
        'No se pudo conectar a MySQL. Arranca el servicio MySQL y revisa MYSQL_HOST, MYSQL_PORT, MYSQL_USER y MYSQL_PASSWORD en .env',
      );
    }
    process.exit(1);
  }
})();

