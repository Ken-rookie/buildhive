const DEFAULT_PAYMENT_METHODS = ['card', 'gcash', 'qrph'];
const VALID_PAYMENT_METHODS = new Set([
  'card',
  'gcash',
  'qrph',
  'grab_pay',
  'paymaya',
  'billease',
  'dob',
  'dob_ubp',
  'atome',
]);

export function normalizePaymongoPaymentMethods(rawValue) {
  const configured = typeof rawValue === 'string' ? rawValue : '';
  const entries = configured
    .split(',')
    .map((method) => method.trim().toLowerCase())
    .filter(Boolean);

  const normalized = [...new Set(entries)].filter((method) => VALID_PAYMENT_METHODS.has(method));
  return normalized.length > 0 ? normalized : [...DEFAULT_PAYMENT_METHODS];
}
