function constantTimeEqual(left, right) {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference === 0;
}

function decodeHex(value) {
  if (!/^[0-9a-f]{64}$/i.test(value)) return null;
  return new Uint8Array(value.match(/.{2}/g).map((byte) => parseInt(byte, 16)));
}

function parsePaymongoSignature(header, mode) {
  const directSignature = decodeHex(header.trim());
  if (directSignature) return [{ payloadPrefix: '', signature: directSignature }];

  const fields = new Map(
    header.split(',').map((part) => {
      const separator = part.indexOf('=');
      return separator < 0
        ? ['', '']
        : [part.slice(0, separator).trim().toLowerCase(), part.slice(separator + 1).trim()];
    }),
  );
  const timestamp = fields.get('t');
  const modeSignature = fields.get(mode === 'live' ? 'li' : 'te');
  const signature = modeSignature ? decodeHex(modeSignature) : null;
  if (!timestamp || !signature) return [];
  return [{ payloadPrefix: `${timestamp}.`, signature }];
}

export async function isValidPaymongoSignature(body, secret, header, mode) {
  if (!['test', 'live'].includes(mode)) return false;

  const candidates = parsePaymongoSignature(header, mode);
  if (candidates.length === 0) return false;

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  for (const candidate of candidates) {
    const payload = `${candidate.payloadPrefix}${body}`;
    const digest = await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(payload),
    );
    if (constantTimeEqual(new Uint8Array(digest), candidate.signature)) return true;
  }

  return false;
}