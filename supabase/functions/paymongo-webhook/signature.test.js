import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { isValidPaymongoSignature } from './signature.js';

function hmac(secret, payload) {
  return createHmac('sha256', secret).update(payload).digest('hex');
}

test('accepts a raw-body hex signature', async () => {
  const body = '{"event":"paid"}';
  const signature = hmac('secret', body);

  assert.equal(await isValidPaymongoSignature(body, 'secret', signature, 'live'), true);
});

test('accepts the signature for the configured mode in a timestamped header', async () => {
  const body = '{"event":"paid"}';
  const timestamp = '1792288800';
  const signature = hmac('secret', `${timestamp}.${body}`);
  const header = `t=${timestamp},te=${signature},li=${signature}`;

  assert.equal(await isValidPaymongoSignature(body, 'secret', header, 'test'), true);
  assert.equal(await isValidPaymongoSignature(body, 'secret', header, 'live'), true);
  assert.equal(await isValidPaymongoSignature(body, 'secret', header, 'invalid'), false);
});

test('rejects altered bodies, wrong secrets, and malformed signatures', async () => {
  const body = '{"event":"paid"}';
  const timestamp = '1792288800';
  const signature = hmac('secret', `${timestamp}.${body}`);
  const header = `t=${timestamp},te=${signature},li=${signature}`;

  assert.equal(await isValidPaymongoSignature(`${body} `, 'secret', header, 'test'), false);
  assert.equal(await isValidPaymongoSignature(body, 'wrong-secret', header, 'test'), false);
  assert.equal(await isValidPaymongoSignature(body, 'secret', 'invalid', 'test'), false);
});