import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizePaymongoPaymentMethods } from './payment-methods.js';

test('defaults to card, gcash, and QR Ph when not configured', () => {
  assert.deepEqual(normalizePaymongoPaymentMethods(undefined), ['card', 'gcash', 'qrph']);
  assert.deepEqual(normalizePaymongoPaymentMethods('   '), ['card', 'gcash', 'qrph']);
});

test('removes blanks and duplicates and keeps valid values', () => {
  assert.deepEqual(normalizePaymongoPaymentMethods('card, gcash, , card'), ['card', 'gcash']);
  assert.deepEqual(normalizePaymongoPaymentMethods('paymaya, card'), ['paymaya', 'card']);
  assert.deepEqual(normalizePaymongoPaymentMethods('qrph'), ['qrph']);
});
