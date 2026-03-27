const jwt = require('jsonwebtoken');

function mustEnv(name, value) {
  if (!value) throw new Error(`Missing env var: ${name}`);
  return value;
}

function signAccessToken(payload) {
  const secret = mustEnv('JWT_SECRET', process.env.JWT_SECRET);
  return jwt.sign(payload, secret, { expiresIn: '7d' });
}

function verifyAccessToken(token) {
  const secret = mustEnv('JWT_SECRET', process.env.JWT_SECRET);
  return jwt.verify(token, secret);
}

module.exports = { signAccessToken, verifyAccessToken };
