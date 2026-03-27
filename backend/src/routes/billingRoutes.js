const express = require('express');

const billing = require('../config/billing');

const router = express.Router();

/**
 * GET /api/billing/rules
 * Reglas públicas para mostrar en apps (comisión, modalidades de pago del paciente).
 */
router.get('/rules', (req, res) => {
  return res.json({
    platform_commission_rate: billing.PLATFORM_COMMISSION_RATE,
    platform_commission_percent: billing.PLATFORM_COMMISSION_PERCENT,
    specialist_share_rate: billing.specialistShareRate,
    specialist_share_percent: billing.specialistSharePercent,
    patient_payment_modes: [
      { code: 'pay_per_consult', label: 'Pago por consulta' },
      { code: 'monthly_subscription', label: 'Suscripción mensual' },
    ],
  });
});

module.exports = { billingRouter: router };
