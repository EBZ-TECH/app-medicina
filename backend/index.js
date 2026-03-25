const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { authRouter } = require('./src/routes/authRoutes');
const { profileRouter } = require('./src/routes/profileRoutes');

const app = express();

const corsOrigin = process.env.CORS_ORIGIN || '*';
app.use(
  cors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(',').map((s) => s.trim()),
  }),
);
app.use(express.json({ limit: '1mb' }));

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.use('/api/auth', authRouter);
app.use('/api/profile', profileRouter);

const port = process.env.PORT || 3000;
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Backend running on port ${port}`);
});

