/** Reglas de facturación MediConnect (requisito: comisión plataforma 15 %). */
const PLATFORM_COMMISSION_RATE = 0.15;
const PLATFORM_COMMISSION_PERCENT = 15;

module.exports = {
  PLATFORM_COMMISSION_RATE,
  PLATFORM_COMMISSION_PERCENT,
  get specialistShareRate() {
    return 1 - PLATFORM_COMMISSION_RATE;
  },
  get specialistSharePercent() {
    return 100 - PLATFORM_COMMISSION_PERCENT;
  },
};
