'use strict'

const crypto = require('node:crypto')

// Apple rejects a developer token that carries anything beyond these claims, and
// answers 401 for any algorithm other than ES256. The header is unusual in
// carrying `id` — Team ID and Service ID joined by a period — alongside `kid`.
// Spec: developer.apple.com/documentation/weatherkitrestapi
//        /request-authentication-for-weatherkit-rest-api

const base64url = (buffer) =>
  Buffer.from(buffer).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

/**
 * ECDSA signatures come out of Node in ASN.1 DER; JOSE wants the raw r‖s pair,
 * each left-padded to the curve size. Passing DER straight through is the
 * classic way to get a silent 401 here.
 */
const signES256 = (signingInput, privateKeyPem) =>
  crypto.sign('sha256', Buffer.from(signingInput), {
    key: privateKeyPem,
    dsaEncoding: 'ieee-p1363'
  })

/**
 * @param {object} config
 * @param {string} config.teamId    10-character Apple Team ID
 * @param {string} config.serviceId the registered Services ID
 * @param {string} config.keyId     10-character key identifier
 * @param {string} config.privateKey  contents of the .p8, PEM encoded
 * @param {number} [config.lifetimeSeconds]
 * @param {number} [config.now] epoch seconds, for tests
 */
function mintDeveloperToken({ teamId, serviceId, keyId, privateKey, lifetimeSeconds = 3600, now }) {
  const issuedAt = now ?? Math.floor(Date.now() / 1000)

  const header = {
    alg: 'ES256',
    kid: keyId,
    id: `${teamId}.${serviceId}`
  }
  const claims = {
    iss: teamId,
    iat: issuedAt,
    exp: issuedAt + lifetimeSeconds,
    sub: serviceId
  }

  const signingInput =
    `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`

  return {
    token: `${signingInput}.${base64url(signES256(signingInput, privateKey))}`,
    expiresAt: claims.exp
  }
}

/**
 * Tokens are reusable for their whole lifetime, so minting one per request would
 * burn CPU for nothing. Re-mint a minute early to cover clock skew and the
 * in-flight request.
 */
function createTokenCache(config) {
  let cached = null
  return function currentToken(now = Math.floor(Date.now() / 1000)) {
    if (!cached || cached.expiresAt - 60 <= now) {
      cached = mintDeveloperToken({ ...config, now })
    }
    return cached.token
  }
}

module.exports = { mintDeveloperToken, createTokenCache, base64url }
