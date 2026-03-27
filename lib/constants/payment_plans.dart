/// Códigos alineados con `profiles.payment_plan` en el backend.
const String kPaymentPlanPayPerConsult = 'pay_per_consult';
const String kPaymentPlanMonthly = 'monthly_subscription';

String paymentPlanLabel(String? code) {
  if (code == kPaymentPlanMonthly) return 'Suscripción mensual';
  return 'Pago por consulta';
}

String paymentPlanSubtitleForCard(String code) {
  if (code == kPaymentPlanMonthly) {
    return 'Tu plan actual es mensual. Puedes cambiar a pago por consulta cuando quieras.';
  }
  return 'Pagas por cada consulta. Cambia a suscripción mensual si te atiendes con frecuencia.';
}
