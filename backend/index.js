const path = require('path');

const express = require('express');
const cors = require('cors');
// Siempre cargar .env junto a index.js (carpeta backend), no desde process.cwd().
require('dotenv').config({ path: path.join(__dirname, '.env') });

const { initDb, closePool } = require('./src/db/postgres');
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

// Evita 404 si el cliente envía `//api/...` (barra duplicada tras el host).
app.use((req, _res, next) => {
  if (req.url && req.url.includes('//')) {
    const q = req.url.indexOf('?');
    const pathOnly = q === -1 ? req.url : req.url.slice(0, q);
    const query = q === -1 ? '' : req.url.slice(q);
    req.url = pathOnly.replace(/\/+/g, '/') + query;
  }
  next();
});

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

// Comprueba desde el navegador/emulador que es este backend (evita confundir otro servicio en el mismo puerto).
app.get('/api', (_req, res) => {
  res.json({
    ok: true,
    name: 'MediConnect API',
    try: ['/health', '/api/auth/login', '/api/consultations/specialists'],
  });
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

// Cualquier otra ruta: JSON (la app no debe recibir HTML 404 de Express).
app.use((req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada en MediConnect',
    method: req.method,
    path: req.originalUrl,
  });
});

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
    console.log(`PostgreSQL ready (uploads: ${uploadsRoot})`);
    server = app.listen(port, '0.0.0.0', () => {
      // eslint-disable-next-line no-console
      console.log(`Backend running on http://0.0.0.0:${port} (emulador Android: http://10.0.2.2:${port})`);
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
        'No se pudo conectar a PostgreSQL. Revisa DATABASE_URL en .env (Supabase: Project Settings → Database).',
      );
    }
    process.exit(1);
  }
})();

