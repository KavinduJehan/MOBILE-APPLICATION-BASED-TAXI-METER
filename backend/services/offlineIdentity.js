const crypto = require('crypto');

// A limited identity proof, not a login token. It grants no API access.
const signature = (payload) => crypto.createHmac('sha256', process.env.JWT_SECRET)
  .update(`offline-customer-v1:${payload}`).digest('base64url');

const issueIdentity = (customerId, now = Date.now()) => {
  const payload = Buffer.from(JSON.stringify({ customerId: String(customerId),
    issuedAt: now, expiresAt: now + 30 * 24 * 60 * 60 * 1000 })).toString('base64url');
  return `${payload}.${signature(payload)}`;
};

const verifyIdentity = (proof, customerId, startTime) => {
  if (typeof proof !== 'string' || proof.length > 2048) return false;
  const [payload, sig, extra] = proof.split('.');
  if (!payload || !sig || extra) return false;
  const expected = Buffer.from(signature(payload));
  const actual = Buffer.from(sig);
  if (expected.length !== actual.length || !crypto.timingSafeEqual(expected, actual)) return false;
  try {
    const claim = JSON.parse(Buffer.from(payload, 'base64url').toString());
    const time = new Date(startTime).getTime();
    return claim.customerId === customerId && Number.isFinite(time) &&
      time >= claim.issuedAt - 5 * 60 * 1000 && time <= claim.expiresAt;
  } catch { return false; }
};

module.exports = { issueIdentity, verifyIdentity };
