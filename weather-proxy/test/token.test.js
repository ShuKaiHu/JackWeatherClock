'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const crypto = require('node:crypto')

const { mintDeveloperToken, createTokenCache } = require('../token')

// A throwaway P-256 pair stands in for the Apple .p8, so the token shape is
// verified without the real private key ever being present.
const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', {
  namedCurve: 'prime256v1',
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' }
})

const CONFIG = {
  teamId: 'MQJ88U9NAJ',
  serviceId: 'com.shukaihu.rainyclock.weather',
  keyId: 'ABC123DEFG',
  privateKey,
  now: 1_700_000_000
}

const decode = (segment) => JSON.parse(Buffer.from(segment, 'base64url').toString())

test('the header carries ES256, the key id and Team.Service', () => {
  const { token } = mintDeveloperToken(CONFIG)
  const header = decode(token.split('.')[0])

  assert.equal(header.alg, 'ES256')
  assert.equal(header.kid, 'ABC123DEFG')
  assert.equal(header.id, 'MQJ88U9NAJ.com.shukaihu.rainyclock.weather')
})

test('the payload carries exactly the four claims Apple allows', () => {
  const { token } = mintDeveloperToken(CONFIG)
  const claims = decode(token.split('.')[1])

  // Apple documents this as an exact set: an extra claim is a 401, and that
  // failure looks identical to a bad key.
  assert.deepEqual(Object.keys(claims).sort(), ['exp', 'iat', 'iss', 'sub'])
  assert.equal(claims.iss, 'MQJ88U9NAJ')
  assert.equal(claims.sub, 'com.shukaihu.rainyclock.weather')
  assert.equal(claims.iat, 1_700_000_000)
  assert.equal(claims.exp, 1_700_003_600)
})

test('the signature is raw r‖s and verifies against the public key', () => {
  const { token } = mintDeveloperToken(CONFIG)
  const [header, payload, signature] = token.split('.')

  const raw = Buffer.from(signature, 'base64url')
  // P-256: 32 bytes of r followed by 32 of s. A DER-wrapped signature would be
  // ~70 bytes and Apple would answer 401 without saying why.
  assert.equal(raw.length, 64)

  const verified = crypto.verify(
    'sha256',
    Buffer.from(`${header}.${payload}`),
    { key: publicKey, dsaEncoding: 'ieee-p1363' },
    raw
  )
  assert.equal(verified, true)
})

test('the token is url-safe base64 with no padding', () => {
  const { token } = mintDeveloperToken(CONFIG)
  assert.match(token, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/)
})

test('the cache reuses a token until it is nearly expired, then re-mints', () => {
  const currentToken = createTokenCache({ ...CONFIG, now: undefined, lifetimeSeconds: 3600 })

  const first = currentToken(1_700_000_000)
  assert.equal(currentToken(1_700_003_000), first, 'still valid, should be reused')

  // 3540 = expiry minus the 60-second safety margin.
  assert.notEqual(currentToken(1_700_003_540), first, 'inside the margin, should re-mint')
})
